import type { PipelineStage, Types } from "mongoose";
import { ConnectionRequestModel } from "../models/ConnectionRequest.js";
import { ConversationModel } from "../models/Conversation.js";
import { MembershipModel } from "../models/Membership.js";
import { ProfileModel } from "../models/Profile.js";
import { TeamModel } from "../models/Team.js";

export type Intent = "mentor" | "teammate";

export const wantsMentor = (text: string) => /\bmentor(s|ship)?\b/i.test(text);
export const intentOf = (text: string): Intent => (wantsMentor(text) ? "mentor" : "teammate");

// Mentors aren't filtered on `looking` (every seeded mentor has looking: false).
// Sponsors and organizers are never suggested.
const intentFilter = (intent: Intent) => intent === "mentor"
  ? { role: "mentor", availability: { $ne: "offline" } }
  : { role: "hacker", looking: true };

const FILLER = new Set([
  "find", "need", "want", "looking", "someone", "somebody", "people", "person", "teammate", "teammates",
  "team", "mentor", "mentors", "help", "who", "knows", "know", "good", "with", "for",
  // Small words that would only add noise ("Who's looking for a team?" leaves nothing).
  "who's", "whos", "anyone", "anybody", "a", "an", "the", "at", "or", "and", "to", "in", "on", "of", "me",
  "my", "i", "is", "are", "can", "could", "please", "pick", "track", "what", "how", "some", "any",
]);

// The words worth a $text search, or "" when only filler is left ("Find a mentor").
export function searchTerms(text: string): string {
  return text.toLowerCase().replace(/["-]/g, " ").split(/\s+/)
    .map((word) => word.replace(/^[^\p{L}\p{N}+#.]+|[^\p{L}\p{N}+#]+$/gu, ""))
    .filter((word) => word.length > 1 && !FILLER.has(word))
    .join(" ");
}

// People the viewer is already in touch with at this event, so Hacky doesn't
// suggest them again: a request either way (pending, accepted or set aside
// with "Not now", personal or to join a team), any chat they share (DM,
// mentor or team) and their teammates.
export async function alreadyInTouch(event: Types.ObjectId, viewer: Types.ObjectId): Promise<Types.ObjectId[]> {
  const [requests, conversations, teams] = await Promise.all([
    ConnectionRequestModel.find({ event, $or: [{ from: viewer }, { to: viewer }] }).select("from to").lean(),
    ConversationModel.find({ event, "members.user": viewer }).select("members.user").lean(),
    TeamModel.find({ event, members: viewer }).select("members").lean(),
  ]);
  return [
    ...requests.flatMap((request) => [request.from, request.to]),
    ...conversations.flatMap((conversation) => conversation.members.map((member) => member.user)),
    ...teams.flatMap((team) => team.members),
  ].filter((id) => !id.equals(viewer));
}

export type CandidateRow = {
  role: string;
  verified?: boolean;
  availability?: string;
  skills?: string[];
  skillsWanted?: string[];
  experience?: string | null;
  goal?: string | null;
  track?: string | null;
  interests?: string[];
  idea?: string | null;
  summary?: string | null;
  profile: { _id: Types.ObjectId; handle: string; name: string; hackyStyle?: unknown; photoUrl?: string | null };
};

function pipeline(match: Record<string, unknown>, sort: Record<string, 1 | -1>, limit: number): PipelineStage[] {
  return [
    { $match: match }, // $text must be in the first $match stage
    ...(match.$text ? [{ $addFields: { score: { $meta: "textScore" } } }] : []),
    { $sort: sort },
    { $limit: limit },
    { $lookup: { from: ProfileModel.collection.name, localField: "user", foreignField: "_id", as: "profile" } },
    { $unwind: "$profile" },
    { $project: {
      _id: 0, role: 1, verified: 1, availability: 1, skills: 1, skillsWanted: 1, experience: 1,
      goal: 1, track: 1, interests: 1, idea: 1, summary: 1,
      profile: { _id: 1, handle: 1, name: 1, hackyStyle: 1, photoUrl: 1 },
    } },
  ];
}

// Best text matches first; everyone who fits the intent when the text matches nobody.
export async function loadCandidates(
  event: Types.ObjectId, excluded: Types.ObjectId[], intent: Intent, text: string,
): Promise<CandidateRow[]> {
  const base = { event, user: { $nin: excluded }, ...intentFilter(intent) };
  const terms = searchTerms(text);
  let rows: CandidateRow[] = [];
  if (terms) {
    try {
      rows = await MembershipModel.aggregate<CandidateRow>(
        pipeline({ ...base, $text: { $search: terms } }, { score: -1, _id: 1 }, 40),
      );
    } catch (error) {
      // 27: the text index doesn't exist yet (run `npm run db:indexes`).
      if ((error as { code?: number }).code !== 27) throw error;
      console.warn("[chat] membership_text index missing; using the fallback candidate query");
    }
  }
  if (rows.length === 0) {
    rows = await MembershipModel.aggregate<CandidateRow>(pipeline(base, { complete: -1, _id: 1 }, 200));
  }
  return rows;
}

// User-written values can't break the one-line format.
const clean = (value: string) => value.replace(/\s+/g, " ").replace(/\|/g, "/").trim();
const list = (values: string[] | undefined, max: number) =>
  (values ?? []).slice(0, max).map(clean).filter(Boolean).join(", ");

// One line (about 50 words) per person for the prompt. ref is "p7" for candidates, absent for the viewer.
export function summaryLine(row: CandidateRow, ref?: string): string {
  const about = clean(row.summary ?? row.idea ?? "").slice(0, 160);
  const fields = [
    ref,
    `${clean(row.profile.name)} (@${row.profile.handle})`,
    row.role,
    row.experience ? clean(row.experience) : "",
    list(row.skills, 8) && `skills: ${list(row.skills, 8)}`,
    list(row.skillsWanted, 5) && `wants: ${list(row.skillsWanted, 5)}`,
    row.track ? `track: ${clean(row.track)}` : "",
    row.goal ? `goal: ${row.goal}` : "",
    list(row.interests, 4) && `interests: ${list(row.interests, 4)}`,
    about && `about: ${about}`,
    row.role === "mentor" && row.verified ? "verified" : "",
    row.role === "mentor" && row.availability === "available" ? "available" : "",
  ];
  return fields.filter(Boolean).join(" | ");
}

const escapeRegex = (text: string) => text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

// Skills named in the message as whole words (works for C++ and C#; "go" doesn't match "Django").
export function matchedSkills(skills: string[] | undefined, text: string): string[] {
  const lower = text.toLowerCase();
  return (skills ?? []).filter((skill) =>
    new RegExp(`(^|[^\\p{L}\\p{N}+#])${escapeRegex(skill.toLowerCase())}(?![\\p{L}\\p{N}+#])`, "u").test(lower));
}
