import { randomUUID } from "node:crypto";
import { APICallError, LoadAPIKeyError, NoObjectGeneratedError, RetryError } from "ai";
import { Router } from "express";
import mongoose from "mongoose";
import { z } from "zod";
import { HttpError } from "../errors.js";
import { blockedWith, requireMembership } from "../events/access.js";
import { viewerId } from "../me.js";
import { AgentMessageModel } from "../models/AgentMessage.js";
import { ProfileModel } from "../models/Profile.js";
import { type CandidateRow, intentOf, loadCandidates, matchedSkills, summaryLine } from "./candidates.js";
import { type RankOutput, type Ranker, defaultRanker } from "./gemini.js";

export const chatQuerySchema = z.object({
  format: z.enum(["stream", "json"]).default("stream"),
});

export const chatBodySchema = z.object({
  message: z.object({
    // Mobile sends "mobile-<micros>-<n>"; AI SDK ids are short alphanumerics.
    id: z.string().regex(/^[A-Za-z0-9_-]{1,100}$/).refine((id) => !id.startsWith("reply-"), "Reserved id"),
    role: z.literal("user"),
    parts: z.array(z.looseObject({ type: z.string() })).min(1).max(20),
  }).transform((m, ctx) => {
    // Only the user's text is kept and stored; other parts are dropped.
    const text = m.parts
      .filter((p) => p.type === "text" && typeof p.text === "string")
      .map((p) => (p.text as string).trim())
      .filter(Boolean).join("\n");
    if (text.length < 1 || text.length > 1000) {
      ctx.addIssue({ code: "custom", path: ["parts"], message: "Send 1-1000 characters of text" });
      return z.NEVER;
    }
    return { id: m.id, text };
  }),
});

type Part = Record<string, unknown> & { type: string };
type StoredMessage = { messageId: string; role: string; parts: Part[] };

const toChatMessage = (doc: StoredMessage) => ({ id: doc.messageId, role: doc.role, parts: doc.parts });

const textOf = (parts: Part[]) =>
  parts.filter((p) => p.type === "text" && typeof p.text === "string").map((p) => p.text as string).join(" ");

const handlesOf = (parts: Part[]) => parts.flatMap((p) => {
  if (p.type !== "tool-search_people") return [];
  const cards = ((p.output as { cards?: { person?: { handle?: string } }[] } | undefined)?.cards ?? []);
  return cards.flatMap((c) => (c.person?.handle ? [`@${c.person.handle}`] : []));
});

// One line per past message for context, capped at 300 chars.
function historyLine(doc: StoredMessage): string {
  const text = textOf(doc.parts).replace(/\s+/g, " ");
  const handles = handlesOf(doc.parts);
  const line = doc.role === "user"
    ? `user: ${text}`
    : `hacky: ${text}${handles.length ? ` [suggested: ${handles.join(", ")}]` : ""}`;
  return line.slice(0, 300);
}

// AI SDK and provider errors to the contract's error codes. Unknown errors become 500.
export function toHttpError(error: unknown): unknown {
  const err = RetryError.isInstance(error) ? error.lastError : error;
  if (err instanceof HttpError) return err;
  const name = (err as { name?: string } | null)?.name;
  if (name === "TimeoutError" || name === "AbortError") {
    return new HttpError(504, "ai_timeout", "Hacky took too long. Please try again.");
  }
  if (APICallError.isInstance(err)) {
    return err.statusCode === 429
      ? new HttpError(429, "rate_limited", "Hacky is busy right now. Please try again in a minute.")
      : new HttpError(503, "ai_unavailable", "Hacky is offline right now. Please try again later.");
  }
  if (LoadAPIKeyError.isInstance(err)) {
    return new HttpError(503, "ai_unavailable", "Hacky is offline right now. Please try again later.");
  }
  if (NoObjectGeneratedError.isInstance(err)) {
    return new HttpError(502, "ai_bad_response", "Hacky got confused. Please try again.");
  }
  return err;
}

const NO_ONE = {
  teammate: "There's no one at this event I can suggest for that yet.",
  mentor: "No mentors have joined this event yet.",
};

// Builds the assistant parts from what the model returned, trusting none of its ids.
function assistantParts(out: RankOutput | null, refs: Map<string, CandidateRow>, intent: "mentor" | "teammate", text: string): Part[] {
  const picked: { row: CandidateRow; reason: string }[] = [];
  for (const match of out?.matches ?? []) {
    const row = refs.get(match.ref);
    if (!row) { console.warn(`[chat] dropped unknown ref ${JSON.stringify(match.ref).slice(0, 20)}`); continue; }
    if (picked.some((p) => p.row === row) || picked.length >= 3) continue;
    const reason = match.reason.replace(/\s+/g, " ").trim().slice(0, 160)
      || `Knows ${(row.skills ?? []).slice(0, 3).join(", ")}.`;
    picked.push({ row, reason });
  }

  const handles = new Set(picked.map((p) => p.row.profile.handle.toLowerCase()));
  let reply = (out?.reply ?? "").trim().slice(0, 500)
    // Mobile turns @handle into a profile link, so invented handles lose the @.
    .replace(/@([a-z0-9_]{1,30})/gi, (all, handle: string) => (handles.has(handle.toLowerCase()) ? all : handle));
  if (!reply) {
    reply = picked.length
      ? "Here's who could help. Tap a card to see their profile or connect."
      : "I didn't find anyone for that yet. Try a skill, like \"flutter\" or \"python\".";
  }

  const parts: Part[] = [{ type: "text", text: reply }];
  if (picked.length) {
    parts.push({
      type: "tool-search_people",
      toolCallId: `call-${randomUUID()}`,
      state: "output-available",
      input: { query: text },
      output: {
        status: "matches",
        kind: intent === "mentor" ? "mentor" : "hacker",
        cards: picked.map(({ row, reason }) => ({
          card: intent === "mentor" ? "mentor" : "person",
          person: {
            userId: row.profile._id.toString(),
            handle: row.profile.handle,
            name: row.profile.name,
            hackyStyle: row.profile.hackyStyle ?? {},
            photoUrl: row.profile.photoUrl ?? null,
            role: row.role,
          },
          ...(intent === "mentor" ? { verified: row.verified ?? false } : {}),
          skills: row.skills ?? [],
          evidence: {
            matchedSkills: matchedSkills(row.skills, text),
            ...(intent === "mentor" ? { availability: row.availability ?? "available" } : {}),
          },
          reason,
        })),
      },
    });
  }
  return parts;
}

// Mounted at /api/events after requireAuth.
export function createChatRouter({ rank = defaultRanker }: { rank?: Ranker } = {}): Router {
  const router = Router();

  router.get("/:slug/chat", async (req, res) => {
    const viewer = viewerId(res.locals);
    const { event } = await requireMembership(req.params.slug, viewer);
    const docs = await AgentMessageModel.find({ user: viewer, event: event._id })
      .sort({ createdAt: -1, _id: -1 }).limit(200).lean<StoredMessage[]>();
    docs.reverse();
    // Cards are snapshots, so hide people the viewer blocked (or who blocked them) since.
    const blocked = new Set((await blockedWith(viewer)).map(String));
    const messages = docs.map((doc) => toChatMessage({
      ...doc,
      parts: doc.parts.flatMap((part) => {
        if (part.type !== "tool-search_people") return [part];
        const output = part.output as { cards?: { person?: { userId?: string } }[] } | undefined;
        const cards = (output?.cards ?? []).filter((c) => !blocked.has(c.person?.userId ?? ""));
        return cards.length ? [{ ...part, output: { ...output, cards } }] : [];
      }),
    }));
    res.json({ messages });
  });

  router.post("/:slug/chat", async (req, res) => {
    const viewer = viewerId(res.locals);
    const { format } = chatQuerySchema.parse(req.query);
    const body = chatBodySchema.parse(req.body).message;
    if (format === "stream") {
      throw new HttpError(501, "not_implemented", "Streaming isn't available yet. Use ?format=json.");
    }
    const { event, membership } = await requireMembership(req.params.slug, viewer);

    // Mobile's Retry resends the same id: answer with the saved reply, no Gemini call.
    const replyId = `reply-${body.id}`;
    const saved = await AgentMessageModel.findOne({ user: viewer, event: event._id, messageId: replyId }).lean<StoredMessage>();
    if (saved) {
      res.json({ message: toChatMessage(saved) });
      return;
    }

    const excluded = [viewer, ...await blockedWith(viewer)];
    const intent = intentOf(body.text);
    const rows = await loadCandidates(event._id, excluded, intent, body.text);

    let parts: Part[];
    if (rows.length === 0) {
      parts = [{ type: "text", text: NO_ONE[intent] }];
    } else {
      const refs = new Map(rows.map((row, i) => [`p${i + 1}`, row]));
      const viewerProfile = await ProfileModel.findById(viewer).select("handle name hackyStyle photoUrl").lean();
      const history = (await AgentMessageModel.find({ user: viewer, event: event._id })
        .sort({ createdAt: -1, _id: -1 }).limit(6).lean<StoredMessage[]>()).reverse().map(historyLine);
      let out: RankOutput;
      try {
        out = await rank({
          eventName: event.name,
          tracks: event.tracks ?? [],
          viewerLine: viewerProfile ? summaryLine({ ...membership, profile: viewerProfile } as CandidateRow) : "(unknown)",
          history,
          intent,
          candidates: [...refs].map(([ref, row]) => ({ ref, line: summaryLine(row, ref) })),
          text: body.text,
        });
      } catch (error) {
        throw toHttpError(error);
      }
      parts = assistantParts(out, refs, intent, body.text);
    }

    // Both messages are saved or neither is, so Retry works after a failure.
    const userDoc = { user: viewer, event: event._id, messageId: body.id, role: "user", parts: [{ type: "text", text: body.text }] };
    const replyDoc = { user: viewer, event: event._id, messageId: replyId, role: "assistant", parts };
    try {
      await mongoose.connection.transaction(async (session) => {
        await AgentMessageModel.insertMany([userDoc, replyDoc], { session });
      });
    } catch (error) {
      if ((error as { code?: number }).code !== 11000) throw error;
      // Same id sent twice at once: the other request saved it first.
      const winner = await AgentMessageModel.findOne({ user: viewer, event: event._id, messageId: replyId }).lean<StoredMessage>();
      if (!winner) throw new HttpError(409, "conflict", "That message id was already used. Please send it again.");
      res.json({ message: toChatMessage(winner) });
      return;
    }
    res.json({ message: toChatMessage({ messageId: replyId, role: "assistant", parts }) });
  });

  return router;
}

export const chatRouter = createChatRouter();

