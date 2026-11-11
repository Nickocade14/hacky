/**
 * Read-only Atlas smoke test. Requires the user's local server/.env.
 *
 * From server/:
 *   node --env-file=.env --import tsx src/scripts/check-matching.ts --kind=hacker --query="backend health tech"
 *   node --env-file=.env --import tsx src/scripts/check-matching.ts --kind=mentor --query="OAuth"
 *   node --env-file=.env --import tsx src/scripts/check-matching.ts --kind=team --query="health React"
 *
 * Does not create/update/delete documents. An embedding query may use Gemini quota.
 */
import mongoose from "mongoose";
import { hybridMatch, type MatchKind } from "../matching/hybrid.js";
import { ProfileModel } from "../models/Profile.js";

const flags = new Map(process.argv.slice(2).map((arg) => {
  const match = /^--([a-z]+)=(.+)$/.exec(arg);
  if (!match) throw new Error(`Invalid argument: ${arg}`);
  return [match[1], match[2]] as const;
}));
if ([...flags.keys()].some((key) => !["kind", "query", "event", "viewer"].includes(key))) {
  throw new Error("Supported options: --kind --query --event --viewer");
}
const kind = flags.get("kind") ?? "hacker";
const query = flags.get("query") ?? "backend health tech";
const eventSlug = flags.get("event") ?? "knighthacks-ix";
const viewerHandle = flags.get("viewer") ?? "demo_you";
if (!["hacker", "mentor", "team"].includes(kind)) throw new Error("--kind must be hacker, mentor or team");
const uri = process.env.MONGODB_URI;
if (!uri || new URL(uri).pathname !== "/hacky") throw new Error("MONGODB_URI must explicitly select /hacky");

await mongoose.connect(uri, { autoIndex: false, serverSelectionTimeoutMS: 10_000 });
try {
  const viewer = await ProfileModel.findOne({ handle: viewerHandle }).select("_id").lean();
  if (!viewer) throw new Error(`No profile found for --viewer=${viewerHandle}`);
  const results = await hybridMatch({ viewerProfileId: viewer._id, eventSlug, kind: kind as MatchKind, query });
  console.log(`Database: ${mongoose.connection.db!.databaseName}`);
  console.log(`Event: ${eventSlug}; viewer: ${viewerHandle}; kind: ${kind}; query: ${query}`);
  console.log(`Results: ${results.length}; vector query enabled: ${Boolean(process.env.GOOGLE_GENERATIVE_AI_API_KEY)}`);
  console.table(results.map((result) => ({
    name: result.kind === "team" ? result.team.name : result.person.name,
    score: result.score,
    matchedSkills: result.matchedSkills.join(", "),
    keywordRank: result.evidence.keywordRank ?? "—",
    vectorRank: result.evidence.vectorRank ?? "—",
  })));
} finally {
  await mongoose.disconnect();
}
