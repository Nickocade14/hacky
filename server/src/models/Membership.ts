import { Schema, model, type InferSchemaType } from "mongoose";
import { AVAILABILITY, EXPERIENCE, HACK_GOALS, MEMBER_ROLES, MOTIVATIONS } from "./enums.js";

// One person at one event: their role there plus what the agent learned about
// them for matching. (Old Postgres: event_members + member_profiles.)
const membershipSchema = new Schema(
  {
    event: { type: Schema.Types.ObjectId, ref: "Event", required: true },
    user: { type: Schema.Types.ObjectId, ref: "Profile", required: true },
    role: { type: String, enum: MEMBER_ROLES, required: true, default: "hacker" },
    verified: { type: Boolean, required: true, default: false },
    availability: { type: String, enum: AVAILABILITY, required: true, default: "available" },
    looking: { type: Boolean, required: true, default: true },

    // Matching data (filled by onboarding + the agent)
    skills: { type: [String], default: [] },
    skillsWanted: { type: [String], default: [] },
    experience: { type: String, enum: EXPERIENCE },
    wantsExperienced: { type: Boolean, required: true, default: false },
    goal: { type: String, enum: HACK_GOALS },
    track: String,
    interests: { type: [String], default: [] },
    idea: { type: String, maxlength: 2000 },
    summary: { type: String, maxlength: 1000 },
    motivations: { type: [{ type: String, enum: MOTIVATIONS }], default: [] },
    complete: { type: Boolean, required: true, default: false },
  },
  { timestamps: true },
);

membershipSchema.index({ event: 1, user: 1 }, { unique: true });
membershipSchema.index({ user: 1 });
membershipSchema.index({ event: 1, role: 1, looking: 1 });
// Keyword search for matching (replaces the Postgres tsvector).
membershipSchema.index(
  { skills: "text", skillsWanted: "text", interests: "text", track: "text", idea: "text", summary: "text" },
  { name: "membership_text", weights: { skills: 5, interests: 3, track: 3, skillsWanted: 2, idea: 1, summary: 1 } },
);

export type Membership = InferSchemaType<typeof membershipSchema>;
export const MembershipModel = model("Membership", membershipSchema);
