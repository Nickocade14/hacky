import { Router } from "express";
import { Types } from "mongoose";
import { z } from "zod";
import { HttpError } from "../errors.js";
import { blockedWith, requireMembership, toPersonSummary } from "../events/access.js";
import { viewerId } from "../me.js";
import { ConversationModel, listConversations } from "../models/Conversation.js";
import { HelpRequestModel } from "../models/HelpRequest.js";
import { MembershipModel } from "../models/Membership.js";
import { MessageModel, createMessage, listMessages } from "../models/Message.js";
import { ProfileModel } from "../models/Profile.js";
import { TeamModel } from "../models/Team.js";

const objectId = z.string().regex(/^[a-f\d]{24}$/i, "Invalid id");

export const listMessagesQuerySchema = z.object({
  before: objectId.optional(),
  after: objectId.optional(),
  limit: z.coerce.number().int().min(1).max(100).default(30),
}).refine((q) => !(q.before && q.after), "Use one cursor, not both");

export const sendMessageBodySchema = z.object({
  clientId: z.uuid(),
  body: z.string().trim().min(1).max(4000),
}).strict();

type MessageDoc = {
  _id: Types.ObjectId;
  conversation: Types.ObjectId;
  sender?: Types.ObjectId | null;
  clientId?: string | null;
  body: string;
  kind: string;
  createdAt: Date;
};

// Message in docs/openapi.yaml.
export const toMessage = (m: MessageDoc) => ({
  id: m._id.toString(),
  conversationId: m.conversation.toString(),
  senderId: m.sender ? m.sender.toString() : null,
  clientId: m.clientId ?? null,
  body: m.body,
  kind: m.kind,
  createdAt: m.createdAt.toISOString(),
});

type ConversationDoc = {
  _id: Types.ObjectId;
  event: Types.ObjectId;
  kind: string;
  members: { user: Types.ObjectId; lastReadAt?: Date | null }[];
  team?: Types.ObjectId | null;
  helpRequest?: Types.ObjectId | null;
  lastMessageAt: Date;
  createdAt: Date;
};

// The other person in a DM or mentor chat; null in team chats.
const peerOf = (c: ConversationDoc, viewer: Types.ObjectId) =>
  c.kind === "team" ? null : c.members.find((m) => !m.user.equals(viewer)) ?? null;

// The conversation, if the viewer is in it and still belongs to its event.
async function myConversation(rawId: string, viewer: Types.ObjectId) {
  const id = objectId.parse(rawId);
  const conversation = await ConversationModel.findOne({ _id: id, "members.user": viewer }).lean();
  if (!conversation) throw new HttpError(404, "not_found", "Conversation not found.");
  if (!await MembershipModel.exists({ event: conversation.event, user: viewer })) {
    throw new HttpError(403, "forbidden", "You must join this event first.");
  }
  return conversation as ConversationDoc;
}

// Mounted at /api after requireAuth.
export function createConversationsRouter(): Router {
  const router = Router();

  // ConversationSummary list, newest activity first. Chats with blocked people are left out.
  router.get("/events/:slug/conversations", async (req, res) => {
    const viewer = viewerId(res.locals);
    const { event } = await requireMembership(req.params.slug, viewer);
    const blocked = await blockedWith(viewer);
    const conversations = (await listConversations(event._id, viewer).lean() as ConversationDoc[])
      .filter((c) => { const peer = peerOf(c, viewer); return !peer || !blocked.some((b) => b.equals(peer.user)); });

    const peers = conversations.flatMap((c) => { const p = peerOf(c, viewer); return p ? [p.user] : []; });
    const [profiles, memberships, teams, helps] = await Promise.all([
      ProfileModel.find({ _id: { $in: peers } }).select("handle name hackyStyle photoUrl").lean(),
      MembershipModel.find({ event: event._id, user: { $in: peers } }).select("user role").lean(),
      TeamModel.find({ _id: { $in: conversations.flatMap((c) => (c.team ? [c.team] : [])) } }).select("name").lean(),
      HelpRequestModel.find({ _id: { $in: conversations.flatMap((c) => (c.helpRequest ? [c.helpRequest] : [])) } })
        .select("title status").lean(),
    ]);

    const summaries = await Promise.all(conversations.map(async (c) => {
      const me = c.members.find((m) => m.user.equals(viewer));
      const peer = peerOf(c, viewer);
      const profile = peer ? profiles.find((p) => p._id.equals(peer.user)) : null;
      const team = c.team ? teams.find((t) => t._id.equals(c.team!)) : null;
      const help = c.helpRequest ? helps.find((h) => h._id.equals(c.helpRequest!)) : null;
      const [last, unreadCount] = await Promise.all([
        MessageModel.findOne({ conversation: c._id }).sort({ _id: -1 }).lean(),
        MessageModel.countDocuments({
          conversation: c._id,
          sender: { $ne: viewer },
          ...(me?.lastReadAt ? { createdAt: { $gt: me.lastReadAt } } : {}),
        }),
      ]);
      return {
        id: c._id.toString(),
        kind: c.kind,
        peer: profile
          ? toPersonSummary(profile, memberships.find((m) => m.user.equals(profile._id))?.role ?? "hacker")
          : null,
        team: team ? { id: team._id.toString(), name: team.name } : null,
        helpRequest: help ? { id: help._id.toString(), title: help.title, status: help.status } : null,
        lastMessage: last ? toMessage(last) : null,
        lastMessageAt: c.lastMessageAt.toISOString(),
        unreadCount,
        peerLastReadAt: peer?.lastReadAt ? peer.lastReadAt.toISOString() : null,
        createdAt: c.createdAt.toISOString(),
      };
    }));
    res.json({ conversations: summaries });
  });

  router.get("/conversations/:id/messages", async (req, res) => {
    const viewer = viewerId(res.locals);
    const query = listMessagesQuerySchema.parse(req.query);
    const conversation = await myConversation(req.params.id, viewer);
    const page = await listMessages(conversation._id, {
      before: query.before ? new Types.ObjectId(query.before) : undefined,
      after: query.after ? new Types.ObjectId(query.after) : undefined,
      limit: query.limit,
    });
    res.json({ messages: page.messages.map(toMessage), hasMore: page.hasMore });
  });

  // Retrying with the same clientId returns the same message.
  router.post("/conversations/:id/messages", async (req, res) => {
    const viewer = viewerId(res.locals);
    const body = sendMessageBodySchema.parse(req.body);
    const conversation = await myConversation(req.params.id, viewer);
    const peer = peerOf(conversation, viewer);
    if (peer && (await blockedWith(viewer)).some((b) => b.equals(peer.user))) {
      throw new HttpError(403, "forbidden", "You can't message this person.");
    }
    const message = await createMessage({
      conversation: conversation._id, sender: viewer, clientId: body.clientId, body: body.body, kind: "text",
    });
    res.status(201).json({ message: toMessage(message.toObject()) });
  });

  // Unsend for everyone: only the sender, never a system message.
  router.delete("/conversations/:id/messages/:messageId", async (req, res) => {
    const viewer = viewerId(res.locals);
    const conversation = await myConversation(req.params.id, viewer);
    const messageId = objectId.parse(req.params.messageId);
    const message = await MessageModel.findOne({ _id: messageId, conversation: conversation._id }).lean();
    if (!message) throw new HttpError(404, "not_found", "That message is already gone.");
    if (!message.sender || !message.sender.equals(viewer)) {
      throw new HttpError(403, "forbidden", "You can only unsend your own messages.");
    }
    await MessageModel.deleteOne({ _id: message._id });
    res.json({ ok: true });
  });

  router.post("/conversations/:id/read", async (req, res) => {
    const viewer = viewerId(res.locals);
    const conversation = await myConversation(req.params.id, viewer);
    const lastReadAt = new Date();
    await ConversationModel.updateOne(
      { _id: conversation._id, "members.user": viewer },
      { $max: { "members.$.lastReadAt": lastReadAt } },
    );
    res.json({ lastReadAt: lastReadAt.toISOString() });
  });

  return router;
}
