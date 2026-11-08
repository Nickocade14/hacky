import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
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
import { ConversationModel } from "../src/models/Conversation.js";
import { EventModel } from "../src/models/Event.js";
import { MembershipModel } from "../src/models/Membership.js";
import { ProfileModel } from "../src/models/Profile.js";
import { TeamModel } from "../src/models/Team.js";

process.env.JWT_SECRET = "test-secret-that-is-at-least-32-characters-long";

let replica: MongoMemoryReplSet;
let base: string;
let server: ReturnType<ReturnType<typeof createApp>["listen"]>;
let schemas: Record<string, object>;
const ajv = new Ajv({ strict: false, validateFormats: false });
const slug = "knighthacks-ix";
let eventId: Types.ObjectId;
const people: Record<string, { id: Types.ObjectId; token: string }> = {};

async function person(handle: string, join = true) {
  const id = new Types.ObjectId();
  await ProfileModel.create({ _id: id, handle, name: handle.toUpperCase() });
  if (join) await MembershipModel.create({ event: eventId, user: id, role: "hacker" });
  people[handle] = { id, token: signToken(id).token };
}

before(async () => {
  // Isolated ephemeral database: NEVER connects to the user's Atlas cluster.
  replica = await MongoMemoryReplSet.create({ replSet: { count: 1 }, instanceOpts: [{ launchTimeout: 60_000 }] });
  await connectDb(replica.getUri("hacky_social_tests"));
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

  eventId = (await EventModel.create({ slug, name: "Knight Hacks IX" }))._id;
  for (const handle of ["ana", "ben", "cam", "dee", "eve", "fay", "gus"]) await person(handle);
  await person("outsider", false);
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

const send = (from: string, to: string, extra: Record<string, unknown> = {}) =>
  call("POST", `/api/events/${slug}/requests`, from, { toUserId: people[to].id.toString(), intro: `Hi ${to}!`, ...extra });

test("send, list, hide and accept a request, then chat", async () => {
  const sent = await send("ana", "ben");
  assert.equal(sent.status, 201);
  assertSchema("RequestResult", sent.body);
  assert.equal(sent.body.request.direction, "outgoing");
  assert.equal(sent.body.request.status, "pending");
  assert.equal("hiddenAt" in sent.body.request, false);
  assert.equal((await send("ana", "ben")).status, 409);

  const bens = await call("GET", `/api/events/${slug}/requests`, "ben");
  assert.equal(bens.body.requests.length, 1);
  assertSchema("ConnectionRequest", bens.body.requests[0]);
  assert.equal(bens.body.requests[0].direction, "incoming");
  assert.equal(bens.body.requests[0].person.handle, "ana");
  assert.equal(bens.body.requests[0].hiddenAt, null);

  const id = sent.body.request.id;
  assert.equal((await call("POST", `/api/requests/${id}/accept`, "ana")).status, 403);
  assert.equal((await call("POST", `/api/requests/${id}/hide`, "ben")).status, 200);
  const hidden = await call("GET", `/api/events/${slug}/requests`, "ben");
  assert.ok(hidden.body.requests[0].hiddenAt);
  const anaSees = await call("GET", `/api/events/${slug}/requests`, "ana");
  assert.equal(anaSees.body.requests[0].status, "pending");

  const accepted = await call("POST", `/api/requests/${id}/accept`, "ben");
  assert.equal(accepted.status, 200);
  assertSchema("RequestResult", accepted.body);
  assert.equal(accepted.body.request.status, "accepted");
  const conversationId = accepted.body.request.conversationId;
  assert.match(conversationId, /^[a-f\d]{24}$/);
  // Accepting twice returns the same conversation.
  const again = await call("POST", `/api/requests/${id}/accept`, "ben");
  assert.equal(again.body.request.conversationId, conversationId);

  const clientId = randomUUID();
  const message = await call("POST", `/api/conversations/${conversationId}/messages`, "ana", { clientId, body: "Hey Ben" });
  assert.equal(message.status, 201);
  assertSchema("Message", message.body.message);
  const retry = await call("POST", `/api/conversations/${conversationId}/messages`, "ana", { clientId, body: "Hey Ben" });
  assert.equal(retry.body.message.id, message.body.message.id);
  await call("POST", `/api/conversations/${conversationId}/messages`, "ben", { clientId: randomUUID(), body: "Hi Ana" });

  const list = await call("GET", `/api/events/${slug}/conversations`, "ben");
  assert.equal(list.status, 200);
  assert.equal(list.body.conversations.length, 1);
  const summary = list.body.conversations[0];
  assertSchema("ConversationSummary", summary);
  assert.equal(summary.kind, "dm");
  assert.equal(summary.peer.handle, "ana");
  assert.equal(summary.unreadCount, 1);
  assert.equal(summary.lastMessage.body, "Hi Ana");

  const read = await call("POST", `/api/conversations/${conversationId}/read`, "ben");
  assert.equal(read.status, 200);
  const afterRead = await call("GET", `/api/events/${slug}/conversations`, "ben");
  assert.equal(afterRead.body.conversations[0].unreadCount, 0);
  const anaList = await call("GET", `/api/events/${slug}/conversations`, "ana");
  assert.equal(anaList.body.conversations[0].peerLastReadAt, read.body.lastReadAt);

  const page = await call("GET", `/api/conversations/${conversationId}/messages?limit=1`, "ben");
  assertSchema("MessagePage", page.body);
  assert.equal(page.body.messages.length, 1);
  assert.equal(page.body.hasMore, true);
  assert.equal(page.body.messages[0].body, "Hi Ana");
  const older = await call("GET", `/api/conversations/${conversationId}/messages?before=${page.body.messages[0].id}`, "ben");
  assert.deepEqual(older.body.messages.map((m: any) => m.body), ["Hey Ben"]);
  assert.equal((await call("GET", `/api/conversations/${conversationId}/messages?before=${page.body.messages[0].id}&after=${page.body.messages[0].id}`, "ben")).status, 400);

  // Unsend: only the sender; then it's gone.
  const mine = message.body.message.id;
  assert.equal((await call("DELETE", `/api/conversations/${conversationId}/messages/${mine}`, "ben")).status, 403);
  assert.equal((await call("DELETE", `/api/conversations/${conversationId}/messages/${mine}`, "ana")).status, 200);
  assert.equal((await call("DELETE", `/api/conversations/${conversationId}/messages/${mine}`, "ana")).status, 404);

  // Not in the conversation: 404.
  assert.equal((await call("GET", `/api/conversations/${conversationId}/messages`, "cam")).status, 404);
});

test("a mutual personal request accepts the first one and opens one DM", async () => {
  const first = await send("cam", "dee");
  const mutual = await send("dee", "cam");
  assert.equal(mutual.status, 201);
  assert.equal(mutual.body.request.id, first.body.request.id);
  assert.equal(mutual.body.request.status, "accepted");
  assert.equal(mutual.body.request.direction, "incoming");
  assert.ok(mutual.body.request.conversationId);
  assert.equal(await ConversationModel.countDocuments({ event: eventId, kind: "dm" }), 2);
});

test("bad requests", async () => {
  assert.equal((await send("ana", "ana")).status, 400);
  assert.equal((await send("ana", "outsider")).status, 404);
  assert.equal((await send("outsider", "ana")).status, 403);
  assert.equal((await send("ana", "eve", { intro: "see https://evil.example" })).status, 400);
  assert.equal((await send("ana", "eve", { intro: "" })).status, 400);
  assert.equal((await call("POST", `/api/requests/${new Types.ObjectId()}/accept`, "ana")).status, 404);
  assert.equal((await call("POST", "/api/requests/nope/accept", "ana")).status, 400);
});

test("team requests need the owner and respect size and one team per person", async () => {
  const team = await call("POST", `/api/events/${slug}/teams`, "eve", { name: "Eve's Team", maxSize: 2 });
  assert.equal(team.status, 201);
  const teamId = team.body.id;

  // Must go to the owner.
  assert.equal((await send("fay", "ana", { teamId })).status, 400);
  const fayAsks = await send("fay", "eve", { teamId });
  assert.equal(fayAsks.status, 201);
  assert.deepEqual(fayAsks.body.request.team, { id: teamId, name: "Eve's Team" });
  const gusAsks = await send("gus", "eve", { teamId });
  // A reverse personal request never auto-accepts a team request.
  assert.equal((await send("eve", "fay")).body.request.status, "pending");

  const accepted = await call("POST", `/api/requests/${fayAsks.body.request.id}/accept`, "eve");
  assert.equal(accepted.status, 200);
  const members = (await TeamModel.findById(teamId).lean())!.members.map(String);
  assert.deepEqual(members.sort(), [people.eve.id.toString(), people.fay.id.toString()].sort());

  // Full now (maxSize 2): 409 and gus's request stays pending.
  const full = await call("POST", `/api/requests/${gusAsks.body.request.id}/accept`, "eve");
  assert.equal(full.status, 409);
  const evesView = await call("GET", `/api/events/${slug}/requests`, "eve");
  assert.equal(evesView.body.requests.find((r: any) => r.id === gusAsks.body.request.id).status, "pending");

  // Fay is on a team now, so she can't ask to join another.
  const other = await call("POST", `/api/events/${slug}/teams`, "gus", { name: "Gus Team" });
  assert.equal((await send("fay", "gus", { teamId: other.body.id })).status, 409);
});

test("blocks hide requests and conversations and stop messages", async () => {
  const before = await call("GET", `/api/events/${slug}/conversations`, "ana");
  const dm = before.body.conversations.find((c: any) => c.peer?.handle === "ben");
  assert.ok(dm);

  assert.equal((await call("POST", "/api/blocks", "ana", { userId: people.ben.id.toString() })).status, 200);
  assert.equal((await call("POST", "/api/blocks", "ana", { userId: people.ben.id.toString() })).status, 200);
  assert.equal((await call("POST", "/api/blocks", "ana", { userId: people.ana.id.toString() })).status, 400);
  assert.equal((await call("POST", "/api/blocks", "ana", { userId: "x" })).status, 400);

  for (const who of ["ana", "ben"]) {
    const list = await call("GET", `/api/events/${slug}/conversations`, who);
    assert.equal(list.body.conversations.some((c: any) => c.id === dm.id), false, who);
    const requests = await call("GET", `/api/events/${slug}/requests`, who);
    assert.equal(requests.body.requests.some((r: any) => ["ana", "ben"].includes(r.person.handle)), false, who);
  }
  const blockedSend = await call("POST", `/api/conversations/${dm.id}/messages`, "ben", { clientId: randomUUID(), body: "hello?" });
  assert.equal(blockedSend.status, 403);
  assert.equal((await send("ben", "ana")).status, 404);
});
