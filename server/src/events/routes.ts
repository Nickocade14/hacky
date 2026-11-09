import { Router } from "express";
import { Types } from "mongoose";
import { z } from "zod";
import { HttpError } from "../errors.js";
import { ConnectionRequestModel } from "../models/ConnectionRequest.js";
import { ConversationModel } from "../models/Conversation.js";
import { ProfileModel } from "../models/Profile.js";
import { EventModel } from "../models/Event.js";
import { MembershipModel } from "../models/Membership.js";
import { AVAILABILITY, EXPERIENCE, HACK_GOALS, MOTIVATIONS } from "../models/enums.js";
import { toPublicProfile, viewerId } from "../me.js";
import {
  blockedWith, findEventOr404, requireMembership, toEventInfo, toEventMe, toIntake, toMembership,
} from "./access.js";

const tag = z.string().trim().min(1).max(40);
const tags = z.array(tag).max(30).transform((list) => [...new Set(list)]);

export const joinBodySchema = z.object({ role: z.enum(["hacker", "mentor"]).default("hacker") });

// UpdateEventMeBody: intake fields plus availability and looking. role and verified can't change here.
export const updateEventMeSchema = z.object({
  skills: tags,
  skillsWanted: tags,
  experience: z.enum(EXPERIENCE).nullable(),
  wantsExperienced: z.boolean(),
  goal: z.enum(HACK_GOALS).nullable(),
  track: z.string().trim().max(80).nullable(),
  interests: tags,
  idea: z.string().trim().max(2000).nullable(),
  motivations: z.array(z.enum(MOTIVATIONS)).max(6).transform((list) => [...new Set(list)]),
  availability: z.enum(AVAILABILITY),
  looking: z.boolean(),
}).partial().strict();

// Enough for Hacky to match someone: what they know, how much, and why they're here.
const isComplete = (m: { skills?: string[] | null; experience?: string | null; goal?: string | null }) =>
  (m.skills?.length ?? 0) > 0 && Boolean(m.experience) && Boolean(m.goal);

// Relation in docs/openapi.yaml: where the viewer stands with this person
// (personal requests only; team requests don't change it).
export async function relationWith(event: Types.ObjectId, viewer: Types.ObjectId, other: Types.ObjectId) {
  const [low, high] = viewer.toString() < other.toString() ? [viewer, other] : [other, viewer];
  const [requests, dm] = await Promise.all([
    ConnectionRequestModel.find({
      event,
      team: null,
      $or: [{ from: viewer, to: other }, { from: other, to: viewer }],
    }).select("_id from status").lean(),
    ConversationModel.findOne({ event, kind: "dm", dmUserLow: low, dmUserHigh: high }).select("_id").lean(),
  ]);
  const conversationId = dm?._id.toString() ?? null;
  const accepted = requests.find((r) => r.status === "accepted");
  if (accepted) return { state: "accepted", requestId: accepted._id.toString(), conversationId };
  const outgoing = requests.find((r) => r.status === "pending" && r.from.equals(viewer));
  if (outgoing) return { state: "outgoing", requestId: outgoing._id.toString(), conversationId };
  const incoming = requests.find((r) => r.status === "pending" && r.from.equals(other));
  if (incoming) return { state: "incoming", requestId: incoming._id.toString(), conversationId };
  return { state: "none", requestId: null, conversationId };
}

// Mounted at /api/events after requireAuth.
export function createEventsRouter(): Router {
  const router = Router();

  router.get("/", async (_req, res) => {
    const events = await EventModel.find().sort({ startsAt: -1, _id: 1 }).lean();
    res.json({ events: events.map(toEventInfo) });
  });

  router.get("/:slug", async (req, res) => {
    res.json(toEventInfo(await findEventOr404(req.params.slug)));
  });

  // Joining again returns the same membership; the role picked first stays.
  router.post("/:slug/join", async (req, res) => {
    const viewer = viewerId(res.locals);
    const { role } = joinBodySchema.parse(req.body ?? {});
    const event = await findEventOr404(req.params.slug);
    const filter = { event: event._id, user: viewer };
    let membership;
    try {
      membership = await MembershipModel.findOneAndUpdate(
        filter,
        { $setOnInsert: { role, verified: false } },
        { upsert: true, new: true },
      ).lean();
    } catch (error) {
      // Two joins at once: the other one created it.
      if ((error as { code?: number }).code !== 11000) throw error;
      membership = await MembershipModel.findOne(filter).lean();
    }
    res.json(toEventMe(membership!));
  });

  router.get("/:slug/me", async (req, res) => {
    const { membership } = await requireMembership(req.params.slug, viewerId(res.locals));
    res.json(toEventMe(membership));
  });

  router.patch("/:slug/me", async (req, res) => {
    const viewer = viewerId(res.locals);
    const body = updateEventMeSchema.parse(req.body);
    const { event, membership } = await requireMembership(req.params.slug, viewer);
    const set: Record<string, unknown> = {};
    const unset: Record<string, ""> = {};
    for (const [key, value] of Object.entries(body)) {
      if (value === null || value === "") unset[key] = "";
      else set[key] = value;
    }
    set.complete = isComplete({ ...membership, ...body });
    const updated = await MembershipModel.findOneAndUpdate(
      { event: event._id, user: viewer },
      { $set: set, ...(Object.keys(unset).length ? { $unset: unset } : {}) },
      { new: true },
    ).lean();
    res.json(toEventMe(updated!));
  });

  // PersonDetail. 404 if they aren't in the event or either one blocked the other.
  router.get("/:slug/people/:handle", async (req, res) => {
    const viewer = viewerId(res.locals);
    const handle = z.string().toLowerCase().regex(/^[a-z0-9_]{3,30}$/).parse(req.params.handle);
    const { event } = await requireMembership(req.params.slug, viewer);
    const notFound = new HttpError(404, "not_found", "This person isn't at this event.");
    const profile = await ProfileModel.findOne({ handle }).lean();
    if (!profile) throw notFound;
    const blocked = await blockedWith(viewer);
    if (blocked.some((id) => id.equals(profile._id))) throw notFound;
    const membership = await MembershipModel.findOne({ event: event._id, user: profile._id }).lean();
    if (!membership) throw notFound;
    const { complete: _complete, wantsExperienced: _wants, ...intake } = toIntake(membership);
    res.json({
      ...toPublicProfile(profile),
      ...toMembership(membership),
      ...intake,
      relation: await relationWith(event._id, viewer, profile._id),
    });
  });

  return router;
}
