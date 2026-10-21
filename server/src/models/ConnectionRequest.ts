import { Schema, model, type InferSchemaType } from "mongoose";
import { REQUEST_SOURCE, REQUEST_STATUS } from "./enums.js";

// A request to connect (collection "requests"). One per direction/event/purpose.
// hiddenAt: the recipient tapped "Not now" (the sender still sees "pending").
// team: request to join; `to` is the owner, who must accept before adding `from`.
//
// The unique index is per direction, so A->B and B->A can both exist. Rule
// (same as the old Hacky): when creating A->B, look for a pending B->A first;
// if it's there, accept it instead and open one DM. This only applies to personal
// requests (no team). Team membership always requires the owner's acceptance.
const requestSchema = new Schema(
  {
    event: { type: Schema.Types.ObjectId, ref: "Event", required: true },
    from: { type: Schema.Types.ObjectId, ref: "Profile", required: true },
    to: { type: Schema.Types.ObjectId, ref: "Profile", required: true },
    status: { type: String, enum: REQUEST_STATUS, required: true, default: "pending" },
    intro: { type: String, required: true, trim: true, minlength: 1, maxlength: 500 },
    source: { type: String, enum: REQUEST_SOURCE, required: true, default: "agent" },
    team: { type: Schema.Types.ObjectId, ref: "Team" },
    respondedAt: Date,
    hiddenAt: Date,
  },
  { timestamps: { createdAt: true, updatedAt: false }, collection: "requests" },
);

// Only runs on save()/create(). If a route uses upsert, check from !== to with Zod.
requestSchema.pre("validate", function () {
  if (this.from && this.to && this.from.equals(this.to)) {
    this.invalidate("to", "You can't send a request to yourself");
  }
});

// A prior personal connection must not prevent a separate request to join a team.
// Missing team is indexed as null, so personal requests remain unique too.
requestSchema.index({ event: 1, from: 1, to: 1, team: 1 }, { unique: true });
requestSchema.index({ to: 1, status: 1 });
requestSchema.index({ from: 1 });

export type ConnectionRequest = InferSchemaType<typeof requestSchema>;
export const ConnectionRequestModel = model("ConnectionRequest", requestSchema);
