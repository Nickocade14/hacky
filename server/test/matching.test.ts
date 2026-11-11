import assert from "node:assert/strict";
import { after, before, test } from "node:test";
import mongoose, { Types } from "mongoose";
import { MongoMemoryReplSet } from "mongodb-memory-server";
import { connectDb, disconnectDb } from "../src/db.js";
import { fuseRanks, hybridMatch, keywordTerms, vectorPipeline } from "../src/matching/hybrid.js";
import { BlockModel } from "../src/models/Block.js";
import { ConnectionRequestModel } from "../src/models/ConnectionRequest.js";
import { EventModel } from "../src/models/Event.js";
import { MembershipModel } from "../src/models/Membership.js";
import { ProfileModel } from "../src/models/Profile.js";
import { TeamModel } from "../src/models/Team.js";

let replica: MongoMemoryReplSet;
let event: Types.ObjectId;
let viewer: Types.ObjectId;
const people = new Map<string, Types.ObjectId>();

async function member(handle: string, fields: Record<string, unknown> = {}, at = event) {
  const id = new Types.ObjectId();
  await ProfileModel.create({ _id: id, handle, name: handle.replace(/_/g, " ") });
  await MembershipModel.create({ event: at, user: id, role: "hacker", skills: [], ...fields });
  people.set(handle, id);
  return id;
}
const id = (handle: string) => people.get(handle)!;
const queryVector = Array.from({ length: 768 }, (_, index) => index === 0 ? 1 : 0);
const fakeVectors = (...handles: string[]) => async () => handles.map((handle) => id(handle).toString());
const args = (kind: "hacker" | "mentor" | "team" = "hacker", query = "Python") => ({
  viewerProfileId: viewer, eventSlug: "matching-tests", kind, query, queryVector,
});

before(async () => {
  // A temporary replica set, not the Atlas MONGODB_URI. No Gemini API requests.
  replica = await MongoMemoryReplSet.create({ replSet: { count: 1 }, instanceOpts: [{ launchTimeout: 60_000 }] });
  await connectDb(replica.getUri("hacky_matching_tests"));
  for (const model of [ProfileModel, EventModel, MembershipModel, TeamModel, BlockModel, ConnectionRequestModel]) {
    await model.createCollection();
    await model.createIndexes();
  }
  event = (await EventModel.create({ slug: "matching-tests", name: "Matching Tests" }))._id;
  const otherEvent = (await EventModel.create({ slug: "other-event", name: "Other" }))._id;
  viewer = await member("match_viewer", { skills: ["React"] });
  await member("python_dev", { skills: ["Python", "FastAPI"], interests: ["health tech"] });
  await member("backend_dev", { skills: ["Go", "Postgres"], interests: ["health tech"] });
  await member("blocked_dev", { skills: ["Python"] });
  await member("reverse_blocked", { skills: ["Python"] });
  await member("busy_dev", { skills: ["Python"], looking: false });
  await member("offline_dev", { skills: ["Python"], availability: "offline" });
  await member("sponsor_dev", { skills: ["Python"], role: "sponsor" });
  await member("outsider_dev", { skills: ["Python"] }, otherEvent);
  await member("requested_dev", { skills: ["Python"] });
  await member("mentor_dev", { role: "mentor", looking: false, verified: true, skills: ["OAuth", "Python"] });
  await member("offline_mentor", { role: "mentor", availability: "offline", skills: ["Python"] });
  await member("team_owner", { skills: ["React"] });
  await member("team_owner2", { skills: ["React"] });
  await BlockModel.create({ blocker: viewer, blocked: id("blocked_dev") });
  await BlockModel.create({ blocker: id("reverse_blocked"), blocked: viewer });
  await ConnectionRequestModel.create({ event, from: viewer, to: id("requested_dev"), intro: "Hi" });
  await TeamModel.create({ event, owner: id("team_owner"), members: [id("team_owner")],
    name: "Health Builders", idea: "Health platform", wantedSkills: ["React"], maxSize: 4 });
  await TeamModel.create({ event, owner: id("team_owner2"), members: [id("team_owner2")],
    name: "Full Team", wantedSkills: ["Python"], maxSize: 1 });
}, { timeout: 240_000 });

after(async () => {
  await disconnectDb();
  await replica?.stop();
});

test("RRF rewards documents found in both branches and has deterministic ties", () => {
  const scores = fuseRanks(["a", "b"], ["b", "c"]);
  assert.equal(scores[0].id, "b");
  assert.ok(scores[0].relevance > scores[1].relevance);
  assert.equal(fuseRanks(["a", "a"], ["b"]).length, 2);
  assert.equal(keywordTerms("Find a teammate with Python and Postgres"), "python postgres");
});

test("Atlas query starts with $vectorSearch and restricts event + ownerKind", () => {
  const pipeline = vectorPipeline(event, "member", queryVector, 10);
  const first = pipeline[0].$vectorSearch as Record<string, unknown>;
  assert.equal(first.index, "embedding_vector");
  assert.equal(first.path, "embedding");
  assert.deepEqual(first.filter, { event, ownerKind: "member" });
  assert.equal(first.numCandidates, 100);
  assert.equal(first.limit, 10);
});

test("hybrid matching uses real Mongo text search and simulated Atlas ranks", async () => {
  const results = await hybridMatch(args(), { searchVectors: fakeVectors("backend_dev", "python_dev") });
  const best = results[0];
  assert.equal(best.kind, "hacker");
  assert.equal(best.person.handle, "python_dev"); // Appears in both text + vector lists.
  assert.deepEqual(best.matchedSkills, ["Python"]);
  assert.ok(best.evidence.keywordRank !== null);
  assert.ok(best.evidence.vectorRank !== null);
  assert.ok(results.every((result) => !("embedding" in result)));
});

test("post-retrieval checks exclude viewer, blocks, requests, sponsors, not-looking and offline", async () => {
  const results = await hybridMatch(args(), {
    searchVectors: fakeVectors("match_viewer", "blocked_dev", "reverse_blocked", "requested_dev",
      "sponsor_dev", "busy_dev", "offline_dev", "outsider_dev", "python_dev"),
  });
  assert.deepEqual(results.map((result) => result.kind === "team" ? result.team.name : result.person.handle), ["python_dev"]);
});

test("mentor queries exclude offline mentors and do not require looking=true", async () => {
  const results = await hybridMatch(args("mentor"), { searchVectors: fakeVectors("offline_mentor", "mentor_dev") });
  assert.deepEqual(results.map((result) => result.kind === "team" ? "" : result.person.handle), ["mentor_dev"]);
});

test("team matching removes full teams and returns public team data without vectors", async () => {
  const teams = await TeamModel.find({ event }).lean();
  const full = teams.find((team) => team.name === "Full Team")!;
  const available = teams.find((team) => team.name === "Health Builders")!;
  const results = await hybridMatch(args("team", "React health project"), {
    searchVectors: async () => [full._id.toString(), available._id.toString()],
  });
  assert.equal(results.length, 1);
  assert.equal(results[0].kind, "team");
  if (results[0].kind === "team") {
    assert.equal(results[0].team.name, "Health Builders");
    assert.deepEqual(results[0].matchedSkills, ["React"]);
    assert.ok(!("embedding" in results[0].team));
  }
});

test("event membership is mandatory and invalid query input is rejected", async () => {
  await assert.rejects(hybridMatch({ ...args(), eventSlug: "other-event" }, { searchVectors: fakeVectors("python_dev") }),
    (error: any) => error.status === 403);
  await assert.rejects(hybridMatch({ ...args(), query: " " }, { searchVectors: fakeVectors("python_dev") }),
    (error: any) => error.status === 400);
});
