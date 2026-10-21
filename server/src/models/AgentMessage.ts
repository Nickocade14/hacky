import { Schema, model, type InferSchemaType } from "mongoose";
import { AGENT_ROLES } from "./enums.js";

// Hacky chat history, one thread per user per event.
// messageId is the AI SDK message id; parts is the AI SDK message parts array.
const agentMessageSchema = new Schema(
  {
    user: { type: Schema.Types.ObjectId, ref: "Profile", required: true },
    event: { type: Schema.Types.ObjectId, ref: "Event", required: true },
    messageId: { type: String, required: true },
    role: { type: String, enum: AGENT_ROLES, required: true },
    parts: { type: Schema.Types.Mixed, required: true },
  },
  { timestamps: { createdAt: true, updatedAt: false } },
);

agentMessageSchema.index({ user: 1, messageId: 1 }, { unique: true });
agentMessageSchema.index({ user: 1, event: 1, createdAt: 1 });
agentMessageSchema.index({ event: 1 });

export type AgentMessage = InferSchemaType<typeof agentMessageSchema>;
export const AgentMessageModel = model("AgentMessage", agentMessageSchema);
