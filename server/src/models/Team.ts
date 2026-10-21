import { Schema, Types, model, type InferSchemaType } from "mongoose";

// One team per person per event. The owner is always included in members and maxSize.
// Requesting to join sends a ConnectionRequest to the owner; acceptance adds the member.
const teamSchema = new Schema(
  {
    event: { type: Schema.Types.ObjectId, ref: "Event", required: true },
    owner: { type: Schema.Types.ObjectId, ref: "Profile", required: true },
    members: { type: [{ type: Schema.Types.ObjectId, ref: "Profile" }], default: [] },
    name: { type: String, required: true, trim: true, minlength: 1, maxlength: 80 },
    idea: { type: String, maxlength: 1000 },
    track: String,
    wantedSkills: { type: [String], default: [] },
    maxSize: {
      type: Number,
      required: true,
      default: 4,
      min: 1,
      max: 8,
      validate: { validator: Number.isInteger, message: "maxSize must be a whole number" },
    },
  },
  { timestamps: { createdAt: true, updatedAt: false } },
);

// Only runs on save()/create(). Adding members later goes through addTeamMember.
teamSchema.pre("validate", function () {
  if (!Array.isArray(this.members) || this.members.some((member) => !member)) {
    this.invalidate("members", "Every team member must be a user id");
    return;
  }
  const ids = this.members.map((m) => m.toString());
  if (new Set(ids).size !== ids.length) {
    this.invalidate("members", "A person can only be on the team once");
  }
  if (this.owner && !ids.includes(this.owner.toString())) {
    this.invalidate("members", "The team owner must be included in members");
  }
  if (this.members.length > this.maxSize) {
    this.invalidate("members", `A team can have at most ${this.maxSize} members`);
  }
});

teamSchema.index({ event: 1 });
teamSchema.index({ owner: 1 });
teamSchema.index({ members: 1 });
// A multikey unique index prevents membership in two teams, including concurrent joins.
teamSchema.index({ event: 1, members: 1 }, { unique: true });
teamSchema.index(
  { name: "text", idea: "text", track: "text", wantedSkills: "text" },
  { name: "team_text" },
);

export type Team = InferSchemaType<typeof teamSchema>;
export const TeamModel = model("Team", teamSchema);

type NewTeam = Pick<Team, "event" | "owner" | "name"> & Partial<Pick<Team, "idea" | "track" | "wantedSkills" | "maxSize">>;

// The route supplies owner from JWT and verifies event membership.
export function createTeam(input: NewTeam) {
  return TeamModel.create({ ...input, members: [input.owner] });
}

// The size check is in the filter, so two people joining at once can't
// overfill the team. Returns null when the team is full (or doesn't exist).
export function addTeamMember(teamId: Types.ObjectId, user: Types.ObjectId) {
  return TeamModel.findOneAndUpdate(
    { _id: teamId, $or: [{ members: user }, { $expr: { $lt: [{ $size: "$members" }, "$maxSize"] } }] },
    { $addToSet: { members: user } },
    { new: true },
  );
}
