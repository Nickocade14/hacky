import { Schema, Types, model, type InferSchemaType } from "mongoose";
import { MESSAGE_KINDS } from "./enums.js";
import { ConversationModel } from "./Conversation.js";
import { HttpError } from "../errors.js";

// sender is empty for system messages. clientId lets the app swap its instant
// copy of a sent message for the real one (and makes resends idempotent).
const messageSchema = new Schema(
  {
    conversation: { type: Schema.Types.ObjectId, ref: "Conversation", required: true },
    sender: { type: Schema.Types.ObjectId, ref: "Profile" },
    clientId: String,
    body: { type: String, required: true, minlength: 1, maxlength: 4000 },
    kind: { type: String, enum: MESSAGE_KINDS, required: true, default: "text" },
  },
  { timestamps: { createdAt: true, updatedAt: false } },
);

// text and card messages have a sender; system messages don't.
// Only runs on save()/create(), which is how messages are created.
messageSchema.pre("validate", function () {
  if (this.kind === "system" && this.sender) this.invalidate("sender", "System messages have no sender");
  if (this.kind !== "system" && !this.sender) this.invalidate("sender", "This message needs a sender");
});

// Exclusive ObjectId cursors; messages created in the same millisecond still have a stable order.
messageSchema.index({ conversation: 1, _id: -1 });
messageSchema.index(
  { sender: 1, clientId: 1 },
  { unique: true, partialFilterExpression: { clientId: { $type: "string" } } },
);

export type Message = InferSchemaType<typeof messageSchema>;
export const MessageModel = model("Message", messageSchema);

type NewMessage = Pick<Message, "conversation" | "body"> & Partial<Pick<Message, "sender" | "clientId" | "kind">>;

// All message sends (including server-generated system messages) use this helper.
// Routes still check JWT, event membership and blocks before calling it.
// Atlas or a local replica set is required for the transaction.
export async function createMessage(input: NewMessage) {
  try {
    return await MessageModel.db.transaction(async (session) => {
      const message = await new MessageModel(input).save({ session });
      const result = await ConversationModel.updateOne(
        { _id: message.conversation, ...(message.sender ? { "members.user": message.sender } : {}) },
        { $max: { lastMessageAt: message.createdAt } },
        { session },
      );
      if (!result.matchedCount) throw new HttpError(404, "not_found", "Conversation not found");
      return message;
    });
  } catch (error) {
    const duplicate = error as { code?: number; keyPattern?: Record<string, number> };
    if (duplicate.code !== 11000 || !duplicate.keyPattern?.sender || !duplicate.keyPattern?.clientId || !input.clientId) {
      throw error;
    }
    const existing = await MessageModel.findOne({ sender: input.sender ?? null, clientId: input.clientId });
    if (!existing) throw error;
    if (!existing.conversation.equals(input.conversation) || existing.body !== input.body || existing.kind !== (input.kind ?? "text")) {
      throw new HttpError(409, "conflict", "clientId was already used for a different message");
    }
    // A retry does not advance lastMessageAt: no new message was sent.
    return existing;
  }
}

export async function listMessages(conversation: Types.ObjectId, options: { before?: Types.ObjectId; after?: Types.ObjectId; limit?: number } = {}) {
  const { before, after, limit = 30 } = options;
  if ((before && after) || !Number.isInteger(limit) || limit < 1 || limit > 100) {
    throw new HttpError(400, "invalid_input", "Use one cursor and a limit between 1 and 100");
  }
  const messages = await MessageModel.find({
    conversation,
    ...(before ? { _id: { $lt: before } } : after ? { _id: { $gt: after } } : {}),
  }).sort({ _id: after ? 1 : -1 }).limit(limit + 1).lean();
  const hasMore = messages.length > limit;
  messages.splice(limit);
  if (!after) messages.reverse();
  return { messages, hasMore };
}
