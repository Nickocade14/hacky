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
import { ProfileModel } from "../src/models/Profile.js";
import { UserModel } from "../src/models/User.js";

process.env.JWT_SECRET = "test-secret-that-is-at-least-32-characters-long";
process.env.APP_URL = "https://hackymatch.test";

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

// The raw token from the last mail's link (/verify?token=... or /reset?token=...).
function tokenFromMail(path: "/verify" | "/reset"): string {
  const mail = outbox.at(-1);
  assert.ok(mail, "expected a mail");
  const match = new RegExp(`https://hackymatch\\.test${path}\\?token=([^\\s"&]+)`).exec(mail.text);
  assert.ok(match, `expected a ${path} link in: ${mail.text}`);
  return decodeURIComponent(match[1]);
}

const assertSchema = (name: string, value: unknown) => {
  const validate = ajv.compile(schemas[name]);
  assert.equal(validate(value), true, JSON.stringify(validate.errors));
};

const nico = { name: "Nico", handle: "Nico_C", email: "Nico@Example.com", password: "correct-horse" };

test("register, verify, login and GET /api/me", async () => {
  const registered = await call("POST", "/api/auth/register", nico);
  assert.equal(registered.status, 201);
  assert.deepEqual(registered.body, { ok: true });
  assert.equal(outbox.length, 1);
  assert.equal(outbox[0].to, "nico@example.com");

  const user = await UserModel.findOne({ email: "nico@example.com" }).lean();
  assert.ok(user);
  assert.equal(user.emailVerified, false);
  const profile = await ProfileModel.findById(user._id).lean();
  assert.equal(profile?.handle, "nico_c");

  // Not verified yet: 403, and the right password is still needed first.
  assert.equal((await call("POST", "/api/auth/login", { email: nico.email, password: "wrong-pass" })).status, 401);
  const early = await call("POST", "/api/auth/login", { email: nico.email, password: nico.password });
  assert.equal(early.status, 403);
  assert.equal(early.body.error.code, "email_not_verified");

  const token = tokenFromMail("/verify");
  assert.equal((await call("POST", "/api/auth/verify-email", { token })).status, 200);
  const reused = await call("POST", "/api/auth/verify-email", { token });
  assert.equal(reused.status, 400);
  assert.equal(reused.body.error.code, "invalid_token");

  const event = await EventModel.create({ slug: "knighthacks-ix", name: "Knight Hacks IX" });
  await MembershipModel.create({ event: event._id, user: user._id, role: "hacker" });

  const login = await call("POST", "/api/auth/login", { email: "NICO@example.com", password: nico.password });
  assert.equal(login.status, 200);
  assertSchema("LoginResult", login.body);
  assert.equal(login.body.me.profile.handle, "nico_c");
  assert.deepEqual(login.body.me.events, [{ slug: "knighthacks-ix", name: "Knight Hacks IX", role: "hacker", verified: false }]);
  assert.ok(Date.parse(login.body.expiresAt) > Date.now() + 6 * 24 * 3600_000);
  assert.equal(JSON.stringify(login.body).includes("passwordHash"), false);
  assert.equal(JSON.stringify(login.body).includes("nico@example.com"), false);

  const me = await call("GET", "/api/me", undefined, login.body.token);
  assert.equal(me.status, 200);
  assertSchema("Me", me.body);
  assert.deepEqual(me.body, login.body.me);
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

test("taken email or handle is 409, bad input is 400", async () => {
  const first = { name: "Ana", handle: "ana", email: "ana@example.com", password: "password-1" };
  assert.equal((await call("POST", "/api/auth/register", first)).status, 201);
  const sameEmail = await call("POST", "/api/auth/register", { ...first, handle: "ana2" });
  assert.equal(sameEmail.status, 409);
  assert.equal(sameEmail.body.error.code, "email_taken");
  const sameHandle = await call("POST", "/api/auth/register", { ...first, email: "ana2@example.com", handle: "ANA" });
  assert.equal(sameHandle.status, 409);
  assert.equal(sameHandle.body.error.code, "handle_taken");
  // The failed registration left no half-made account behind.
  assert.equal(await UserModel.countDocuments({ email: "ana2@example.com" }), 0);

  for (const body of [{}, { ...first, email: "x" }, { ...first, password: "short" }, { ...first, handle: "a b" }]) {
    const response = await call("POST", "/api/auth/register", body);
    assert.equal(response.status, 400);
    assert.equal(response.body.error.code, "invalid_input");
  }
  assert.equal((await call("POST", "/api/auth/login", { email: "ana@example.com" })).status, 400);
});

test("resend-verification and forgot-password always answer 200", async () => {
  for (const path of ["/api/auth/resend-verification", "/api/auth/forgot-password"]) {
    const response = await call("POST", path, { email: "nobody@example.com" });
    assert.equal(response.status, 200);
    assert.deepEqual(response.body, { ok: true });
  }
  assert.equal(outbox.length, 0);

  await call("POST", "/api/auth/register", { name: "Bo", handle: "bo_dev", email: "bo@example.com", password: "password-1" });
  const first = tokenFromMail("/verify");
  assert.equal((await call("POST", "/api/auth/resend-verification", { email: "bo@example.com" })).status, 200);
  const second = tokenFromMail("/verify");
  assert.notEqual(first, second);
  // Only the newest link works.
  assert.equal((await call("POST", "/api/auth/verify-email", { token: first })).status, 400);
  assert.equal((await call("POST", "/api/auth/verify-email", { token: second })).status, 200);

  // Verified accounts don't get another verification mail.
  outbox.length = 0;
  await call("POST", "/api/auth/resend-verification", { email: "bo@example.com" });
  assert.equal(outbox.length, 0);
});

test("forgot and reset password", async () => {
  await call("POST", "/api/auth/register", { name: "Cy", handle: "cy", email: "cy@example.com", password: "old-password" });
  outbox.length = 0;
  assert.equal((await call("POST", "/api/auth/forgot-password", { email: "cy@example.com" })).status, 200);
  const token = tokenFromMail("/reset");

  // A bad new password doesn't use up the token.
  assert.equal((await call("POST", "/api/auth/reset-password", { token, password: "short" })).status, 400);
  assert.equal((await call("POST", "/api/auth/reset-password", { token, password: "new-password" })).status, 200);
  const reused = await call("POST", "/api/auth/reset-password", { token, password: "another-one" });
  assert.equal(reused.status, 400);
  assert.equal(reused.body.error.code, "invalid_token");
  // A made-up token is rejected too.
  assert.equal((await call("POST", "/api/auth/reset-password", { token: "x".repeat(43), password: "new-password" })).status, 400);

  assert.equal((await call("POST", "/api/auth/login", { email: "cy@example.com", password: "old-password" })).status, 401);
  // Resetting through the emailed link also verified the email.
  assert.equal((await call("POST", "/api/auth/login", { email: "cy@example.com", password: "new-password" })).status, 200);
});
