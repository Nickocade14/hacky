import assert from "node:assert/strict";
import { once } from "node:events";
import { after, before, test } from "node:test";
import { fileURLToPath } from "node:url";
import SwaggerParser from "@apidevtools/swagger-parser";
import { Ajv } from "ajv";
import mongoose, { Types } from "mongoose";
import { MongoMemoryReplSet } from "mongodb-memory-server";
import { createApp } from "../src/app.js";
import { signToken } from "../src/auth/jwt.js";
import { connectDb, disconnectDb } from "../src/db.js";
import { BlockModel } from "../src/models/Block.js";
import { ConnectionRequestModel } from "../src/models/ConnectionRequest.js";
import { EventModel } from "../src/models/Event.js";
import { MembershipModel } from "../src/models/Membership.js";
import { ProfileModel } from "../src/models/Profile.js";
import { openDm } from "../src/models/Conversation.js";

process.env.JWT_SECRET = "test-secret-that-is-at-least-32-characters-long";

let replica: MongoMemoryReplSet;
let base: string;
let server: ReturnType<ReturnType<typeof createApp>["listen"]>;
let schemas: Record<string, object>;
const ajv = new Ajv({ strict: false, validateFormats: false });

let eventId: Types.ObjectId;
const people: Record<string, { id: Types.ObjectId; token: string }> = {};

async function person(handle: string, opts: { join?: boolean; role?: "hacker" | "mentor"; skills?: string[] } = {}) {
  const id = new Types.ObjectId();
  await ProfileModel.create({ _id: id, handle, name: handle.toUpperCase(), bio: `${handle} bio` });
  if (opts.join !== false) {
    await MembershipModel.create({ event: eventId, user: id, role: opts.role ?? "hacker", skills: opts.skills ?? [] });
  }
  people[handle] = { id, token: signToken(id).token };
  return people[handle];
}

before(async () => {
  // Isolated ephemeral database: NEVER connects to the user's Atlas cluster.
  replica = await MongoMemoryReplSet.create({ replSet: { count: 1 }, instanceOpts: [{ launchTimeout: 60_000 }] });
  await connectDb(replica.getUri("hacky_events_tests"));
  for (const name of mongoose.modelNames()) {
    await mongoose.model(name).createCollection();
    await mongoose.model(name).createIndexes();
  }
  server = createApp({ mailer: { send: async () => {} } }).listen(0, "127.0.0.1");
  await once(server, "listening");
  const address = server.address();
  assert.ok(address && typeof address !== "string");
  base = `http://127.0.0.1:${address.port}`;
  const api = await SwaggerParser.dereference(fileURLToPath(new URL("../../docs/openapi.yaml", import.meta.url)));
  schemas = (api as any).components.schemas;

  const event = await EventModel.create({
    slug: "knighthacks-ix", name: "Knight Hacks IX", tracks: ["Fintech", "Health"],
    startsAt: new Date("2026-10-24T22:00:00Z"), endsAt: new Date("2026-10-26T16:00:00Z"),
  });
  eventId = event._id;
  await EventModel.create({ slug: "demo-hacks", name: "Demo Hacks" });

  await person("viewer", { skills: ["Flutter"] });
  await person("maya", { skills: ["React", "TypeScript"] });
  await person("theo", { role: "mentor", skills: ["Python"] });
  await person("blocked_guy");
  await person("blocker_gal");
  await person("outsider", { join: false });
  await BlockModel.create({ blocker: people.viewer.id, blocked: people.blocked_guy.id });
  await BlockModel.create({ blocker: people.blocker_gal.id, blocked: people.viewer.id });
}, { timeout: 240_000 });

after(async () => {
  await new Promise<void>((resolve) => { server.close(() => resolve()); server.closeAllConnections(); });
  await disconnectDb();
  await replica.stop();
});

async function call(method: string, path: string, who: string | null, body?: unknown) {
  const response = await fetch(`${base}${path}`, {
    method,
    headers: {
      ...(body === undefined ? {} : { "Content-Type": "application/json" }),
      ...(who ? { Authorization: `Bearer ${people[who].token}` } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  return { status: response.status, body: await response.json() as any };
}

const assertSchema = (name: string, value: unknown) => {
  const validate = ajv.compile(schemas[name]);
  assert.equal(validate(value), true, `${name}: ${JSON.stringify(validate.errors)}`);
};

test("every route needs a token", async () => {
  for (const path of ["/api/events", "/api/events/knighthacks-ix", "/api/events/knighthacks-ix/me"]) {
    assert.equal((await call("GET", path, null)).status, 401);
  }
});

test("list and get events", async () => {
  const list = await call("GET", "/api/events", "viewer");
  assert.equal(list.status, 200);
  assert.deepEqual(list.body.events.map((e: any) => e.slug).sort(), ["demo-hacks", "knighthacks-ix"]);
  for (const event of list.body.events) assertSchema("EventInfo", event);

  const one = await call("GET", "/api/events/knighthacks-ix", "viewer");
  assert.equal(one.status, 200);
  assert.deepEqual(one.body.tracks, ["Fintech", "Health"]);
  assert.equal(one.body.startsAt, "2026-10-24T22:00:00.000Z");
  assert.equal((await call("GET", "/api/events/nope", "viewer")).status, 404);
});

test("join, then read and update my intake", async () => {
  // Not a member yet: 403.
  assert.equal((await call("GET", "/api/events/knighthacks-ix/me", "outsider")).status, 403);
  const joined = await call("POST", "/api/events/knighthacks-ix/join", "outsider", { role: "mentor" });
  assert.equal(joined.status, 200);
  assertSchema("EventMe", joined.body);
  assert.equal(joined.body.role, "mentor");
  assert.equal(joined.body.verified, false);
  // Joining again keeps the first role.
  const again = await call("POST", "/api/events/knighthacks-ix/join", "outsider", { role: "hacker" });
  assert.equal(again.body.role, "mentor");
  assert.equal(await MembershipModel.countDocuments({ user: people.outsider.id }), 1);
  assert.equal((await call("POST", "/api/events/nope/join", "outsider", {})).status, 404);
  assert.equal((await call("POST", "/api/events/knighthacks-ix/join", "outsider", { role: "organizer" })).status, 400);

  const patched = await call("PATCH", "/api/events/knighthacks-ix/me", "outsider", {
    skills: ["Go", "Go", "Rust"], experience: "advanced", goal: "learn", track: "Health", looking: false,
  });
  assert.equal(patched.status, 200);
  assertSchema("EventMe", patched.body);
  assert.deepEqual(patched.body.intake.skills, ["Go", "Rust"]);
  assert.equal(patched.body.intake.complete, true);
  assert.equal(patched.body.looking, false);

  const cleared = await call("PATCH", "/api/events/knighthacks-ix/me", "outsider", { goal: null, track: null });
  assert.equal(cleared.body.intake.goal, null);
  assert.equal(cleared.body.intake.track, null);
  assert.equal(cleared.body.intake.complete, false);

  for (const body of [{ role: "organizer" }, { verified: true }, { experience: "expert" }, { skills: ["x".repeat(41)] }]) {
    assert.equal((await call("PATCH", "/api/events/knighthacks-ix/me", "outsider", body)).status, 400);
  }
  const me = await call("GET", "/api/me", "outsider");
  assert.deepEqual(me.body.events, [{ slug: "knighthacks-ix", name: "Knight Hacks IX", role: "mentor", verified: false }]);
});

test("update my profile", async () => {
  const updated = await call("PATCH", "/api/me/profile", "viewer", {
    name: "Nico C", bio: "Flutter dev", hackyStyle: { look: "knit", color: "teal" },
    links: { github: "https://github.com/nico" },
  });
  assert.equal(updated.status, 200);
  assertSchema("PublicProfile", updated.body);
  assert.equal(updated.body.name, "Nico C");
  assert.deepEqual(updated.body.links, { github: "https://github.com/nico" });
  const noBio = await call("PATCH", "/api/me/profile", "viewer", { bio: null });
  assert.equal(noBio.body.bio, null);
  assert.equal(noBio.body.name, "Nico C");
  for (const body of [{}, { name: "" }, { links: { github: "http://x.com" } }, { hackyStyle: { color: "x".repeat(41) } }]) {
    assert.equal((await call("PATCH", "/api/me/profile", "viewer", body)).status, 400, JSON.stringify(body));
  }
});

test("a person's profile, with blocks and relations", async () => {
  const maya = await call("GET", "/api/events/knighthacks-ix/people/MAYA", "viewer");
  assert.equal(maya.status, 200);
  assertSchema("PersonDetail", maya.body);
  assert.deepEqual(maya.body.skills, ["React", "TypeScript"]);
  assert.deepEqual(maya.body.relation, { state: "none", requestId: null, conversationId: null });
  assert.equal(JSON.stringify(maya.body).includes("email"), false);

  for (const handle of ["blocked_guy", "blocker_gal", "nobody_here"]) {
    assert.equal((await call("GET", `/api/events/knighthacks-ix/people/${handle}`, "viewer")).status, 404, handle);
  }
  assert.equal((await call("GET", "/api/events/demo-hacks/people/maya", "viewer")).status, 403);

  const request = await ConnectionRequestModel.create({
    event: eventId, from: people.viewer.id, to: people.maya.id, intro: "Hi!",
  });
  const outgoing = await call("GET", "/api/events/knighthacks-ix/people/maya", "viewer");
  assert.deepEqual(outgoing.body.relation, { state: "outgoing", requestId: request._id.toString(), conversationId: null });
  const incoming = await call("GET", "/api/events/knighthacks-ix/people/viewer", "maya");
  assert.equal(incoming.body.relation.state, "incoming");

  await ConnectionRequestModel.updateOne({ _id: request._id }, { $set: { status: "accepted" } });
  const dm = await openDm(eventId, people.viewer.id, people.maya.id);
  const accepted = await call("GET", "/api/events/knighthacks-ix/people/maya", "viewer");
  assert.deepEqual(accepted.body.relation, {
    state: "accepted", requestId: request._id.toString(), conversationId: dm._id.toString(),
  });
});

test("teams: create, my team, get, one team per person", async () => {
  const none = await call("GET", "/api/events/knighthacks-ix/me/team", "viewer");
  assert.deepEqual(none.body, { team: null });

  const created = await call("POST", "/api/events/knighthacks-ix/teams", "viewer", {
    name: "Knit Wits", idea: "Matchmaking", wantedSkills: ["React"], maxSize: 3,
  });
  assert.equal(created.status, 201);
  assertSchema("TeamDetail", created.body);
  assert.equal(created.body.owner.handle, "viewer");
  assert.equal(created.body.size, 1);
  assert.deepEqual(created.body.members.map((m: any) => m.handle), ["viewer"]);

  const mine = await call("GET", "/api/events/knighthacks-ix/me/team", "viewer");
  assert.deepEqual(mine.body.team, { id: created.body.id, name: "Knit Wits", isOwner: true, size: 1, maxSize: 3 });

  const second = await call("POST", "/api/events/knighthacks-ix/teams", "viewer", { name: "Again" });
  assert.equal(second.status, 409);
  assert.equal((await call("POST", "/api/events/knighthacks-ix/teams", "maya", { name: "" })).status, 400);
  assert.equal((await call("POST", "/api/events/knighthacks-ix/teams", "maya", { name: "X", maxSize: 9 })).status, 400);

  const seen = await call("GET", `/api/events/knighthacks-ix/teams/${created.body.id}`, "maya");
  assert.equal(seen.status, 200);
  assert.equal(seen.body.name, "Knit Wits");
  assert.equal((await call("GET", `/api/events/knighthacks-ix/teams/${new Types.ObjectId()}`, "maya")).status, 404);
  assert.equal((await call("GET", "/api/events/knighthacks-ix/teams/bad-id", "maya")).status, 400);
});
