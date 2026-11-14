import assert from "node:assert/strict";
import { after, before, test } from "node:test";
import mongoose, { Types } from "mongoose";
import { MongoMemoryReplSet } from "mongodb-memory-server";
import { summaryLine } from "../src/chat/candidates.js";
import { connectDb, disconnectDb } from "../src/db.js";
import { hybridChatCandidates } from "../src/matching/chat-candidates.js";
import { BlockModel } from "../src/models/Block.js";
import { ConnectionRequestModel } from "../src/models/ConnectionRequest.js";
import { EventModel } from "../src/models/Event.js";
import { MembershipModel } from "../src/models/Membership.js";
import { ProfileModel } from "../src/models/Profile.js";

let replica: MongoMemoryReplSet;
let event: Types.ObjectId;
let viewer: Types.ObjectId;
const people = new Map<string, Types.ObjectId>();
const vector = Array.from({ length: 768 }, (_, index) => index === 0 ? 1 : 0);

async function member(handle: string, props: Record<string, unknown> = {}, at = event) {
  const id = new Types.ObjectId();
  await ProfileModel.create({ _id: id, handle, name: handle.replaceAll("_", " ") });
  await MembershipModel.create({ event: at, user: id, role: "hacker", skills: [], ...props });
  people.set(handle, id);
  return id;
}
const id = (handle: string) => people.get(handle)!;
const input = (text: string, intent: "teammate" | "mentor" = "teammate", excluded: Types.ObjectId[] = []) => ({
  eventId: event,
  eventSlug: "chat-matching",
  viewerProfileId: viewer,
  excludedProfileIds: excluded,
  text,
  intent,
  queryVector: vector,
});
const searchVectors = (...handles: string[]) => async () => handles.map((handle) => id(handle).toString());

before(async () => {
  // All integration tests use an isolated in-memory replica set, never Atlas.
  replica = await MongoMemoryReplSet.create({ replSet: { count: 1 }, instanceOpts: [{ launchTimeout: 60_000 }] });
  await connectDb(replica.getUri("hacky_chat_matching_tests"));
  for (const model of [ProfileModel, EventModel, MembershipModel, BlockModel, ConnectionRequestModel]) {
    await model.createCollection();
    await model.createIndexes();
  }
  event = (await EventModel.create({ slug: "chat-matching", name: "Chat matching" }))._id;
  const other = (await EventModel.create({ slug: "another-hack", name: "Other event" }))._id;
  viewer = await member("chat_viewer", { skills: ["React"] });
  await member("python_builder", {
    skills: ["Python", "FastAPI"], skillsWanted: ["React"],
    interests: ["health tech"], experience: "intermediate", summary: "Builds APIs for clinics",
  });
  await member("python_contact", { skills: ["Python"] });
  await member("python_blocked", { skills: ["Python"] });
  await member("python_busy", { skills: ["Python"], looking: false });
  await member("python_outside", { skills: ["Python"] }, other);
  await member("mentor_good", { role: "mentor", skills: ["OAuth"], looking: false, verified: true });
  await member("mentor_offline", { role: "mentor", skills: ["OAuth"], availability: "offline" });
  await BlockModel.create({ blocker: viewer, blocked: id("python_blocked") });
}, { timeout: 240_000 });

after(async () => {
  await disconnectDb();
  await replica?.stop();
});

test("adapts hybrid-ranked members into the existing chat CandidateRow shape", async () => {
const rows = await hybridChatCandidates(input("Find Python for health tech", "teammate", [id("python_contact")]), {    searchVectors: searchVectors("python_builder", "python_busy"),
  });
  assert.deepEqual(rows.map((row) => row.profile.handle), ["python_builder"]);
  assert.deepEqual(rows[0].skills, ["Python", "FastAPI"]);
  assert.deepEqual(rows[0].skillsWanted, ["React"]);
  assert.match(summaryLine(rows[0], "p1"), /wants: React/);
  assert.match(summaryLine(rows[0], "p1"), /Builds APIs for clinics/);
  assert.equal("embedding" in rows[0], false);
});

test("excludes already-in-touch IDs supplied by chat, blocked users, and other events", async () => {
  const rows = await hybridChatCandidates(input("Python", "teammate", [id("python_contact")]), {
    searchVectors: searchVectors("python_contact", "python_blocked", "python_outside", "python_builder"),
  });
  assert.deepEqual(rows.map((row) => row.profile.handle), ["python_builder"]);
});

test("mentor intent keeps mentors who are not looking, with verified status", async () => {
  const rows = await hybridChatCandidates(input("OAuth mentor", "mentor"), {
    searchVectors: searchVectors("mentor_offline", "mentor_good"),
  });
  assert.deepEqual(rows.map((row) => row.profile.handle), ["mentor_good"]);
  assert.equal(rows[0].role, "mentor");
  assert.equal(rows[0].verified, true);
});

test("handles chat messages longer than hybrid's 300-character input limit", async () => {
  const rows = await hybridChatCandidates(input(`Python ${"health ".repeat(60)}`), {
    searchVectors: searchVectors("python_builder"),
  });
  assert.equal(rows[0].profile.handle, "python_builder");
});

test("does not bypass event membership authorization", async () => {
  await assert.rejects(hybridChatCandidates({ ...input("Python"), eventSlug: "another-hack" }, {
    searchVectors: searchVectors("python_builder"),
  }), (error: unknown) => (error as { status?: number }).status === 403);
});

test("returns no candidates for filler-only queries without semantic search", async () => {
  const rows = await hybridChatCandidates({ ...input("Find a mentor", "mentor"), queryVector: null });
  assert.deepEqual(rows, []);
  // The chat route should preserve its existing loadCandidates() fallback.
});
