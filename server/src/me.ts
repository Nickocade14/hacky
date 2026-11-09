import { Router } from "express";
import { Types } from "mongoose";
import { z } from "zod";
import { HttpError } from "./errors.js";
import { EventModel } from "./models/Event.js";
import { MembershipModel } from "./models/Membership.js";
import { ProfileModel } from "./models/Profile.js";

type ProfileDoc = {
  _id: Types.ObjectId;
  handle: string;
  name: string;
  hackyStyle?: unknown;
  photoUrl?: string | null;
  bio?: string | null;
  links?: Map<string, string> | Record<string, string> | null;
  isDemo?: boolean;
};

// PublicProfile in docs/openapi.yaml. Never includes email.
export function toPublicProfile(profile: ProfileDoc) {
  const links = profile.links instanceof Map ? Object.fromEntries(profile.links) : { ...(profile.links ?? {}) };
  return {
    userId: profile._id.toString(),
    handle: profile.handle,
    name: profile.name,
    hackyStyle: (profile.hackyStyle ?? {}) as Record<string, unknown>,
    photoUrl: profile.photoUrl ?? null,
    bio: profile.bio ?? null,
    links,
    isDemo: profile.isDemo ?? false,
  };
}

// Me in docs/openapi.yaml: my profile plus the events I belong to.
export async function buildMe(userId: Types.ObjectId) {
  const profile = await ProfileModel.findById(userId).lean();
  if (!profile) throw new HttpError(401, "unauthorized", "Please log in again.");
  const memberships = await MembershipModel.find({ user: userId }).select("event role verified").lean();
  const events = await EventModel.find({ _id: { $in: memberships.map((m) => m.event) } })
    .select("slug name").lean();
  const byId = new Map(events.map((event) => [event._id.toString(), event]));
  return {
    profile: toPublicProfile(profile),
    events: memberships.flatMap((m) => {
      const event = byId.get(m.event.toString());
      return event ? [{ slug: event.slug, name: event.name, role: m.role, verified: m.verified }] : [];
    }),
  };
}

// Reads the id requireAuth put in res.locals.
export function viewerId(locals: Record<string, unknown>): Types.ObjectId {
  const raw = locals.profileId;
  if (typeof raw !== "string" || !/^[a-f\d]{24}$/i.test(raw)) {
    throw new HttpError(401, "unauthorized", "Please log in again.");
  }
  return new Types.ObjectId(raw);
}

const httpsUrl = z.string().max(300).regex(/^https:\/\//, "Links must start with https://").pipe(z.url());

export const hackyStyleSchema = z.looseObject({
  look: z.string().max(40).optional(),
  color: z.string().max(40).optional(),
  flair: z.string().max(40).optional(),
  move: z.string().max(40).optional(),
  avatar: z.enum(["photo", "hacky"]).optional(),
}).refine((style) => JSON.stringify(style).length <= 2000, "Hacky style is too large");

// UpdateProfileBody: only the fields to change. links replaces the whole set.
export const updateProfileBodySchema = z.object({
  name: z.string().trim().min(1).max(80).optional(),
  bio: z.string().trim().max(500).nullable().optional(),
  hackyStyle: hackyStyleSchema.optional(),
  links: z.object({ github: httpsUrl, linkedin: httpsUrl, website: httpsUrl }).partial().optional(),
}).refine((body) => Object.keys(body).length > 0, "Send at least one field to change");

// Mounted at /api/me after requireAuth.
export function createMeRouter(): Router {
  const router = Router();
  router.get("/", async (_req, res) => {
    res.json(await buildMe(viewerId(res.locals)));
  });

  router.patch("/profile", async (req, res) => {
    const body = updateProfileBodySchema.parse(req.body);
    const set: Record<string, unknown> = {};
    const unset: Record<string, ""> = {};
    if (body.name !== undefined) set.name = body.name;
    if (body.hackyStyle !== undefined) set.hackyStyle = body.hackyStyle;
    if (body.links !== undefined) set.links = body.links;
    if (body.bio === null || body.bio === "") unset.bio = "";
    else if (body.bio !== undefined) set.bio = body.bio;
    const profile = await ProfileModel.findByIdAndUpdate(
      viewerId(res.locals),
      { ...(Object.keys(set).length ? { $set: set } : {}), ...(Object.keys(unset).length ? { $unset: unset } : {}) },
      { new: true },
    ).lean();
    if (!profile) throw new HttpError(401, "unauthorized", "Please log in again.");
    res.json(toPublicProfile(profile));
  });
  return router;
}
