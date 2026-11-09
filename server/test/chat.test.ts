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
import type { RankInput, RankOutput } from "../src/chat/gemini.js";
import { connectDb, disconnectDb } from "../src/db.js";
import { HttpError } from "../src/errors.js";
import { AgentMessageModel } from "../src/models/AgentMessage.js";
import { BlockModel } from "../src/models/Block.js";
import { EventModel } from "../src/models/Event.js";
import { MembershipModel } from "../src/models/Membership.js";
import { ProfileModel } from "../src/models/Profile.js";

process.env.JWT_SECRET = "test-secret-that-is-at-least-32-characters-long";

let replica: MongoMemoryReplSet;
let base: string;
let server: ReturnType<ReturnType<typeof createApp>["listen"]>;
let chatMessageSchema: object;
const ajv = new Ajv({ strict: false, validateFormats: false });

// Each test sets what the fake ranker does.
let calls: RankInput[] = [];
let nextRank: (input: RankInput) => Promise<RankOutput> = async () => ({ reply: "", matches: [] });

const ids: Record<string, Types.ObjectId> = {};
let token: string;

async function person(handle: string, event: Types.ObjectId | null, membership: Record<string, unknown> = {}) {
  const id = new Types.ObjectId();
  await ProfileModel.create({ _id: id, handle, name: handle.toUpperCase() });
  if (event) await MembershipModel.create({ event, user: id, role: "hacker", ...membership });
  ids[handle] = id;
  return id;
}

before(async () => {
  // Isolated ephemeral database: NEVER connects to the user's Atlas cluster.
  replica = await MongoMemoryReplSet.create({ replSet: { count: 1 }, instanceOpts: [{ launchTimeout: 60_000 }] });
  await connectDb(replica.getUri("hacky_chat_tests"));
  for (const name of mongoose.modelNames()) {
    await mongoose.model(name).createCollection();
    await mongoose.model(name).createIndexes();
  }
  const rank = (input: RankInput) => { calls.push(input); return nextRank(input); };
  server = createApp({ mailer: { send: async () => {} }, rank }).listen(0, "127.0.0.1");
  await once(server, "listening");
  const address = server.address();
  assert.ok(address && typeof address !== "string");
  base = `http://127.0.0.1:${address.port}`;
  const api = await SwaggerParser.dereference(fileURLToPath(new URL("../../docs/openapi.yaml", import.meta.url)));
  chatMessageSchema = (api as any).components.schemas.ChatMessage;

  const event = (await EventModel.create({ slug: "knighthacks-ix", name: "Knight Hacks IX", tracks: ["Fintech"] }))._id;
  const other = (await EventModel.create({ slug: "demo-hacks", name: "Demo Hacks" }))._id;
  const lonely = (await EventModel.create({ slug: "lonely-hacks", name: "Lonely Hacks" }))._id;

  const viewer = await person("viewer", event, { skills: ["Flutter"] });
  await person("react_dev", event, { skills: ["React", "TypeScript"], summary: "Frontend person" });
  await person("cpp_dev", event, { skills: ["C++"] });
  await person("busy_dev", event, { skills: ["React"], looking: false });
  await person("go_dev", event, { skills: ["Go"] });
  await person("mentor_mo", event, { role: "mentor", looking: false, verified: true, skills: ["React"] });
  const blocked = await person("blocked_dev", event, { skills: ["React"] });
  const blocker = await person("blocker_dev", event, { skills: ["React"] });
  await person("elsewhere", other, { skills: ["React"] });
  await BlockModel.create({ blocker: viewer, blocked });
  await BlockModel.create({ blocker, blocked: viewer });
  token = signToken(viewer).token;
  await MembershipModel.create({ event: lonely, user: viewer, role: "hacker" });
}, { timeout: 240_000 });

after(async () => {
  await new Promise<void>((resolve) => { server.close(() => resolve()); server.closeAllConnections(); });
  await disconnectDb();
  await replica.stop();
});

async function call(method: string, path: string, body?: unknown, auth = token) {
  const response = await fetch(`${base}${path}`, {
    method,
    headers: {
      ...(body === undefined ? {} : { "Content-Type": "application/json" }),
      ...(auth ? { Authorization: `Bearer ${auth}` } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  return { status: response.status, body: await response.json() as any };
}

let n = 0;
const message = (text: string, id = `mobile-${Date.now()}-${n++}`) =>
  ({ message: { id, role: "user", parts: [{ type: "text", text }] } });
const post = (text: string, id?: string, slug = "knighthacks-ix") =>
  call("POST", `/api/events/${slug}/chat?format=json`, message(text, id));

// The ref the fake ranker was given for this handle.
const refFor = (input: RankInput, handle: string) =>
  input.candidates.find((c) => c.line.includes(`(@${handle})`))?.ref;

test("401 without a token", async () => {
  assert.equal((await call("GET", "/api/events/knighthacks-ix/chat", undefined, "")).status, 401);
  assert.equal((await call("POST", "/api/events/knighthacks-ix/chat?format=json", message("hi"), "")).status, 401);
});

test("400 for bad input", async () => {
  const bad = [
    { message: { id: "a1", role: "assistant", parts: [{ type: "text", text: "hi" }] } },
    { message: { id: "a2", role: "user", parts: [{ type: "text", text: "   " }] } },
    { message: { id: "a3", role: "user", parts: [{ type: "text", text: "x".repeat(1001) }] } },
    { message: { id: "a b", role: "user", parts: [{ type: "text", text: "hi" }] } },
    { message: { id: "reply-1", role: "user", parts: [{ type: "text", text: "hi" }] } },
  ];
  for (const body of bad) {
    const response = await call("POST", "/api/events/knighthacks-ix/chat?format=json", body);
    assert.equal(response.status, 400, JSON.stringify(body));
    assert.equal(response.body.error.code, "invalid_input");
  }
  assert.equal((await call("POST", "/api/events/knighthacks-ix/chat?format=xml", message("hi"))).status, 400);
});

test("403 for unknown events and events I'm not in", async () => {
  assert.equal((await post("hi", undefined, "nope-hacks")).status, 403);
  assert.equal((await post("hi", undefined, "demo-hacks")).status, 403);
  assert.equal((await call("GET", "/api/events/demo-hacks/chat")).status, 403);
});

test("501 for streaming until it lands", async () => {
  const response = await call("POST", "/api/events/knighthacks-ix/chat", message("hi"));
  assert.equal(response.status, 501);
  assert.equal(response.body.error.code, "not_implemented");
});

let happyId = "";
let suggestedId = "";

test("happy path: validated cards, saved history and an idempotent retry", async () => {
  calls = [];
  nextRank = async (input) => {
    const ref = refFor(input, "react_dev")!;
    return { reply: "Meet @react_dev and @ghost!", matches: [
      { ref, reason: "Builds React and TypeScript UIs." }, { ref: "p999", reason: "x" }, { ref, reason: "again" },
    ] };
  };
  happyId = "mobile-1762560000000000-0";
  const response = await post("Find a teammate who knows React", happyId);
  assert.equal(response.status, 200);
  const reply = response.body.message;
  assert.equal(ajv.compile(chatMessageSchema)(reply), true);
  assert.equal(reply.id, `reply-${happyId}`);
  assert.equal(reply.role, "assistant");
  assert.deepEqual(reply.parts[0], { type: "text", text: "Meet @react_dev and ghost!" });
  const tool = reply.parts[1];
  assert.equal(tool.type, "tool-search_people");
  assert.equal(tool.state, "output-available");
  assert.match(tool.toolCallId, /^call-[0-9a-f-]{36}$/);
  assert.deepEqual(tool.input, { query: "Find a teammate who knows React" });
  assert.equal(tool.output.status, "matches");
  assert.equal(tool.output.kind, "hacker");
  assert.equal(tool.output.cards.length, 1);
  const card = tool.output.cards[0];
  assert.equal(card.card, "person");
  assert.match(card.person.userId, /^[a-f\d]{24}$/);
  suggestedId = card.person.userId;
  assert.deepEqual(card.person, {
    userId: ids.react_dev.toString(), handle: "react_dev", name: "REACT_DEV", hackyStyle: {}, photoUrl: null, role: "hacker",
  });
  assert.deepEqual(card.skills, ["React", "TypeScript"]);
  assert.deepEqual(card.evidence, { matchedSkills: ["React"] });
  assert.equal(card.reason, "Builds React and TypeScript UIs.");

  // Who Gemini was allowed to see.
  assert.equal(calls.length, 1);
  const seen = calls[0].candidates.map((c) => c.line).join("\n");
  for (const hidden of ["viewer", "blocked_dev", "blocker_dev", "busy_dev", "mentor_mo", "elsewhere"]) {
    assert.equal(seen.includes(`(@${hidden})`), false, hidden);
  }
  assert.equal(calls[0].intent, "teammate");
  assert.ok(calls[0].viewerLine.includes("(@viewer)"));

  const history = await call("GET", "/api/events/knighthacks-ix/chat");
  assert.equal(history.status, 200);
  assert.deepEqual(history.body.messages.map((m: any) => [m.id, m.role]), [[happyId, "user"], [`reply-${happyId}`, "assistant"]]);
  assert.deepEqual(history.body.messages[0].parts, [{ type: "text", text: "Find a teammate who knows React" }]);

  // Retry with the same id: same answer, no second Gemini call.
  const retry = await post("Find a teammate who knows React", happyId);
  assert.deepEqual(retry.body.message, reply);
  assert.equal(calls.length, 1);
});

test("mentor intent only offers mentors, and the next turn sends history", async () => {
  calls = [];
  nextRank = async (input) => ({ reply: "Mo can help.", matches: [{ ref: refFor(input, "mentor_mo")!, reason: "Mentors React." }] });
  const response = await post("find a mentor");
  assert.equal(response.status, 200);
  assert.equal(calls[0].intent, "mentor");
  assert.equal(calls[0].candidates.length, 1);
  assert.ok(calls[0].candidates[0].line.includes("(@mentor_mo)"));
  assert.ok(calls[0].history.some((line) => line.includes("[suggested: @react_dev]")));
  const card = response.body.message.parts[1].output.cards[0];
  assert.equal(card.card, "mentor");
  assert.equal(card.verified, true);
  assert.equal(card.evidence.availability, "available");
});

test("matchedSkills handles C++ and invalid refs fall back to text only", async () => {
  nextRank = async (input) => ({ reply: "", matches: [{ ref: refFor(input, "cpp_dev")!, reason: "" }] });
  const cpp = await post("anyone good at C++?");
  const card = cpp.body.message.parts[1].output.cards[0];
  assert.deepEqual(card.evidence.matchedSkills, ["C++"]);
  assert.equal(card.reason, "Knows C++.");
  assert.equal(cpp.body.message.parts[0].text, "Here's who could help. Tap a card to see their profile or connect.");

  nextRank = async () => ({ reply: "", matches: [{ ref: "p404", reason: "nope" }] });
  const none = await post("anyone good at go?");
  assert.equal(none.body.message.parts.length, 1);
  assert.equal(none.body.message.parts[0].type, "text");
});

test("no candidates: a text answer without calling Gemini", async () => {
  calls = [];
  const response = await post("Find a teammate who knows React", undefined, "lonely-hacks");
  assert.equal(response.status, 200);
  assert.deepEqual(response.body.message.parts, [{ type: "text", text: "There's no one at this event I can suggest for that yet." }]);
  assert.equal(calls.length, 0);
});

test("Gemini errors map to 504 and 503 and save nothing", async () => {
  nextRank = async () => { throw new DOMException("x", "TimeoutError"); };
  const timeout = await post("Find a teammate who knows React", "timeout-1");
  assert.equal(timeout.status, 504);
  assert.equal(timeout.body.error.code, "ai_timeout");
  assert.equal(await AgentMessageModel.countDocuments({ messageId: { $in: ["timeout-1", "reply-timeout-1"] } }), 0);

  nextRank = async () => { throw new HttpError(503, "ai_unavailable", "Hacky is offline right now. Please try again later."); };
  const offline = await post("Find a teammate who knows React", "offline-1");
  assert.equal(offline.status, 503);
  assert.equal(offline.body.error.code, "ai_unavailable");
});

test("a person blocked later disappears from old cards", async () => {
  await BlockModel.create({ blocker: ids.viewer, blocked: new Types.ObjectId(suggestedId) });
  const history = await call("GET", "/api/events/knighthacks-ix/chat");
  const reply = history.body.messages.find((m: any) => m.id === `reply-${happyId}`);
  assert.deepEqual(reply.parts.map((p: any) => p.type), ["text"]);
});
