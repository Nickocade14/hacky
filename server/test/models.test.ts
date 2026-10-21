import assert from "node:assert/strict";
import { createHash, randomUUID } from "node:crypto";
import { before, after, test } from "node:test";
import mongoose, { Types } from "mongoose";
import { MongoMemoryReplSet } from "mongodb-memory-server";
import { connectDb, disconnectDb } from "../src/db.js";
import {
  AuthTokenModel, issueAuthToken, consumeAuthToken,
  TeamModel, createTeam, addTeamMember,
  ConversationModel, openDm, listConversations, MessageModel, createMessage, listMessages,
  ConnectionRequestModel,
} from "../src/models/index.js";

const id = () => new Types.ObjectId();
let replica: MongoMemoryReplSet;
before(async () => {
  // Always a throwaway database, never MONGODB_URI from the user's environment.
  replica = await MongoMemoryReplSet.create({ replSet: { count: 1 }, instanceOpts: [{ launchTimeout: 60_000 }] });
  await connectDb(replica.getUri("hacky_tests"));
  for (const name of mongoose.modelNames()) {
    await mongoose.model(name).createCollection();
    await mongoose.model(name).createIndexes();
  }
}, { timeout: 240_000 });
after(async () => {
  await disconnectDb();
  await replica?.stop();
});

test("concurrent token issuance leaves one live token, consumed at most once", async () => {
  const user = id();
  const tokens = await Promise.all(Array.from({ length: 8 }, () => issueAuthToken(user, "reset-password", 15)));
  const rows = await AuthTokenModel.find({ user, kind: "reset-password" });
  assert.equal(rows.length, 1);
  const raw = tokens.find((token) => createHash("sha256").update(token).digest("hex") === rows[0].tokenHash);
  assert.ok(raw);
  const consumed = await Promise.all([consumeAuthToken(raw, "reset-password"), consumeAuthToken(raw, "reset-password")]);
  assert.equal(consumed.filter(Boolean).length, 1);
  const expired = await issueAuthToken(user, "reset-password", 15);
  await AuthTokenModel.updateOne({ user }, { $set: { expiresAt: new Date(0) } });
  assert.equal(await consumeAuthToken(expired, "reset-password"), null);
  const verify = await issueAuthToken(user, "verify-email", 15);
  assert.equal(await consumeAuthToken(verify, "reset-password"), null);
  assert.ok(await consumeAuthToken(verify, "verify-email"));
});

test("invalid/null members return ValidationError and owners count as members", async () => {
  const event = id(), owner = id(), peer = id();
  for (const members of [null, [null], [], [owner, owner], [peer]]) {
    await assert.rejects(new TeamModel({ event, owner, name: "Invalid", members }).validate(), mongoose.Error.ValidationError);
  }
  await assert.rejects(new TeamModel({ event, owner, name: "Invalid", members: [owner], maxSize: 1.5 }).validate(), mongoose.Error.ValidationError);
  const [low, high] = [owner, peer].sort((a, b) => a.toString().localeCompare(b.toString()));
  for (const members of [null, [null], [{}], [{ user: owner }]]) {
    await assert.rejects(new ConversationModel({ event, kind: "dm", dmUserLow: low, dmUserHigh: high, members }).validate(), mongoose.Error.ValidationError);
  }
  const team = await createTeam({ event, owner, name: "Valid" });
  assert.deepEqual(team.members.map(String), [String(owner)]);
  for (const kind of ["text", "card"]) {
    await assert.rejects(new MessageModel({ conversation: id(), body: "Hello", kind }).validate(), mongoose.Error.ValidationError);
  }
  await new MessageModel({ conversation: id(), body: "Welcome", kind: "system" }).validate();
});

test("concurrent joins enforce capacity and one team per event", async () => {
  const event = id(), owner = id();
  const team = await createTeam({ event, owner, name: "Small", maxSize: 2 });
  const results = await Promise.all([addTeamMember(team._id, id()), addTeamMember(team._id, id())]);
  assert.equal(results.filter(Boolean).length, 1);
  assert.equal((await TeamModel.findById(team._id))?.members.length, 2);
  assert.ok(await addTeamMember(team._id, owner)); // Idempotent even when full.
  const first = await createTeam({ event, owner: id(), name: "First" });
  const second = await createTeam({ event, owner: id(), name: "Second" });
  const applicant = id();
  const attempts = await Promise.allSettled([addTeamMember(first._id, applicant), addTeamMember(second._id, applicant)]);
  assert.equal(attempts.filter((result) => result.status === "fulfilled").length, 1);
  assert.equal(await TeamModel.countDocuments({ event, members: applicant }), 1);
  await assert.rejects(createTeam({ event, owner: applicant, name: "Another" }), (error: any) => error.code === 11000);
  assert.ok(await createTeam({ event: id(), owner: applicant, name: "Different event" }));
});

test("message writes advance activity transactionally and retries do not duplicate or reorder", async () => {
  const event = id(), sender = id(), peer = id();
  const conversation = await openDm(event, sender, peer);
  await ConversationModel.updateOne({ _id: conversation._id }, { $set: { lastMessageAt: new Date(0) } });
  const input = { conversation: conversation._id, sender, body: "Hello", clientId: randomUUID() };
  const sent = await Promise.all([createMessage(input), createMessage(input)]);
  assert.equal(String(sent[0]._id), String(sent[1]._id));
  assert.equal(await MessageModel.countDocuments({ conversation: conversation._id }), 1);
  const activity = (await ConversationModel.findById(conversation._id))!.lastMessageAt;
  assert.equal(activity.getTime(), sent[0].createdAt.getTime());
  await createMessage(input);
  assert.equal((await ConversationModel.findById(conversation._id))!.lastMessageAt.getTime(), activity.getTime());
  await assert.rejects(createMessage({ ...input, body: "Different" }), (error: any) => error.status === 409);
  const missing = id();
  await assert.rejects(createMessage({ conversation: missing, sender, body: "Orphan" }), (error: any) => error.status === 404);
  assert.equal(await MessageModel.countDocuments({ conversation: missing }), 0);
  const future = new Date(Date.now() + 60_000);
  await ConversationModel.updateOne({ _id: conversation._id }, { $set: { lastMessageAt: future } });
  await createMessage({ conversation: conversation._id, body: "System update", kind: "system" });
  assert.equal((await ConversationModel.findById(conversation._id))!.lastMessageAt.getTime(), future.getTime());
  const otherConversation = await openDm(event, sender, id());
  const ordered = await listConversations(event, sender);
  assert.deepEqual(ordered.map((entry) => String(entry._id)), [String(conversation._id), String(otherConversation._id)]);
  assert.equal((await listConversations(id(), sender)).length, 0);
});

test("ObjectId pagination has no skips or repeats when timestamps tie", async () => {
  const conversation = id(), sender = id(), timestamp = new Date();
  const messages = await MessageModel.create(Array.from({ length: 7 }, (_, index) => ({ conversation, sender, body: String(index), createdAt: timestamp })));
  const expected = messages.map((message) => String(message._id)).sort();
  const newest = await listMessages(conversation, { limit: 2 });
  assert.deepEqual(newest.messages.map((message) => String(message._id)), expected.slice(-2));
  assert.equal(newest.hasMore, true);
  const older = await listMessages(conversation, { before: newest.messages[0]._id, limit: 2 });
  assert.deepEqual(older.messages.map((message) => String(message._id)), expected.slice(3, 5));
  const caughtUp: string[] = [];
  let cursor = messages[0]._id;
  while (true) {
    const page = await listMessages(conversation, { after: cursor, limit: 2 });
    caughtUp.push(...page.messages.map((message) => String(message._id)));
    if (!page.hasMore) break;
    cursor = page.messages.at(-1)!._id;
  }
  assert.deepEqual(caughtUp, expected.slice(1));
  const plan = await MessageModel.collection.find({ conversation, _id: { $lt: messages.at(-1)!._id } }).sort({ _id: -1 }).explain("queryPlanner");
  assert.ok(JSON.stringify(plan.queryPlanner.winningPlan).includes("conversation_1__id_-1"));
  assert.ok(!JSON.stringify(plan.queryPlanner.winningPlan).includes('"stage":"SORT"'));
});

test("an existing personal connection does not block a separate team join request", async () => {
  const event = id(), from = id(), to = id(), team = id();
  const personal = { event, from, to, intro: "Let's connect" };
  await ConnectionRequestModel.create({ ...personal, status: "accepted" });
  await ConnectionRequestModel.create({ ...personal, team, intro: "I'd like to join your team" });
  await assert.rejects(ConnectionRequestModel.create(personal), (error: any) => error.code === 11000);
  await assert.rejects(ConnectionRequestModel.create({ ...personal, team }), (error: any) => error.code === 11000);
});
