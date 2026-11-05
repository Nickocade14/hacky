import assert from "node:assert/strict";
import { after, before, test } from "node:test";
import { once } from "node:events";
import express from "express";
import mongoose, { Types } from "mongoose";
import { MongoMemoryReplSet } from "mongodb-memory-server";
import { connectDb, disconnectDb } from "../src/db.js";
import { errorHandler } from "../src/errors.js";
import { BlockModel } from "../src/models/Block.js";
import { EventModel } from "../src/models/Event.js";
import { MembershipModel } from "../src/models/Membership.js";
import { ProfileModel } from "../src/models/Profile.js";
import { searchHandler } from "../src/search.js";

let replica: MongoMemoryReplSet;
let viewer: Types.ObjectId;
let eventSlug: string;

before(async () => {
  // Isolated ephemeral database: NEVER connects to the user's Atlas cluster.
  replica = await MongoMemoryReplSet.create({ replSet: { count: 1 }, instanceOpts: [{ launchTimeout: 60_000 }] });
  await connectDb(replica.getUri("hacky_search_tests"));
  for (const name of mongoose.modelNames()) {
    await mongoose.model(name).createCollection();
    await mongoose.model(name).createIndexes();
  }

  const event = await EventModel.create({ slug: "knighthacks-ix", name: "Knight Hacks IX" });
  const outside = await EventModel.create({ slug: "demo-hacks", name: "Demo Hacks" });
  eventSlug = event.slug;

  async function member(handle: string, name: string, skills: string[], opts: {
    eventId?: Types.ObjectId; role?: "hacker" | "mentor"; viewer?: boolean;
  } = {}) {
    const _id = new Types.ObjectId();
    await ProfileModel.create({ _id, handle, name, isDemo: !opts.viewer });
    await MembershipModel.create({
      event: opts.eventId ?? event._id,
      user: _id,
      role: opts.role ?? "hacker",
      skills,
    });
    return _id;
  }

  viewer = await member("viewer", "Rea Viewer", [], { viewer: true });
  await member("react_pro", "Frontender", ["React"]); // prefix handle
  await member("jane", "Real Person", ["Java"]); // prefix name
  await member("breadwinner", "Bread Winner", ["C++"]); // handle contains
  await member("design_guru", "Nora", ["React Native", "Go"]); // skill only
  await member("react_mentor", "Mentor", ["React"], { role: "mentor" });
  const blocked = await member("react_blocked", "Blocked", ["React"]);
  const reverseBlocked = await member("react_hidden", "Hidden", ["React"]);
  await BlockModel.create({ blocker: viewer, blocked });
  await BlockModel.create({ blocker: reverseBlocked, blocked: viewer });
  await member("react_outsider", "Outsider", ["React"], { eventId: outside._id });
}, { timeout: 240_000 });

after(async () => {
  await disconnectDb();
  await replica?.stop();
});

async function withServer(
  authenticated: boolean,
  run: (base: string) => Promise<void>,
) {
  const app = express();
  app.get("/api/search", (req, res, next) => {
    if (authenticated) res.locals.profileId = viewer.toString();
    next();
  }, searchHandler);
  app.use(errorHandler);
  const server = app.listen(0, "127.0.0.1");
  try {
    await once(server, "listening");
    const address = server.address();
    assert.ok(address && typeof address !== "string");
    await run(`http://127.0.0.1:${address.port}`);
  } finally {
    await new Promise<void>((resolve) => { server.close(() => resolve()); server.closeAllConnections(); });
  }
}

test("case-insensitive partial search ranks names/handles first, excludes self/blocks/other events", async () => {
  await withServer(true, async (base) => {
    const response = await fetch(`${base}/api/search?event=${eventSlug}&q=ReA`);
    assert.equal(response.status, 200);
    const body = await response.json() as { results: Array<{
      userId: string; handle: string; name: string; skills: string[]; matchedSkills: string[];
    }> };
    assert.deepEqual(body.results.map((hit) => hit.handle), [
      "react_mentor", "react_pro", "jane", "breadwinner", "design_guru",
    ]);
    assert.deepEqual(body.results[0].matchedSkills, []);
    assert.deepEqual(body.results.at(-1)?.matchedSkills, ["React Native"]);
    assert.match(body.results[0].userId, /^[\da-f]{24}$/);
  });
});

test("role and limit work, and regex metacharacters are literal", async () => {
  await withServer(true, async (base) => {
    const mentor = await fetch(`${base}/api/search?event=${eventSlug}&q=react&role=mentor`);
    assert.equal(mentor.status, 200);
    assert.deepEqual((await mentor.json()).results.map((hit: { handle: string }) => hit.handle), ["react_mentor"]);

    const limited = await fetch(`${base}/api/search?event=${eventSlug}&q=rea&limit=1`);
    assert.equal(limited.status, 200);
    assert.equal((await limited.json()).results.length, 1);

    const plus = await fetch(`${base}/api/search?event=${eventSlug}&q=${encodeURIComponent("C++")}`);
    assert.equal(plus.status, 200);
    assert.deepEqual((await plus.json()).results.map((hit: { handle: string }) => hit.handle), ["breadwinner"]);
  });
});

test("401 unauthenticated, 400 invalid query and 403 not a member", async () => {
  await withServer(false, async (base) => {
    const response = await fetch(`${base}/api/search?event=${eventSlug}&q=rea`);
    assert.equal(response.status, 401);
    assert.equal((await response.json()).error.code, "unauthorized");
  });
  await withServer(true, async (base) => {
    for (const query of ["q=", "q=rea&limit=51", "q=rea&role=admin", "q=rea&limit=2.5"]) {
      const response = await fetch(`${base}/api/search?event=${eventSlug}&${query}`);
      assert.equal(response.status, 400);
      assert.equal((await response.json()).error.code, "invalid_input");
    }
    const response = await fetch(`${base}/api/search?event=demo-hacks&q=rea`);
    assert.equal(response.status, 403);
  });
});
