import { Schema, Types, model, type InferSchemaType } from "mongoose";
import { HELP_STATUS } from "./enums.js";

// Created only from the "Request help" button. A hacker can have at most 3
// open requests (checked in the route).
const helpRequestSchema = new Schema(
  {
    event: { type: Schema.Types.ObjectId, ref: "Event", required: true },
    hacker: { type: Schema.Types.ObjectId, ref: "Profile", required: true },
    title: { type: String, required: true, trim: true, minlength: 3, maxlength: 120 },
    details: { type: String, maxlength: 2000 },
    skillsNeeded: { type: [String], default: [] },
    status: { type: String, enum: HELP_STATUS, required: true, default: "open" },
    mentor: { type: Schema.Types.ObjectId, ref: "Profile" },
    claimedAt: Date,
    resolvedAt: Date,
  },
  { timestamps: { createdAt: true, updatedAt: false }, collection: "help" },
);

// open = no mentor; claimed/resolved = has a mentor. Only runs on save()/create().
helpRequestSchema.pre("validate", function () {
  if (this.status === "open" && this.mentor) this.invalidate("mentor", "An open request has no mentor");
  if (this.status !== "open" && !this.mentor) this.invalidate("mentor", "A claimed request needs a mentor");
});

helpRequestSchema.index({ event: 1, status: 1, createdAt: 1 });
helpRequestSchema.index({ hacker: 1 });
helpRequestSchema.index({ mentor: 1 });

export type HelpRequest = InferSchemaType<typeof helpRequestSchema>;
export const HelpRequestModel = model("HelpRequest", helpRequestSchema);

// Status changes go through these, never a bare update: the filter is what
// enforces the rule. Both return null when the change isn't allowed
// (already claimed, not your request, already resolved).
export function claimHelpRequest(id: Types.ObjectId, mentor: Types.ObjectId) {
  return HelpRequestModel.findOneAndUpdate(
    { _id: id, status: "open", hacker: { $ne: mentor } },
    { $set: { status: "claimed", mentor, claimedAt: new Date() } },
    { new: true },
  );
}

export function resolveHelpRequest(id: Types.ObjectId, mentor: Types.ObjectId) {
  return HelpRequestModel.findOneAndUpdate(
    { _id: id, status: "claimed", mentor },
    { $set: { status: "resolved", resolvedAt: new Date() } },
    { new: true },
  );
}
