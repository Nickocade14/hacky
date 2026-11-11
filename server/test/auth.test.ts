import assert from "node:assert/strict";
import { once } from "node:events";
import { after, before, beforeEach, test } from "node:test";
import { fileURLToPath } from "node:url";
import SwaggerParser from "@apidevtools/swagger-parser";
import { Ajv } from "ajv";
import mongoose from "mongoose";
import { MongoMemoryReplSet } from "mongodb-memory-server";
import { createApp } from "../src/app.js";
import { connectDb, disconnectDb } from "../src/db.js";
import type { Mail } from "../src/email/mailer.js";
import { EventModel } from "../src/models/Event.js";
import { MembershipModel } from "../src/models/Membership.js";
import { AuthCodeModel } from "../src/models/AuthCode.js";
import { PendingSignupModel } from "../src/models/PendingSignup.js";
import { ProfileModel } from "../src/models/Profile.js";
import { UserModel } from "../src/models/User.js";
import { hashPassword } from "../src/validation/auth.js";

process.env.JWT_SECRET = "test-secret-that-is-at-least-32-characters-long";

let replica: MongoMemoryReplSet;
let base: string;
let server: ReturnType<ReturnType<typeof createApp>["listen"]>;
let schemas: Record<string, object>;
const outbox: Mail[] = [];
const ajv = new Ajv({ strict: false, validateFormats: false });

before(async () => {
  // Isolated ephemeral database: NEVER connects to the user's Atlas cluster.
  replica = await MongoMemoryReplSet.create({ replSet: { count: 1 }, instanceOpts: [{ launchTimeout: 60_000 }] });
  await connectDb(replica.getUri("hacky_auth_tests"));
  for (const name of mongoose.modelNames()) {
    await mongoose.model(name).createCollection();
    await mongoose.model(name).createIndexes();
  }
  server = createApp({ mailer: { send: async (mail) => { outbox.push(mail); } } }).listen(0, "127.0.0.1");
  await once(server, "listening");
  const address = server.address();
  assert.ok(address && typeof address !== "string");
  base = `http://127.0.0.1:${address.port}`;
  const api = await SwaggerParser.dereference(fileURLToPath(new URL("../../docs/openapi.yaml", import.meta.url)));
  schemas = (api as any).components.schemas;
}, { timeout: 240_000 });

after(async () => {
  await new Promise<void>((resolve) => { server.close(() => resolve()); server.closeAllConnections(); });
  await disconnectDb();
  await replica.stop();
});

beforeEach(() => { outbox.length = 0; });

async function call(method: string, path: string, body?: unknown, token?: string) {
  const response = await fetch(`${base}${path}`, {
    method,
    headers: {
      ...(body === undefined ? {} : { "Content-Type": "application/json" }),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  return { status: response.status, body: await response.json() as any };
}

// The 6-digit code from the last mail.
function codeFromMail(): string {
  const mail = outbox.at(-1);
  assert.ok(mail, "expected a mail");
  const match = /^(\d{6})$/m.exec(mail.text);
  assert.ok(match, `expected a code in: ${mail.text}`);
  assert.ok(mail.subject.startsWith(match[1]));
  return match[1];
}

// A 6-digit code that isn't `code`.
const otherCode = (code: string) => String((Number(code) + 1) % 1_000_000).padStart(6, "0");

const assertSchema = (name: string, value: unknown) => {
  const validate = ajv.compile(schemas[name]);
  assert.equal(validate(value), true, JSON.stringify(validate.errors));
};

const register = (body: { name: string; handle: string; email: string; password: string }) =>
  call("POST", "/api/auth/register", body);

// Registers and verifies; returns the LoginResult body.
async function signUp(body: { name: string; handle: string; email: string; password: string }) {
  assert.equal((await register(body)).status, 200);
  const verified = await call("POST", "/api/auth/verify-email", { email: body.email, code: codeFromMail() });
  assert.equal(verified.status, 200, JSON.stringify(verified.body));
  return verified.body;
}

const nico = { name: "Nico", handle: "Nico_C", email: "Nico@Example.com", password: "correct-horse" };

test("register saves nothing until the code; verify creates the account and logs in", async () => {
  const registered = await register(nico);
  assert.equal(registered.status, 200);
  assert.deepEqual(registered.body, { ok: true });
  assert.equal(outbox.length, 1);
  assert.equal(outbox[0].to, "nico@example.com");
  assert.ok(!outbox[0].html.includes("http"), "the mail has a code, not a link");

  // No account yet: the email and the username are still free.
  assert.equal(await UserModel.countDocuments({ email: "nico@example.com" }), 0);
  assert.equal(await ProfileModel.countDocuments({ handle: "nico_c" }), 0);
  assert.equal((await call("POST", "/api/auth/login", { email: nico.email, password: nico.password })).status, 401);
  // The pending sign-up never stores the code or the password in plain text.
  const pending = await PendingSignupModel.findOne({ email: "nico@example.com" }).select("+passwordHash +codeHash").lean();
  assert.ok(pending);
  const code = codeFromMail();
  assert.ok(!JSON.stringify(pending).includes(code));
  assert.ok(!JSON.stringify(pending).includes(nico.password));

  const wrong = await call("POST", "/api/auth/verify-email", { email: nico.email, code: otherCode(code) });
  assert.equal(wrong.status, 400);
  assert.equal(wrong.body.error.code, "invalid_code");

  const verified = await call("POST", "/api/auth/verify-email", { email: "NICO@example.com", code: ` ${code} ` });
  assert.equal(verified.status, 200);
  assertSchema("LoginResult", verified.body);
  assert.equal(verified.body.me.profile.handle, "nico_c");
  assert.equal(JSON.stringify(verified.body).includes("passwordHash"), false);
  assert.equal(JSON.stringify(verified.body).includes("nico@example.com"), false);
  const user = await UserModel.findOne({ email: "nico@example.com" }).lean();
  assert.equal(user?.emailVerified, true);
  assert.equal(await PendingSignupModel.countDocuments({ email: "nico@example.com" }), 0);

  // A code works once.
  const reused = await call("POST", "/api/auth/verify-email", { email: nico.email, code });
  assert.equal(reused.status, 400);
  assert.equal(reused.body.error.code, "invalid_code");

  // The JWT from verify works, and login gives the same account.
  const me = await call("GET", "/api/me", undefined, verified.body.token);
  assert.equal(me.status, 200);
  assertSchema("Me", me.body);

  const event = await EventModel.create({ slug: "knighthacks-ix", name: "Knight Hacks IX" });
  await MembershipModel.create({ event: event._id, user: user!._id, role: "hacker" });
  const login = await call("POST", "/api/auth/login", { email: "NICO@example.com", password: nico.password });
  assert.equal(login.status, 200);
  assertSchema("LoginResult", login.body);
  assert.deepEqual(login.body.me.events, [{ slug: "knighthacks-ix", name: "Knight Hacks IX", role: "hacker", verified: false }]);
  assert.ok(Date.parse(login.body.expiresAt) > Date.now() + 6 * 24 * 3600_000);
});

test("protected routes answer 401 without a valid token", async () => {
  for (const token of [undefined, "not-a-jwt", "eyJhbGciOiJIUzI1NiJ9.e30.x"]) {
    for (const path of ["/api/me", "/api/search?event=knighthacks-ix&q=re"]) {
      const response = await call("GET", path, undefined, token);
      assert.equal(response.status, 401, `${path} with ${token}`);
      assert.equal(response.body.error.code, "unauthorized");
    }
  }
  // Unknown routes are still 404, not 401.
  assert.equal((await call("GET", "/api/nope")).status, 404);
});

test("taken email or username is 409, bad input is 400", async () => {
  const first = { name: "Ana", handle: "ana", email: "ana@example.com", password: "password-1" };
  await signUp(first);
  const sameEmail = await register({ ...first, handle: "ana2" });
  assert.equal(sameEmail.status, 409);
  assert.equal(sameEmail.body.error.code, "email_taken");
  const sameHandle = await register({ ...first, email: "ana2@example.com", handle: "ANA" });
  assert.equal(sameHandle.status, 409);
  assert.equal(sameHandle.body.error.code, "handle_taken");
  assert.match(sameHandle.body.error.message, /username/i);
  // Seeded demo people have a Profile but no User; their usernames are taken too.
  await ProfileModel.create({ _id: new mongoose.Types.ObjectId(), handle: "demo_person", name: "Demo", isDemo: true });
  assert.equal((await register({ ...first, email: "ana3@example.com", handle: "demo_person" })).body.error.code, "handle_taken");
  // None of the failed tries left anything behind.
  assert.equal(await PendingSignupModel.countDocuments({ email: { $in: ["ana2@example.com", "ana3@example.com"] } }), 0);

  for (const body of [{}, { ...first, email: "x" }, { ...first, password: "short" }, { ...first, handle: "a b" }]) {
    const response = await call("POST", "/api/auth/register", body);
    assert.equal(response.status, 400);
    assert.equal(response.body.error.code, "invalid_input");
  }
  for (const code of ["12345", "abcdef", "1234567", ""]) {
    const response = await call("POST", "/api/auth/verify-email", { email: "ana@example.com", code });
    assert.equal(response.status, 400);
    assert.equal(response.body.error.code, "invalid_input");
  }
  assert.equal((await call("POST", "/api/auth/login", { email: "ana@example.com" })).status, 400);
});

test("an unverified sign-up doesn't hold the username; the first to verify gets it", async () => {
  const first = { name: "Dee", handle: "dee", email: "dee@example.com", password: "password-1" };
  const second = { ...first, email: "dee2@example.com" };
  assert.equal((await register(first)).status, 200);
  const firstCode = codeFromMail();
  assert.equal((await register(second)).status, 200);
  const secondCode = codeFromMail();

  assert.equal((await call("POST", "/api/auth/verify-email", { email: second.email, code: secondCode })).status, 200);
  const late = await call("POST", "/api/auth/verify-email", { email: first.email, code: firstCode });
  assert.equal(late.status, 409);
  assert.equal(late.body.error.code, "handle_taken");
  // The losing sign-up is gone, so it can start over with another username.
  assert.equal(await PendingSignupModel.countDocuments({ email: first.email }), 0);
  assert.equal(await UserModel.countDocuments({ email: first.email }), 0);
  await signUp({ ...first, handle: "dee_two" });
});

test("an expired sign-up is gone and the same email and username can register again", async () => {
  const body = { name: "Eli", handle: "eli_dev", email: "eli@example.com", password: "password-1" };
  assert.equal((await register(body)).status, 200);
  const code = codeFromMail();
  await PendingSignupModel.updateOne({ email: body.email }, { $set: { expiresAt: new Date(Date.now() - 1000) } });
  assert.equal((await call("POST", "/api/auth/verify-email", { email: body.email, code })).body.error.code, "invalid_code");
  // Resend doesn't revive it either.
  outbox.length = 0;
  await call("POST", "/api/auth/resend-verification", { email: body.email });
  assert.equal(outbox.length, 0);
  // Registering again replaces it with a fresh code.
  await signUp(body);
  assert.equal(await PendingSignupModel.countDocuments({ email: body.email }), 0);
});

test("5 wrong codes delete the sign-up, even when sent at once", async () => {
  const body = { name: "Fay", handle: "fay", email: "fay@example.com", password: "password-1" };
  assert.equal((await register(body)).status, 200);
  const code = codeFromMail();
  const wrong = await Promise.all(Array.from({ length: 8 }, () =>
    call("POST", "/api/auth/verify-email", { email: body.email, code: otherCode(code) })));
  assert.ok(wrong.every((response) => response.status === 400 && response.body.error.code === "invalid_code"));
  assert.equal(await PendingSignupModel.countDocuments({ email: body.email }), 0);
  // Even the right code is useless now.
  assert.equal((await call("POST", "/api/auth/verify-email", { email: body.email, code })).status, 400);
});

test("resend-verification and forgot-password always answer 200", async () => {
  for (const path of ["/api/auth/resend-verification", "/api/auth/forgot-password"]) {
    const response = await call("POST", path, { email: "nobody@example.com" });
    assert.equal(response.status, 200);
    assert.deepEqual(response.body, { ok: true });
  }
  assert.equal(outbox.length, 0);

  const bo = { name: "Bo", handle: "bo_dev", email: "bo@example.com", password: "password-1" };
  assert.equal((await register(bo)).status, 200);
  const first = codeFromMail();
  // Spend some tries; resend gives them back.
  for (let i = 0; i < 4; i++) await call("POST", "/api/auth/verify-email", { email: bo.email, code: otherCode(first) });
  assert.equal((await call("POST", "/api/auth/resend-verification", { email: bo.email })).status, 200);
  const second = codeFromMail();
  if (first !== second) {
    // Only the newest code works.
    assert.equal((await call("POST", "/api/auth/verify-email", { email: bo.email, code: first })).status, 400);
  }
  assert.equal((await call("POST", "/api/auth/verify-email", { email: bo.email, code: second })).status, 200);

  // Verified accounts don't get another sign-up code.
  outbox.length = 0;
  await call("POST", "/api/auth/resend-verification", { email: bo.email });
  assert.equal(outbox.length, 0);
});

test("forgot and reset password with a code, then logged in", async () => {
  await signUp({ name: "Cy", handle: "cy_dev", email: "cy@example.com", password: "old-password" });
  outbox.length = 0;
  assert.equal((await call("POST", "/api/auth/forgot-password", { email: "CY@example.com" })).status, 200);
  assert.equal(outbox[0].to, "cy@example.com");
  const code = codeFromMail();

  // A bad new password is rejected before it spends a try.
  const weak = await call("POST", "/api/auth/reset-password", { email: "cy@example.com", code, password: "short" });
  assert.equal(weak.status, 400);
  assert.equal(weak.body.error.code, "invalid_input");
  const wrong = await call("POST", "/api/auth/reset-password", { email: "cy@example.com", code: otherCode(code), password: "new-password" });
  assert.equal(wrong.body.error.code, "invalid_code");
  // A code only works for its own email.
  await signUp({ name: "Di", handle: "di_dev", email: "di@example.com", password: "password-1" });
  assert.equal((await call("POST", "/api/auth/reset-password", { email: "di@example.com", code, password: "new-password" })).status, 400);

  const reset = await call("POST", "/api/auth/reset-password", { email: "cy@example.com", code, password: "new-password" });
  assert.equal(reset.status, 200);
  assertSchema("LoginResult", reset.body);
  assert.equal(reset.body.me.profile.handle, "cy_dev");
  assert.equal((await call("GET", "/api/me", undefined, reset.body.token)).status, 200);
  const reused = await call("POST", "/api/auth/reset-password", { email: "cy@example.com", code, password: "another-one" });
  assert.equal(reused.status, 400);
  assert.equal(reused.body.error.code, "invalid_code");

  assert.equal((await call("POST", "/api/auth/login", { email: "cy@example.com", password: "old-password" })).status, 401);
  assert.equal((await call("POST", "/api/auth/login", { email: "cy@example.com", password: "new-password" })).status, 200);

  // 5 wrong tries delete the reset code.
  outbox.length = 0;
  await call("POST", "/api/auth/forgot-password", { email: "cy@example.com" });
  const next = codeFromMail();
  for (let i = 0; i < 5; i++) {
    await call("POST", "/api/auth/reset-password", { email: "cy@example.com", code: otherCode(next), password: "new-password-2" });
  }
  assert.equal(await AuthCodeModel.countDocuments({}), 0);
  assert.equal((await call("POST", "/api/auth/reset-password", { email: "cy@example.com", code: next, password: "new-password-2" })).status, 400);
});

test("accounts made before sign-up codes still need verification to log in", async () => {
  await UserModel.create({ email: "old@example.com", passwordHash: await hashPassword("password-1"), emailVerified: false });
  const response = await call("POST", "/api/auth/login", { email: "old@example.com", password: "password-1" });
  assert.equal(response.status, 403);
  assert.equal(response.body.error.code, "email_not_verified");
});
