/**
 * Adapter from hybridMatch's public member results to the CandidateRow shape
 * already consumed by Hacky's chat prompt and card builder.
 *
 * This does not change the HTTP API or the chat routes. The chat owner can
 * opt into the adapter once the contract-preserving integration is reviewed.
 */
import { Types } from "mongoose";
import type { CandidateRow, Intent } from "../chat/candidates.js";
import { MembershipModel } from "../models/Membership.js";
import { hybridMatch, type MatchDeps, type MemberMatch } from "./hybrid.js";

export interface ChatCandidateQuery {
  eventId: Types.ObjectId;
  eventSlug: string;
  viewerProfileId: Types.ObjectId;
  /** Includes the viewer, blocks, conversations, requests and teammates. */
  excludedProfileIds: readonly Types.ObjectId[];
  intent: Intent;
  text: string;
  /** Tests may pass null or a fixed 768-d vector to avoid Gemini requests. */
  queryVector?: number[] | null;
}

/**
 * Keep the hybrid ranking, but fetch full public matching-intake data so
 * summaryLine() continues to include skills wanted, goals, ideas, etc.
 *
 * hybridMatch itself validates event membership, blocks and requests. We also
 * exclude the chat route's already-in-touch IDs because that route covers
 * existing conversations and teammates that hybridMatch does not yet cover.
 */
export async function hybridChatCandidates(
  input: ChatCandidateQuery,
  deps: MatchDeps = {},
): Promise<CandidateRow[]> {
  const kind = input.intent === "mentor" ? "mentor" : "hacker";
  // Chat accepts up to 1000 characters, but hybridMatch currently accepts 300.
  // Truncate only the retrieval query, never the message the assistant sees.
  const query = input.text.trim().slice(0, 300).trim();
  const matches = await hybridMatch({
    viewerProfileId: input.viewerProfileId,
    eventSlug: input.eventSlug,
    kind,
    query,
    limit: 10,
    queryVector: input.queryVector,
  }, deps);

  const excluded = new Set<string>([input.viewerProfileId.toString(),
    ...input.excludedProfileIds.map((id) => id.toString())]);
  const eligible = matches.filter((match): match is MemberMatch =>
    match.kind !== "team" && !excluded.has(match.person.userId));
  if (eligible.length === 0) return [];
  const ids = eligible.map((match) => new Types.ObjectId(match.person.userId));

  // Scope the join by event and role again, so candidates who changed their
  // role/availability while retrieval ran never enter a chat prompt.
  const memberships = await MembershipModel.find({
    event: input.eventId,
    user: { $in: ids },
    role: kind,
    availability: { $ne: "offline" },
    ...(kind === "hacker" ? { looking: true } : {}),
  }).select("user role verified availability skills skillsWanted experience goal track interests idea summary")
    .lean();
  const byUser = new Map(memberships.map((m) => [m.user.toString(), m]));

  // No raw vectors or private User fields; preserve fusion order exactly.
  return eligible.flatMap((match): CandidateRow[] => {
    const member = byUser.get(match.person.userId);
    if (!member) return [];
    return [{
      role: member.role,
      verified: member.verified,
      availability: member.availability,
      skills: member.skills ?? [],
      skillsWanted: member.skillsWanted ?? [],
      experience: member.experience ?? null,
      goal: member.goal ?? null,
      track: member.track ?? null,
      interests: member.interests ?? [],
      idea: member.idea ?? null,
      summary: member.summary ?? null,
      profile: {
        _id: new Types.ObjectId(match.person.userId),
        handle: match.person.handle,
        name: match.person.name,
        hackyStyle: match.person.hackyStyle,
        photoUrl: match.person.photoUrl,
      },
    }];
  });
}
