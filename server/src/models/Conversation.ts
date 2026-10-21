import { Schema, Types, model, type InferSchemaType } from "mongoose";
import { CONVERSATION_KINDS } from "./enums.js";

// kind "dm":     dmUserLow + dmUserHigh (sorted ids), one per pair per event.
// kind "mentor": helpRequest, one per help request.
// kind "team":   team, one per team.
// members replaces the old conversation_members table; lastReadAt drives unread badges.
// Create DMs only with openDm() below. pre("validate") only runs on save()/create(),
// so openDm builds the fields itself.
const memberSchema = new Schema(
  {
    user: { type: Schema.Types.ObjectId, ref: "Profile", required: true },
    lastReadAt: Date,
    joinedAt: { type: Date, required: true, default: Date.now },
  },
  { _id: false },
);

const conversationSchema = new Schema(
  {
    event: { type: Schema.Types.ObjectId, ref: "Event", required: true },
    kind: { type: String, enum: CONVERSATION_KINDS, required: true },
    members: { type: [memberSchema], default: [] },
    dmUserLow: { type: Schema.Types.ObjectId, ref: "Profile" },
    dmUserHigh: { type: Schema.Types.ObjectId, ref: "Profile" },
    helpRequest: { type: Schema.Types.ObjectId, ref: "HelpRequest" },
    team: { type: Schema.Types.ObjectId, ref: "Team" },
    // Empty conversations start here; message writes advance it atomically.
    lastMessageAt: { type: Date, required: true, default: Date.now },
  },
  { timestamps: { createdAt: true, updatedAt: false } },
);

// Same shape rules as the old Postgres CHECK constraint.
conversationSchema.pre("validate", function () {
  const { kind, dmUserLow, dmUserHigh, helpRequest, team } = this;
  const ok =
    (kind === "dm" && dmUserLow && dmUserHigh && dmUserLow.toString() < dmUserHigh.toString() && !helpRequest && !team) ||
    (kind === "mentor" && helpRequest && !dmUserLow && !dmUserHigh && !team) ||
    (kind === "team" && team && !dmUserLow && !dmUserHigh && !helpRequest);
  if (!ok) this.invalidate("kind", `Invalid fields for a "${kind}" conversation`);

  if (!Array.isArray(this.members) || this.members.some((member) => !member?.user)) {
    this.invalidate("members", "Every conversation member must have a user");
    return;
  }

  // A DM's members are exactly its two people.
  if (kind === "dm" && dmUserLow && dmUserHigh) {
    const ids = this.members.map((m) => m.user.toString()).sort();
    const pair = [dmUserLow.toString(), dmUserHigh.toString()].sort();
    if (ids.length !== 2 || ids[0] !== pair[0] || ids[1] !== pair[1]) {
      this.invalidate("members", "A DM's members must be dmUserLow and dmUserHigh");
    }
  }
});

conversationSchema.index(
  { event: 1, dmUserLow: 1, dmUserHigh: 1 },
  { unique: true, partialFilterExpression: { kind: "dm" } },
);
conversationSchema.index(
  { helpRequest: 1 },
  { unique: true, partialFilterExpression: { helpRequest: { $type: "objectId" } } },
);
conversationSchema.index(
  { team: 1 },
  { unique: true, partialFilterExpression: { team: { $type: "objectId" } } },
);
conversationSchema.index({ "members.user": 1, lastMessageAt: -1, _id: -1 });

export type Conversation = InferSchemaType<typeof conversationSchema>;
export const ConversationModel = model("Conversation", conversationSchema);

export function listConversations(event: Types.ObjectId, user: Types.ObjectId) {
  return ConversationModel.find({ event, "members.user": user }).sort({ lastMessageAt: -1, _id: -1 });
}

// Returns the DM between a and b at this event, creating it if needed.
// Accepting twice, or two people accepting at the same time, returns the same
// conversation: the unique index stops a second DM.
export async function openDm(event: Types.ObjectId, a: Types.ObjectId, b: Types.ObjectId) {
  if (a.equals(b)) throw new Error("A DM needs two different people");
  const [low, high] = a.toString() < b.toString() ? [a, b] : [b, a];
  const filter = { event, kind: "dm" as const, dmUserLow: low, dmUserHigh: high };
  const now = new Date();
  try {
    return await ConversationModel.findOneAndUpdate(
      filter,
      { $setOnInsert: { members: [{ user: low, joinedAt: now }, { user: high, joinedAt: now }] } },
      { upsert: true, new: true },
    ).orFail();
  } catch (err) {
    // Lost the race to the other request: the DM exists now, return it.
    if ((err as { code?: number }).code === 11000) return ConversationModel.findOne(filter).orFail();
    throw err;
  }
}
