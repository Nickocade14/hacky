/**
 * Read-only hybrid matching for Knight Hacks IX and other events.
 *
 * Keyword retrieval uses the existing MongoDB text indexes on memberships
 * and teams. Semantic retrieval uses the Atlas embedding_vector search index.
 * The two ranked lists are combined with Reciprocal Rank Fusion (RRF).
 *
 * This is a data-layer service, not a new HTTP endpoint. Before wiring it into
 * Hacky's chat route, coordinate with the auth/chat owner (see AGENTS.md).
 *
 * Never return raw embedding arrays or private User data to clients.
 */
import { Types } from "mongoose";
import { embedQuery, normalizeEmbedding } from "../embeddings.js";
import { HttpError } from "../errors.js";
import { BlockModel } from "../models/Block.js";
import { ConnectionRequestModel } from "../models/ConnectionRequest.js";
import { EmbeddingModel } from "../models/Embedding.js";
import { EventModel } from "../models/Event.js";
import { MembershipModel } from "../models/Membership.js";
import { ProfileModel } from "../models/Profile.js";
import { TeamModel } from "../models/Team.js";

export type MatchKind = "hacker" | "mentor" | "team";
type VectorOwner = "member" | "team";
const RRF_K = 60;
const SEARCH_POOL = 100;
const MAX_RESULTS = 10;

const asKey = (value: Types.ObjectId): string => value.toString();

/** MongoDB $text searches can contain punctuation and filler; trim that noise. */
const FILLER = new Set([
  "find", "need", "want", "looking", "someone", "somebody", "anyone", "people",
  "person", "teammate", "teammates", "team", "teams", "mentor", "mentors",
  "help", "who", "knows", "know", "good", "with", "for", "the", "and",
  "to", "in", "on", "of", "a", "an", "me", "my", "i", "can", "please",
]);

export function keywordTerms(query: string): string {
  return query.toLowerCase().replace(/["\-]/g, " ").split(/\s+/)
    .map((word) => word.replace(/^[^\p{L}\p{N}+#.]+|[^\p{L}\p{N}+#]+$/gu, ""))
    .filter((word) => word.length > 1 && !FILLER.has(word)).join(" ");
}

/** RRF, with deterministic tie-breaking; accepts ranked IDs (best first). */
export function fuseRanks(keywordIds: readonly string[], vectorIds: readonly string[]): Array<{ id: string; relevance: number }> {
  const scores = new Map<string, number>();
  for (const ids of [keywordIds, vectorIds]) {
    const seen = new Set<string>();
    ids.forEach((id, index) => {
      if (seen.has(id)) return;
      seen.add(id);
      scores.set(id, (scores.get(id) ?? 0) + 1 / (RRF_K + index + 1));
    });
  }
  // Scale 0..1: perfect first place in both lists is exactly 1.
  return [...scores].map(([id, raw]) => ({ id, relevance: raw * (RRF_K + 1) / 2 }))
    .sort((a, b) => b.relevance - a.relevance || a.id.localeCompare(b.id));
}

/** The first stage *must* be $vectorSearch; event/kind are indexed prefilters. */
export function vectorPipeline(
  event: Types.ObjectId, ownerKind: VectorOwner, queryVector: number[], limit = SEARCH_POOL,
): Record<string, unknown>[] {
  const count = Math.min(SEARCH_POOL, Math.max(1, limit));
  return [
    {
      $vectorSearch: {
        index: "embedding_vector", path: "embedding", queryVector,
        numCandidates: count * 10, limit: count,
        filter: { event, ownerKind },
      },
    },
    { $project: { _id: 0, ownerId: 1, similarity: { $meta: "vectorSearchScore" } } },
  ];
}

async function vectorIds(event: Types.ObjectId, ownerKind: VectorOwner, queryVector: number[]): Promise<string[]> {
  const docs = await EmbeddingModel.collection.aggregate<{ ownerId: Types.ObjectId }>(
    vectorPipeline(event, ownerKind, queryVector), { maxTimeMS: 15_000 },
  ).toArray();
  return docs.map((doc) => asKey(doc.ownerId));
}

async function keywordIds(event: Types.ObjectId, kind: MatchKind, query: string): Promise<string[]> {
  const terms = keywordTerms(query);
  if (!terms) return [];
  if (kind === "team") {
    const rows = await TeamModel.aggregate<{ _id: Types.ObjectId }>([
      { $match: { $text: { $search: terms }, event } },
      { $project: { _id: 1, rankScore: { $meta: "textScore" } } },
      { $sort: { rankScore: -1, _id: 1 } },
      { $limit: SEARCH_POOL },
    ]);
    return rows.map((doc) => asKey(doc._id));
  }
  const rows = await MembershipModel.aggregate<{ user: Types.ObjectId }>([
    { $match: { $text: { $search: terms }, event, role: kind } },
    { $project: { _id: 0, user: 1, rankScore: { $meta: "textScore" } } },
    { $sort: { rankScore: -1, user: 1 } },
    { $limit: SEARCH_POOL },
  ]);
  return rows.map((doc) => asKey(doc.user));
}

export interface MatchInput {
  viewerProfileId: Types.ObjectId;
  eventSlug: string;
  kind: MatchKind;
  query: string;
  limit?: number;
  /** For tests or batch evaluation: avoid making a paid Gemini request. */
  queryVector?: number[] | null;
  /** Optional explicit skills, e.g. ["Go", "Postgres"]. */
  neededSkills?: readonly string[];
}

/** Allows unit/integration tests to inject Atlas results without needing Atlas. */
export interface MatchDeps {
  embed?: (text: string) => Promise<number[]>;
  searchVectors?: (event: Types.ObjectId, ownerKind: VectorOwner, queryVector: number[]) => Promise<string[]>;
}

interface BaseResult {
  score: number; // 0..100, comparable within one search, not a probability
  matchedSkills: string[];
  evidence: { keywordRank: number | null; vectorRank: number | null };
}

export interface MemberMatch extends BaseResult {
  kind: "hacker" | "mentor";
  person: { userId: string; handle: string; name: string; hackyStyle: unknown; photoUrl: string | null };
  skills: string[];
  interests: string[];
  role: "hacker" | "mentor";
  verified: boolean;
  availability: string;
}

export interface TeamMatch extends BaseResult {
  kind: "team";
  team: {
    id: string; name: string; idea: string | null; track: string | null;
    wantedSkills: string[]; size: number; maxSize: number; ownerId: string;
  };
}
export type HybridMatch = MemberMatch | TeamMatch;

function exactMatches(skills: string[], query: string, neededSkills: readonly string[]): string[] {
  const words = query.toLowerCase();
  return skills.filter((skill) => {
    const value = skill.toLowerCase();
    if (neededSkills.some((wanted) => wanted.toLowerCase() === value)) return true;
    const pattern = value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    return new RegExp(`(^|[^\\p{L}\\p{N}+#])${pattern}(?![\\p{L}\\p{N}+#])`, "u").test(words);
  });
}

/** Return results from unprivileged profile data only (not private Users or vectors). */
export async function hybridMatch(input: MatchInput, deps: MatchDeps = {}): Promise<HybridMatch[]> {
  const { viewerProfileId, eventSlug, kind } = input;
  const query = input.query.trim();
  const limit = input.limit ?? 5;
  if (!/^[a-z0-9-]{2,40}$/.test(eventSlug) || !["hacker", "mentor", "team"].includes(kind) ||
      !query || query.length > 300 || !Number.isInteger(limit) || limit < 1 || limit > MAX_RESULTS) {
    throw new HttpError(400, "invalid_input", "Invalid matching query.");
  }
  const event = await EventModel.findOne({ slug: eventSlug }).select("_id").lean();
  if (!event || !await MembershipModel.exists({ event: event._id, user: viewerProfileId })) {
    throw new HttpError(403, "forbidden", "Join this event before finding matches.");
  }

  // Blocks apply both directions, across every event. Requests exclude already-contacted people.
  const [blocks, requests] = await Promise.all([
    BlockModel.find({ $or: [{ blocker: viewerProfileId }, { blocked: viewerProfileId }] })
      .select("blocker blocked").lean(),
    ConnectionRequestModel.find({ event: event._id, $or: [{ from: viewerProfileId }, { to: viewerProfileId }] })
      .select("from to").lean(),
  ]);
  const excluded = new Set<string>([asKey(viewerProfileId)]);
  for (const block of blocks) {
    excluded.add(asKey(block.blocker.equals(viewerProfileId) ? block.blocked : block.blocker));
  }
  for (const request of requests) {
    excluded.add(asKey(request.from.equals(viewerProfileId) ? request.to : request.from));
  }

  // Query embeddings use RETRIEVAL_QUERY with the same model/dimension as the documents.
  // With no key, matching still works using the keyword branch alone.
  const qVector = input.queryVector !== undefined ? input.queryVector
    : (deps.embed ? await deps.embed(query)
      : process.env.GOOGLE_GENERATIVE_AI_API_KEY ? await embedQuery(query) : null);
  const checkedVector = qVector === null ? null : normalizeEmbedding(qVector);
  const [kwIds, vecIds] = await Promise.all([
    keywordIds(event._id, kind, query),
    checkedVector ? (deps.searchVectors ?? vectorIds)(event._id, kind === "team" ? "team" : "member", checkedVector) : [],
  ]);
  const fused = fuseRanks(kwIds, vecIds);
  if (fused.length === 0) return [];
  const wanted = input.neededSkills ?? [];
  const ids = fused.map((row) => new Types.ObjectId(row.id));
  const textRank = new Map(kwIds.map((id, i) => [id, i + 1]));
  const vecRank = new Map(vecIds.map((id, i) => [id, i + 1]));

  if (kind === "team") {
    const teams = await TeamModel.find({ _id: { $in: ids }, event: event._id }).lean();
    const byId = new Map(teams.map((team) => [asKey(team._id), team]));
    const results = fused.flatMap((row): TeamMatch[] => {
      const team = byId.get(row.id);
      if (!team || excluded.has(asKey(team.owner)) || team.members.some((id) => id.equals(viewerProfileId)) ||
          team.members.length >= team.maxSize) return [];
      const matchedSkills = exactMatches(team.wantedSkills ?? [], query, wanted);
      const bonus = matchedSkills.length ? 0.1 : 0;
      return [{
        kind: "team", score: Math.round(100 * Math.min(1, 0.9 * row.relevance + bonus)),
        matchedSkills, evidence: { keywordRank: textRank.get(row.id) ?? null, vectorRank: vecRank.get(row.id) ?? null },
        team: {
          id: row.id, name: team.name, idea: team.idea ?? null, track: team.track ?? null,
          wantedSkills: team.wantedSkills ?? [], size: team.members.length,
          maxSize: team.maxSize, ownerId: asKey(team.owner),
        },
      }];
    });
    return results.sort((a, b) => b.score - a.score || a.team.id.localeCompare(b.team.id)).slice(0, limit);
  }

  // Use one concrete filter shape. Spreading a union of member-role filters
  // confuses Mongoose's TypeScript overload inference for Model.find().
  const memberships = await MembershipModel.find({
    event: event._id,
    user: { $in: ids },
    role: kind,
    availability: { $ne: "offline" },
    ...(kind === "hacker" ? { looking: true } : {}),
  }).lean();
  const profiles = await ProfileModel.find({ _id: { $in: memberships.map((m) => m.user) } })
    .select("handle name hackyStyle photoUrl").lean();
  const memberById = new Map(memberships.map((m) => [asKey(m.user), m]));
  const profileById = new Map(profiles.map((p) => [asKey(p._id), p]));
  const results = fused.flatMap((row): MemberMatch[] => {
    if (excluded.has(row.id)) return [];
    const member = memberById.get(row.id);
    const profile = profileById.get(row.id);
    if (!member || !profile) return [];
    const matchedSkills = exactMatches(member.skills ?? [], query, wanted);
    const bonus = matchedSkills.length ? 0.1 : 0;
    const mentorBonus = kind === "mentor" && member.verified ? 0.05 : 0;
    return [{
      kind, score: Math.round(100 * Math.min(1, 0.85 * row.relevance + bonus + mentorBonus)),
      matchedSkills, evidence: { keywordRank: textRank.get(row.id) ?? null, vectorRank: vecRank.get(row.id) ?? null },
      person: { userId: row.id, handle: profile.handle, name: profile.name,
        hackyStyle: profile.hackyStyle ?? {}, photoUrl: profile.photoUrl ?? null },
      skills: member.skills ?? [], interests: member.interests ?? [], role: kind,
      verified: member.verified, availability: member.availability,
    }];
  });
  return results.sort((a, b) => b.score - a.score || a.person.userId.localeCompare(b.person.userId)).slice(0, limit);
}
