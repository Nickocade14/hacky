/**
 * Backfill Knight Hacks IX vectors in the Atlas `embeddings` collection.
 *
 * Preview (read-only):
 *   node --env-file=.env --import tsx src/scripts/seed-embeddings.ts
 * Small live test:
 *   node --env-file=.env --import tsx src/scripts/seed-embeddings.ts --apply --confirm=hacky --limit=3
 * Resume the rest (safe to rerun):
 *   node --env-file=.env --import tsx src/scripts/seed-embeddings.ts --apply --confirm=hacky
 *
 * Inserts MISSING vectors only. Existing vectors and all non-embedding
 * collections are never modified. Does not create User/login accounts.
 * Live calls to Gemini may use paid API quota.
 */
import mongoose from "mongoose";
import { embedDocument, memberProfileText, teamProfileText } from "../embeddings.js";
import { EmbeddingModel } from "../models/Embedding.js";
import { EventModel } from "../models/Event.js";
import { MembershipModel } from "../models/Membership.js";
import { ProfileModel } from "../models/Profile.js";
import { TeamModel } from "../models/Team.js";

const EVENT_SLUG = "knighthacks-ix";
const apply = process.argv.includes("--apply");
const confirm = process.argv.includes("--confirm=hacky");
const limitArg = process.argv.find((arg) => arg.startsWith("--limit="));
const limitText = limitArg?.slice("--limit=".length);
const limit = limitText === undefined ? Number.POSITIVE_INFINITY : Number(limitText);
if (limitText !== undefined && (!/^\d+$/.test(limitText) || !Number.isSafeInteger(limit) || limit < 1)) {
  throw new Error("--limit must be a positive whole number (e.g. --limit=3).");
}
for (const arg of process.argv.slice(2)) {
  if (arg !== "--apply" && arg !== "--confirm=hacky" && !arg.startsWith("--limit=")) {
    throw new Error(`Unknown argument: ${arg}`);
  }
}
if (apply && !confirm) throw new Error("Writing requires --apply --confirm=hacky.");
if (!apply && (confirm || limitText !== undefined)) {
  throw new Error("--confirm=hacky and --limit require --apply.");
}

const uri = process.env.MONGODB_URI;
if (!uri) throw new Error("MONGODB_URI is missing from server/.env.");
if (new URL(uri).pathname !== "/hacky") {
  throw new Error("Refusing to connect: MONGODB_URI must explicitly select /hacky.");
}
if (apply && !process.env.GOOGLE_GENERATIVE_AI_API_KEY) {
  throw new Error("Add GOOGLE_GENERATIVE_AI_API_KEY to server/.env before --apply.");
}

type Job = {
  ownerKind: "member" | "team";
  ownerId: mongoose.Types.ObjectId;
  label: string;
  text: string;
};
const keyOf = (job: Pick<Job, "ownerKind" | "ownerId">): string =>
  `${job.ownerKind}:${job.ownerId.toString()}`;

await mongoose.connect(uri, { autoIndex: false });
try {
  const event = await EventModel.findOne({ slug: EVENT_SLUG }).select("_id").lean();
  if (!event) throw new Error(`${EVENT_SLUG} is not seeded in the hacky database.`);

  // Resolve member profile IDs from event memberships, not from login User docs.
  const [memberships, teams] = await Promise.all([
    MembershipModel.find({ event: event._id }).select("user skills interests track idea summary motivations").lean(),
    TeamModel.find({ event: event._id }).select("name idea track wantedSkills").lean(),
  ]);
  const profiles = await ProfileModel.find({ _id: { $in: memberships.map((m) => m.user) } })
    .select("_id handle").lean();
  const handles = new Map(profiles.map((profile) => [profile._id.toString(), profile.handle]));

  const jobs: Job[] = [];
  for (const member of memberships) {
    if (!handles.has(member.user.toString())) {
      throw new Error(`Missing Profile for membership ${member.user.toString()}.`);
    }
    const text = memberProfileText(member);
    if (!text) continue; // Members without matching information aren't useful vectors.
    jobs.push({ ownerKind: "member", ownerId: member.user, label: handles.get(member.user.toString())!, text });
  }
  for (const team of teams) {
    const text = teamProfileText(team);
    if (!text) continue;
    jobs.push({ ownerKind: "team", ownerId: team._id, label: team.name, text });
  }
  jobs.sort((a, b) => keyOf(a).localeCompare(keyOf(b)));

  const existing = await EmbeddingModel.find({ event: event._id }).select("ownerKind ownerId").lean();
  const existingKeys = new Set(existing.map((item) => keyOf(item)));
  const pending = jobs.filter((job) => !existingKeys.has(keyOf(job)));

  console.log(`Database: ${mongoose.connection.db!.databaseName}`);
  console.log(`Event: ${EVENT_SLUG}`);
  console.log(`Event memberships: ${memberships.length}; teams: ${teams.length}`);
  console.log(`Eligible profile/team texts: ${jobs.length}`);
  console.log(`Already embedded: ${jobs.length - pending.length}`);
  console.log(`Missing embeddings: ${pending.length}`);

  if (!apply) {
    for (const job of pending.slice(0, 3)) console.log(`  Preview ${job.ownerKind}: ${job.label} — ${job.text.slice(0, 100)}`);
    console.log("DRY RUN: no Gemini requests and no database changes.");
  } else {
    const batch = pending.slice(0, limit);
    console.log(`Generating up to ${batch.length} new embeddings; existing vectors will not be overwritten.`);
    let inserted = 0;
    for (const job of batch) {
      // One document per request, deliberately serialized to ease rate limits.
      const embedding = await embedDocument(job.text);
      const result = await EmbeddingModel.updateOne(
        { event: event._id, ownerKind: job.ownerKind, ownerId: job.ownerId },
        { $setOnInsert: { event: event._id, ownerKind: job.ownerKind, ownerId: job.ownerId, embedding } },
        { upsert: true, runValidators: true },
      );
      inserted += result.upsertedCount;
      console.log(`  ${inserted}/${batch.length} inserted: ${job.ownerKind} ${job.label}`);
      // Keep the request pace low. Retries in embedDocument are separate.
      await new Promise<void>((resolve) => setTimeout(resolve, 1100));
    }
    console.log(`Finished: ${inserted} new embedding document(s). Rerun to resume missing ones.`);
  }
} finally {
  await mongoose.disconnect();
}
