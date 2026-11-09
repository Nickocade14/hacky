import { Router } from "express";
import mongoose, { Types } from "mongoose";
import { z } from "zod";
import { HttpError } from "../errors.js";
import { blockedWith, requireMembership, toPersonSummary } from "../events/access.js";
import { viewerId } from "../me.js";
import { BlockModel } from "../models/Block.js";
import { ConnectionRequestModel } from "../models/ConnectionRequest.js";
import { ConversationModel, openDm } from "../models/Conversation.js";
import { MembershipModel } from "../models/Membership.js";
import { ProfileModel } from "../models/Profile.js";
import { TeamModel, addTeamMember } from "../models/Team.js";
import { REQUEST_SOURCE } from "../models/enums.js";

const objectId = z.string().regex(/^[a-f\d]{24}$/i, "Invalid id");
const LINK = /https?:\/\/|www\.|\b[a-z0-9-]+\.(com|net|org|io|dev|me|app|co|xyz)\b/i;

export const sendRequestBodySchema = z.object({
  toUserId: objectId,
  intro: z.string().trim().min(1).max(500).refine((text) => !LINK.test(text), "Intros can't include links"),
  source: z.enum(REQUEST_SOURCE).default("agent"),
  teamId: objectId.optional(),
}).strict();

export const blockBodySchema = z.object({ userId: objectId }).strict();

type RequestDoc = {
  _id: Types.ObjectId;
  event: Types.ObjectId;
  from: Types.ObjectId;
  to: Types.ObjectId;
  status: string;
  intro: string;
  source: string;
  team?: Types.ObjectId | null;
  createdAt: Date;
  respondedAt?: Date | null;
  hiddenAt?: Date | null;
};

// ConnectionRequest in docs/openapi.yaml, as the viewer sees it.
async function serializeRequests(requests: RequestDoc[], viewer: Types.ObjectId) {
  const others = requests.map((r) => (r.from.equals(viewer) ? r.to : r.from));
  const events = [...new Set(requests.map((r) => r.event.toString()))].map((id) => new Types.ObjectId(id));
  const [profiles, memberships, teams, dms] = await Promise.all([
    ProfileModel.find({ _id: { $in: others } }).select("handle name hackyStyle photoUrl").lean(),
    MembershipModel.find({ event: { $in: events }, user: { $in: others } }).select("event user role").lean(),
    TeamModel.find({ _id: { $in: requests.flatMap((r) => (r.team ? [r.team] : [])) } }).select("name").lean(),
    ConversationModel.find({
      event: { $in: events }, kind: "dm", "members.user": viewer,
      $or: [{ dmUserLow: { $in: others } }, { dmUserHigh: { $in: others } }],
    }).select("event dmUserLow dmUserHigh").lean(),
  ]);
  return requests.flatMap((r) => {
    const incoming = r.to.equals(viewer);
    const other = incoming ? r.from : r.to;
    const profile = profiles.find((p) => p._id.equals(other));
    if (!profile) return [];
    const role = memberships.find((m) => m.event.equals(r.event) && m.user.equals(other))?.role ?? "hacker";
    const team = r.team ? teams.find((t) => t._id.equals(r.team!)) : null;
    const dm = r.status === "accepted"
      ? dms.find((c) => c.event.equals(r.event) && (c.dmUserLow!.equals(other) || c.dmUserHigh!.equals(other)))
      : null;
    return [{
      id: r._id.toString(),
      direction: incoming ? "incoming" : "outgoing",
      status: r.status,
      intro: r.intro,
      source: r.source,
      person: toPersonSummary(profile, role),
      team: team ? { id: team._id.toString(), name: team.name } : null,
      conversationId: dm?._id.toString() ?? null,
      createdAt: r.createdAt.toISOString(),
      respondedAt: r.respondedAt ? r.respondedAt.toISOString() : null,
      ...(incoming ? { hiddenAt: r.hiddenAt ? r.hiddenAt.toISOString() : null } : {}),
    }];
  });
}

async function serializeOne(request: RequestDoc, viewer: Types.ObjectId) {
  const [result] = await serializeRequests([request], viewer);
  if (!result) throw new HttpError(404, "not_found", "Request not found.");
  return result;
}

// Accepts the request and opens the DM. For team requests, also adds the
// requester to the team, all in one transaction. Accepting twice is a no-op.
async function accept(request: RequestDoc) {
  await mongoose.connection.transaction(async (session) => {
    if (request.team) {
      const team = await TeamModel.findOne({ _id: request.team, event: request.event }).session(session).lean();
      if (!team || !team.owner.equals(request.to)) {
        throw new HttpError(409, "conflict", "You no longer own this team.");
      }
      const elsewhere = await TeamModel.exists({ event: request.event, members: request.from, _id: { $ne: team._id } })
        .session(session);
      if (elsewhere) throw new HttpError(409, "conflict", "They already joined another team.");
      if (!await addTeamMember(team._id, request.from, session)) {
        throw new HttpError(409, "conflict", "Your team is full.");
      }
    }
    await ConnectionRequestModel.updateOne(
      { _id: request._id, status: "pending" },
      { $set: { status: "accepted", respondedAt: new Date() }, $unset: { hiddenAt: "" } },
      { session },
    );
    await openDm(request.event, request.from, request.to, session);
  });
  return ConnectionRequestModel.findById(request._id).lean().orFail();
}

// Mounted at /api after requireAuth.
export function createRequestsRouter(): Router {
  const router = Router();

  router.get("/events/:slug/requests", async (req, res) => {
    const viewer = viewerId(res.locals);
    const { event } = await requireMembership(req.params.slug, viewer);
    const blocked = await blockedWith(viewer);
    const requests = await ConnectionRequestModel.find({
      event: event._id,
      $or: [{ from: viewer, to: { $nin: blocked } }, { to: viewer, from: { $nin: blocked } }],
    }).sort({ createdAt: -1, _id: -1 }).lean();
    res.json({ requests: await serializeRequests(requests, viewer) });
  });

  router.post("/events/:slug/requests", async (req, res) => {
    const viewer = viewerId(res.locals);
    const body = sendRequestBodySchema.parse(req.body);
    const { event } = await requireMembership(req.params.slug, viewer);
    const to = new Types.ObjectId(body.toUserId);
    if (to.equals(viewer)) throw new HttpError(400, "invalid_input", "You can't send a request to yourself.");
    const notFound = new HttpError(404, "not_found", "This person isn't at this event.");
    if ((await blockedWith(viewer)).some((id) => id.equals(to))) throw notFound;
    if (!await MembershipModel.exists({ event: event._id, user: to })) throw notFound;

    if (body.teamId) {
      const team = await TeamModel.findOne({ _id: body.teamId, event: event._id }).select("owner").lean();
      if (!team) throw new HttpError(404, "not_found", "Team not found.");
      if (!team.owner.equals(to)) throw new HttpError(400, "invalid_input", "Send team requests to the team's owner.");
      if (await TeamModel.exists({ event: event._id, members: viewer })) {
        throw new HttpError(409, "conflict", "You're already on a team at this event.");
      }
    } else {
      // They already asked me: accept theirs instead of creating a second request.
      const reverse = await ConnectionRequestModel.findOne({
        event: event._id, from: to, to: viewer, team: null, status: "pending",
      }).lean();
      if (reverse) {
        res.status(201).json({ request: await serializeOne(await accept(reverse), viewer) });
        return;
      }
    }
    // One per direction, event and purpose: a duplicate is 409 from the unique index.
    const created = await ConnectionRequestModel.create({
      event: event._id, from: viewer, to, intro: body.intro, source: body.source, team: body.teamId ?? null,
    });
    res.status(201).json({ request: await serializeOne(created.toObject(), viewer) });
  });

  // Recipient only. Must still belong to the request's event.
  async function incomingRequest(rawId: string, viewer: Types.ObjectId) {
    const id = objectId.parse(rawId);
    const request = await ConnectionRequestModel.findById(id).lean();
    if (!request || !request.to.equals(viewer)) {
      if (request?.from.equals(viewer)) throw new HttpError(403, "forbidden", "Only the person you asked can answer.");
      throw new HttpError(404, "not_found", "Request not found.");
    }
    if (!await MembershipModel.exists({ event: request.event, user: viewer })) {
      throw new HttpError(403, "forbidden", "You must join this event first.");
    }
    if ((await blockedWith(viewer)).some((b) => b.equals(request.from))) {
      throw new HttpError(404, "not_found", "Request not found.");
    }
    return request;
  }

  router.post("/requests/:id/accept", async (req, res) => {
    const viewer = viewerId(res.locals);
    const request = await incomingRequest(req.params.id, viewer);
    const accepted = request.status === "accepted" ? request : await accept(request);
    res.json({ request: await serializeOne(accepted, viewer) });
  });

  // "Not now": the sender still sees it as pending.
  router.post("/requests/:id/hide", async (req, res) => {
    const viewer = viewerId(res.locals);
    const request = await incomingRequest(req.params.id, viewer);
    if (request.status === "pending" && !request.hiddenAt) {
      await ConnectionRequestModel.updateOne({ _id: request._id }, { $set: { hiddenAt: new Date() } });
    }
    res.json({ ok: true });
  });

  // Applies in every event and both directions. Blocking twice is fine.
  router.post("/blocks", async (req, res) => {
    const viewer = viewerId(res.locals);
    const blocked = new Types.ObjectId(blockBodySchema.parse(req.body).userId);
    if (blocked.equals(viewer)) throw new HttpError(400, "invalid_input", "You can't block yourself.");
    await BlockModel.updateOne({ blocker: viewer, blocked }, { $setOnInsert: { blocker: viewer, blocked } }, { upsert: true })
      .catch((error) => { if ((error as { code?: number }).code !== 11000) throw error; });
    res.json({ ok: true });
  });

  return router;
}
