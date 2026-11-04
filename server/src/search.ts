/**
 * GET /api/search?event=knighthacks-ix&q=rea[&role=hacker][&limit=20]
 *
 * Auth integration: mount this handler AFTER the project's verified JWT
 * middleware, which must set res.locals.profileId to the authenticated
 * Profile._id. Do not read a viewer id from query parameters or headers.
 *
 * API contract currently names Profile._id "userId" in PersonSummary; this
 * serializes that legacy field without creating a User document for demos.
 * Coordinate a contract-first switch to "profileId" before changing it here.
 */
import type { RequestHandler } from "express";
import { Types, type PipelineStage } from "mongoose";
import { z } from "zod";
import { HttpError } from "./errors.js";
import { BlockModel } from "./models/Block.js";
import { EventModel } from "./models/Event.js";
import { MembershipModel } from "./models/Membership.js";
import { ProfileModel } from "./models/Profile.js";
import { MEMBER_ROLES } from "./models/enums.js";

// Express query parameters may also be arrays/objects; Zod rejects them.
export const searchQuerySchema = z.object({
  event: z.string().regex(/^[a-z0-9-]{2,40}$/),
  q: z.string().trim().min(1).max(100),
  role: z.enum(MEMBER_ROLES).optional(),
  limit: z.preprocess(
    (value) => value === undefined ? "20" : value,
    z.string().regex(/^(?:[1-9]|[1-4]\d|50)$/).transform(Number),
  ),
});

export type SearchQuery = z.infer<typeof searchQuerySchema>;

export interface SearchHit {
  // Legacy API field: this is a Profile._id even for demo-only profiles.
  userId: string;
  handle: string;
  name: string;
  hackyStyle: Record<string, unknown>;
  photoUrl: string | null;
  role: (typeof MEMBER_ROLES)[number];
  skills: string[];
  matchedSkills: string[];
}

const escapeRegex = (text: string): string => text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

export async function searchPeople(
  viewerProfileId: Types.ObjectId,
  { event: eventSlug, q, role, limit }: SearchQuery,
): Promise<SearchHit[]> {
  const event = await EventModel.findOne({ slug: eventSlug }).select("_id").lean();
  // Avoid exposing whether an event exists to non-members.
  if (!event || !await MembershipModel.exists({ event: event._id, user: viewerProfileId })) {
    throw new HttpError(403, "forbidden", "You must belong to this event to search it");
  }

  // Blocks are global and bidirectional, including across events.
  const blocks = await BlockModel.find({
    $or: [{ blocker: viewerProfileId }, { blocked: viewerProfileId }],
  }).select("blocker blocked").lean();
  const excluded = [viewerProfileId, ...blocks.map((block) =>
    block.blocker.toString() === viewerProfileId.toString() ? block.blocked : block.blocker,
  )];

  const pattern = escapeRegex(q);
  const prefix = `^${pattern}`;
  const regex = (text: string) => ({ $regex: text, $options: "i" });
  const starts = (field: string) => ({ $regexMatch: { input: field, regex: prefix, options: "i" } });
  const contains = (field: string) => ({ $regexMatch: { input: field, regex: pattern, options: "i" } });

  // Match event and blocks BEFORE the lookup. Use the DB for ranking and
  // limiting; don't fetch every member into Node on each keystroke.
  const pipeline: PipelineStage[] = [
    { $match: { event: event._id, user: { $nin: excluded }, ...(role ? { role } : {}) } },
    { $lookup: {
      from: ProfileModel.collection.name,
      localField: "user",
      foreignField: "_id",
      as: "profile",
    } },
    { $unwind: "$profile" },
    { $match: { $or: [
      { "profile.handle": regex(pattern) },
      { "profile.name": regex(pattern) },
      { skills: regex(pattern) },
    ] } },
    { $addFields: { matchRank: { $switch: {
      branches: [
        { case: starts("$profile.handle"), then: 0 },
        { case: starts("$profile.name"), then: 1 },
        { case: { $or: [contains("$profile.handle"), contains("$profile.name")] }, then: 2 },
      ],
      default: 3,
    } } } },
    { $sort: { matchRank: 1, "profile.handle": 1, _id: 1 } },
    { $limit: limit },
    { $project: {
      _id: 0,
      userId: { $toString: "$profile._id" },
      handle: "$profile.handle",
      name: "$profile.name",
      hackyStyle: { $ifNull: ["$profile.hackyStyle", {}] },
      photoUrl: { $ifNull: ["$profile.photoUrl", null] },
      role: "$role",
      skills: { $ifNull: ["$skills", []] },
      // The contract says matchedSkills is empty for name/handle matches.
      matchedSkills: { $cond: [
        { $lt: ["$matchRank", 3] },
        [],
        { $filter: {
          input: { $ifNull: ["$skills", []] },
          as: "skill",
          cond: { $regexMatch: { input: "$$skill", regex: pattern, options: "i" } },
        } },
      ] },
    } },
  ];

  return MembershipModel.aggregate<SearchHit>(pipeline).exec();
}

/**
 * This handler is safe to mount even before auth middleware exists: it
 * returns 401 until verified middleware supplies res.locals.profileId.
 * Coordinate mounting with the Backend · Auth owner (app.ts).
 */
export const searchHandler: RequestHandler = async (req, res) => {
  const rawId: unknown = res.locals.profileId;
  if (typeof rawId !== "string" || !/^[a-f\d]{24}$/i.test(rawId)) {
    throw new HttpError(401, "unauthorized", "Authentication required");
  }
  const query = searchQuerySchema.parse(req.query);
  const results = await searchPeople(new Types.ObjectId(rawId), query);
  res.json({ results });
};
