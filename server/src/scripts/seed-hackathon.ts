/**
 * Import Knight Hacks IX demo people into the new MongoDB data model.
 *
 * Default: read-only preview + Mongoose validation (no DB connection).
 * To write: node --env-file=.env --import tsx src/scripts/seed-hackathon.ts --apply --confirm=hacky
 *
 * No User documents are created: demo profiles have no login credentials.
 * The current Profile schema identifies a profile by _id; it has no userId.
 * Import only the knighthacks-ix event, its attendees, and its teams.
 * IMPORTANT: Submit a PR and obtain teammate review before running --apply.
 */
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { Types, type ClientSession } from "mongoose";
import { connectDb, disconnectDb } from "../db.js";
import { EventModel } from "../models/Event.js";
import { ProfileModel } from "../models/Profile.js";
import { MembershipModel } from "../models/Membership.js";
import { TeamModel } from "../models/Team.js";

type Intake = {
  skills: string[];
  skillsWanted: string[];
  experience: string | null;
  wantsExperienced: boolean;
  goal: string | null;
  track: string | null;
  interests: string[];
  idea: string | null;
  summary: string | null;
  motivations: string[];
  complete: boolean;
};
type SeedData = {
  version: number;
  events: Array<{
    slug: string;
    name: string;
    tracks: string[];
    theme: Record<string, unknown>;
    startsAt: string | null;
    endsAt: string | null;
  }>;
  people: Array<{
    handle: string;
    name: string;
    bio: string | null;
    links: Record<string, string>;
    hackyStyle: Record<string, unknown>;
    photoUrl?: string;
    memberships: Array<{
      event: string;
      role: string;
      verified: boolean;
      availability: string;
      looking: boolean;
      intake: Intake;
    }>;
  }>;
  teams: Array<{
    id: string;
    event: string;
    name: string;
    owner: string;
    members: string[]; // Owner is excluded in the old data.
    idea: string | null;
    track: string | null;
    wantedSkills: string[];
    maxSize: number;
  }>;
};

// Deterministic ObjectIds make reruns of this importer idempotent.
function seedId(kind: string, key: string): Types.ObjectId {
  const hex = createHash("sha256").update(`hacky-seed-v1:${kind}:${key}`).digest("hex").slice(0, 24);
  return new Types.ObjectId(hex);
}

const raw = readFileSync(new URL("../../seed/people.json", import.meta.url), "utf8");
const data = JSON.parse(raw) as SeedData;
if (data.version !== 1 || !Array.isArray(data.events) || !Array.isArray(data.people) || !Array.isArray(data.teams)) {
  throw new Error("Unexpected seed format. Expected version 1 with events, people, and teams arrays.");
}

const EVENT_SLUG = "knighthacks-ix";
const selectedEvents = data.events.filter((event) => event.slug === EVENT_SLUG);
if (selectedEvents.length !== 1) {
  throw new Error(`Expected exactly one event with slug ${EVENT_SLUG}`);
}
// Only include people who belong to Knight Hacks IX. In particular, demo_you
// keeps this membership but not its separate Demo Hacks membership.
const people = data.people.filter((person) =>
  person.memberships.some((membership) => membership.event === EVENT_SLUG),
);
const teams = data.teams.filter((team) => team.event === EVENT_SLUG);
const eventIds = new Map(selectedEvents.map((event) => [event.slug, seedId("event", event.slug)]));
const personIds = new Map(people.map((person) => [person.handle, seedId("profile", person.handle)]));
if (personIds.size !== people.length) {
  throw new Error("Duplicate profile handles in Knight Hacks IX seed data.");
}
if (!personIds.has("demo_you")) {
  throw new Error("Required demo profile demo_you is missing from Knight Hacks IX.");
}

const eventDocs = selectedEvents.map((event) => ({
  _id: eventIds.get(event.slug)!,
  slug: event.slug,
  name: event.name,
  tracks: event.tracks,
  theme: event.theme,
  startsAt: event.startsAt ? new Date(event.startsAt) : undefined,
  endsAt: event.endsAt ? new Date(event.endsAt) : undefined,
}));

const profileDocs = people.map((person) => ({
  _id: personIds.get(person.handle)!,
  handle: person.handle,
  name: person.name,
  bio: person.bio ?? undefined,
  links: person.links,
  hackyStyle: person.hackyStyle,
  photoUrl: person.photoUrl ?? undefined,
  isDemo: true,
}));

const membershipDocs = people.flatMap((person) =>
  person.memberships.filter((membership) => membership.event === EVENT_SLUG).map((membership) => {
    const event = eventIds.get(membership.event);
    if (!event) throw new Error(`Unknown event ${membership.event} for ${person.handle}`);
    const intake = membership.intake;
    return {
      event,
      user: personIds.get(person.handle)!,
      role: membership.role,
      verified: membership.verified,
      availability: membership.availability,
      looking: membership.looking,
      skills: intake.skills,
      skillsWanted: intake.skillsWanted,
      experience: intake.experience ?? undefined,
      wantsExperienced: intake.wantsExperienced,
      goal: intake.goal ?? undefined,
      track: intake.track ?? undefined,
      interests: intake.interests,
      idea: intake.idea ?? undefined,
      summary: intake.summary ?? undefined,
      motivations: intake.motivations,
      complete: intake.complete,
    };
  }),
);

const teamDocs = teams.map((team) => {
  const event = eventIds.get(team.event);
  const owner = personIds.get(team.owner);
  if (!event || !owner) throw new Error(`Unknown event or owner for team ${team.name}`);
  const memberHandles = [team.owner, ...team.members];
  const members = memberHandles.map((handle) => {
    const id = personIds.get(handle);
    if (!id) throw new Error(`Unknown team member ${handle} on ${team.name}`);
    const belongsToEvent = people.find((p) => p.handle === handle)?.memberships.some((m) => m.event === team.event);
    if (!belongsToEvent) throw new Error(`Team member ${handle} does not belong to ${team.event}`);
    return id;
  });
  return {
    _id: seedId("team", team.id),
    event,
    owner,
    members, // Includes the owner, as required by the new Team schema.
    name: team.name,
    idea: team.idea ?? undefined,
    track: team.track ?? undefined,
    wantedSkills: team.wantedSkills,
    maxSize: team.maxSize,
  };
});

// Check the model schema and Team validation hooks even during a dry run.
await Promise.all([
  ...eventDocs.map((doc) => new EventModel(doc).validate()),
  ...profileDocs.map((doc) => new ProfileModel(doc).validate()),
  ...membershipDocs.map((doc) => new MembershipModel(doc).validate()),
  ...teamDocs.map((doc) => new TeamModel(doc).validate()),
]);

console.log(`Seed file validated for ${EVENT_SLUG} against the current Mongoose models:`);
console.log(`  Events: ${eventDocs.length}`);
console.log(`  Demo profiles (no login accounts): ${profileDocs.length}`);
console.log(`  Memberships: ${membershipDocs.length}`);
console.log(`  Teams: ${teamDocs.length}`);

const apply = process.argv.includes("--apply");
if (!apply) {
  console.log("DRY RUN: no connection to MongoDB and no database changes.");
  console.log("Submit and obtain review of the seed script PR before using --apply.");
} else {
  if (!process.argv.includes("--confirm=hacky")) {
    throw new Error("To import into MongoDB, pass both --apply and --confirm=hacky.");
  }
  const uri = process.env.MONGODB_URI;
  if (!uri || new URL(uri).pathname !== "/hacky") {
    throw new Error("Refusing to write: MONGODB_URI must explicitly select the /hacky database.");
  }

  await connectDb();
  try {
    // Catch conflicts before making any writes; never overwrite live profiles.
    const [existingEvents, existingProfiles] = await Promise.all([
      EventModel.find({ slug: { $in: selectedEvents.map((e) => e.slug) } }).select("_id slug").lean(),
      ProfileModel.find({ handle: { $in: people.map((p) => p.handle) } })
        .select("_id handle isDemo")
        .lean(),
    ]);
    for (const event of existingEvents) {
      if (!event._id.equals(eventIds.get(event.slug)!)) {
        throw new Error(`Event ${event.slug} already exists with a different id. No changes made.`);
      }
    }
    for (const profile of existingProfiles) {
      if (!profile.isDemo || !profile._id.equals(personIds.get(profile.handle)!)) {
        throw new Error(`Profile ${profile.handle} already exists and is not from this import. No changes made.`);
      }
    }

    const run = async (session: ClientSession) => {
      // Insert only if missing; never clobber later edits or user-created records.
      const insertNew = <T extends { _id: Types.ObjectId }>(docs: T[]) =>
        docs.map((doc) => ({
          updateOne: { filter: { _id: doc._id }, update: { $setOnInsert: doc }, upsert: true },
        }));
      const eventResult = await EventModel.bulkWrite(insertNew(eventDocs), { session });
      const profileResult = await ProfileModel.bulkWrite(insertNew(profileDocs), { session });
      const membershipResult = await MembershipModel.bulkWrite(
        membershipDocs.map((doc) => ({
          updateOne: {
            filter: { event: doc.event, user: doc.user },
            update: { $setOnInsert: doc },
            upsert: true,
          },
        })),
        { session },
      );
      const teamResult = await TeamModel.bulkWrite(insertNew(teamDocs), { session });
      return { eventResult, profileResult, membershipResult, teamResult };
    };

    // Transaction prevents partially populated seed data if a write fails.
    const { eventResult, profileResult, membershipResult, teamResult } =
      await EventModel.db.transaction(async (session) => run(session));
    console.log("Import finished. Newly inserted:");
    console.log(`  Events: ${eventResult.upsertedCount}`);
    console.log(`  Profiles: ${profileResult.upsertedCount}`);
    console.log(`  Memberships: ${membershipResult.upsertedCount}`);
    console.log(`  Teams: ${teamResult.upsertedCount}`);
  } finally {
    await disconnectDb();
  }
}
