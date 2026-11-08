import { Router } from "express";
import { Types } from "mongoose";
import { z } from "zod";
import { HttpError } from "../errors.js";
import { MembershipModel } from "../models/Membership.js";
import { ProfileModel } from "../models/Profile.js";
import { TeamModel, createTeam } from "../models/Team.js";
import { viewerId } from "../me.js";
import { blockedWith, requireMembership, toPersonSummary } from "./access.js";

const tags = z.array(z.string().trim().min(1).max(40)).max(30).transform((list) => [...new Set(list)]);

export const createTeamBodySchema = z.object({
  name: z.string().trim().min(1).max(80),
  idea: z.string().trim().max(1000).optional(),
  track: z.string().trim().max(80).optional(),
  wantedSkills: tags.optional(),
  maxSize: z.number().int().min(1).max(8).default(4),
}).strict();

type TeamDoc = {
  _id: Types.ObjectId;
  event: Types.ObjectId;
  owner: Types.ObjectId;
  members: Types.ObjectId[];
  name: string;
  idea?: string | null;
  track?: string | null;
  wantedSkills?: string[] | null;
  maxSize: number;
};

// TeamDetail in docs/openapi.yaml: owner first, blocked people left out.
export async function toTeamDetail(team: TeamDoc, viewer: Types.ObjectId) {
  const blocked = await blockedWith(viewer);
  const visible = team.members.filter((id) => !blocked.some((b) => b.equals(id)));
  const [profiles, memberships] = await Promise.all([
    ProfileModel.find({ _id: { $in: team.members } }).select("handle name hackyStyle photoUrl").lean(),
    MembershipModel.find({ event: team.event, user: { $in: team.members } }).select("user role").lean(),
  ]);
  const roleOf = new Map(memberships.map((m) => [m.user.toString(), m.role]));
  const summary = (id: Types.ObjectId) => {
    const profile = profiles.find((p) => p._id.equals(id));
    return profile ? toPersonSummary(profile, roleOf.get(id.toString()) ?? "hacker") : null;
  };
  const ordered = [team.owner, ...visible.filter((id) => !id.equals(team.owner))];
  const owner = summary(team.owner);
  if (!owner) throw new Error(`Team ${team._id} has no owner profile`);
  return {
    id: team._id.toString(),
    name: team.name,
    idea: team.idea ?? null,
    track: team.track ?? null,
    wantedSkills: team.wantedSkills ?? [],
    size: team.members.length,
    maxSize: team.maxSize,
    owner,
    members: ordered.map(summary).filter((p) => p !== null),
  };
}

// Mounted at /api/events after requireAuth, next to the events router.
export function createTeamsRouter(): Router {
  const router = Router();

  // MyTeam, or null when I'm on no team.
  router.get("/:slug/me/team", async (req, res) => {
    const viewer = viewerId(res.locals);
    const { event } = await requireMembership(req.params.slug, viewer);
    const team = await TeamModel.findOne({ event: event._id, members: viewer }).lean();
    res.json({
      team: team && {
        id: team._id.toString(),
        name: team.name,
        isOwner: team.owner.equals(viewer),
        size: team.members.length,
        maxSize: team.maxSize,
      },
    });
  });

  router.post("/:slug/teams", async (req, res) => {
    const viewer = viewerId(res.locals);
    const body = createTeamBodySchema.parse(req.body);
    const { event } = await requireMembership(req.params.slug, viewer);
    if (await TeamModel.exists({ event: event._id, members: viewer })) {
      throw new HttpError(409, "conflict", "You're already on a team at this event.");
    }
    // The unique event/members index still stops a second team if two requests race.
    const team = await createTeam({ event: event._id, owner: viewer, ...body });
    res.status(201).json(await toTeamDetail(team.toObject(), viewer));
  });

  router.get("/:slug/teams/:id", async (req, res) => {
    const viewer = viewerId(res.locals);
    const id = z.string().regex(/^[a-f\d]{24}$/i).parse(req.params.id);
    const { event } = await requireMembership(req.params.slug, viewer);
    const team = await TeamModel.findOne({ _id: id, event: event._id }).lean();
    if (!team) throw new HttpError(404, "not_found", "Team not found.");
    res.json(await toTeamDetail(team, viewer));
  });

  return router;
}
