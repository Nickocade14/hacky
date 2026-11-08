import { Types } from "mongoose";
import { HttpError } from "../errors.js";
import { BlockModel } from "../models/Block.js";
import { EventModel } from "../models/Event.js";
import { MembershipModel } from "../models/Membership.js";

export const SLUG = /^[a-z0-9-]{2,40}$/;

type EventDoc = {
  _id: Types.ObjectId;
  slug: string;
  name: string;
  theme?: unknown;
  tracks?: string[] | null;
  startsAt?: Date | null;
  endsAt?: Date | null;
};

// EventInfo in docs/openapi.yaml.
export function toEventInfo(event: EventDoc) {
  return {
    slug: event.slug,
    name: event.name,
    theme: (event.theme ?? {}) as Record<string, unknown>,
    tracks: event.tracks ?? [],
    startsAt: event.startsAt ? event.startsAt.toISOString() : null,
    endsAt: event.endsAt ? event.endsAt.toISOString() : null,
  };
}

type MembershipDoc = {
  role: string;
  verified: boolean;
  availability: string;
  looking: boolean;
  skills?: string[] | null;
  skillsWanted?: string[] | null;
  experience?: string | null;
  wantsExperienced?: boolean | null;
  goal?: string | null;
  track?: string | null;
  interests?: string[] | null;
  idea?: string | null;
  summary?: string | null;
  motivations?: string[] | null;
  complete?: boolean | null;
};

// Membership in docs/openapi.yaml.
export function toMembership(m: MembershipDoc) {
  return { role: m.role, verified: m.verified, availability: m.availability, looking: m.looking };
}

// Intake in docs/openapi.yaml.
export function toIntake(m: MembershipDoc) {
  return {
    skills: m.skills ?? [],
    skillsWanted: m.skillsWanted ?? [],
    experience: m.experience ?? null,
    wantsExperienced: m.wantsExperienced ?? false,
    goal: m.goal ?? null,
    track: m.track ?? null,
    interests: m.interests ?? [],
    idea: m.idea ?? null,
    motivations: m.motivations ?? [],
    summary: m.summary ?? null,
    complete: m.complete ?? false,
  };
}

// EventMe in docs/openapi.yaml.
export const toEventMe = (m: MembershipDoc) => ({ ...toMembership(m), intake: toIntake(m) });

type ProfileLite = { _id: Types.ObjectId; handle: string; name: string; hackyStyle?: unknown; photoUrl?: string | null };

// PersonSummary in docs/openapi.yaml.
export function toPersonSummary(profile: ProfileLite, role: string) {
  return {
    userId: profile._id.toString(),
    handle: profile.handle,
    name: profile.name,
    hackyStyle: (profile.hackyStyle ?? {}) as Record<string, unknown>,
    photoUrl: profile.photoUrl ?? null,
    role,
  };
}

export async function findEventOr404(slug: string) {
  const event = SLUG.test(slug) ? await EventModel.findOne({ slug }).lean() : null;
  if (!event) throw new HttpError(404, "not_found", "Event not found.");
  return event;
}

// 403 whether the event is missing or the viewer isn't in it, so the answer
// doesn't reveal which events exist (same as search).
export async function requireMembership(slug: string, viewer: Types.ObjectId) {
  const event = SLUG.test(slug) ? await EventModel.findOne({ slug }).lean() : null;
  const membership = event ? await MembershipModel.findOne({ event: event._id, user: viewer }).lean() : null;
  if (!event || !membership) throw new HttpError(403, "forbidden", "You must join this event first.");
  return { event, membership };
}

// Everyone the viewer blocked or who blocked the viewer. Blocks apply in every event.
export async function blockedWith(viewer: Types.ObjectId): Promise<Types.ObjectId[]> {
  const blocks = await BlockModel.find({ $or: [{ blocker: viewer }, { blocked: viewer }] })
    .select("blocker blocked").lean();
  return blocks.map((b) => (b.blocker.equals(viewer) ? b.blocked : b.blocker));
}
