import type { ChatMessage } from "./contracts";

// Reads Hacky's answers. The server sends AI SDK message parts: text, and a
// "tool-search_people" part whose output holds the person or mentor cards
// (same shapes mobile reads in mobile/lib/hacky/hacky_parts.dart).

export type CardPerson = { userId: string; handle: string; name: string; photoUrl: string | null; role: string };

export type HackyCard = {
  mentor: boolean;
  person: CardPerson;
  skills: string[];
  matchedSkills: string[];
  reason: string;
  verified: boolean;
  availability: string | null;
};

export type HackyPart =
  | { type: "text"; text: string }
  | { type: "cards"; mentors: boolean; cards: HackyCard[] };

type Json = Record<string, unknown>;
const isObject = (value: unknown): value is Json => typeof value === "object" && value !== null && !Array.isArray(value);
const asString = (value: unknown) => (typeof value === "string" ? value : "");
const strings = (value: unknown) => (Array.isArray(value) ? value.filter((item): item is string => typeof item === "string") : []);

function cardOf(value: unknown): HackyCard | null {
  if (!isObject(value) || !isObject(value.person)) return null;
  const person = value.person;
  const userId = asString(person.userId), handle = asString(person.handle), name = asString(person.name);
  if (!userId || !handle || !name) return null;
  const evidence = isObject(value.evidence) ? value.evidence : {};
  return {
    mentor: value.card === "mentor",
    person: { userId, handle, name, photoUrl: asString(person.photoUrl) || null, role: asString(person.role) || "hacker" },
    skills: strings(value.skills),
    matchedSkills: strings(evidence.matchedSkills),
    reason: asString(value.reason).trim(),
    verified: value.verified === true,
    availability: asString(evidence.availability) || null,
  };
}

/** The parts of an assistant message this page can show, in order. Unknown parts are skipped. */
export function partsOf(message: ChatMessage): HackyPart[] {
  const parts: HackyPart[] = [];
  for (const part of message.parts) {
    if (part.type === "text") {
      const text = asString(part.text).trim();
      if (text) parts.push({ type: "text", text });
    } else if (part.type === "tool-search_people" && isObject(part.output)) {
      const cards = (Array.isArray(part.output.cards) ? part.output.cards : []).map(cardOf).filter((card): card is HackyCard => card !== null);
      if (cards.length) parts.push({ type: "cards", mentors: part.output.kind === "mentor", cards });
    }
  }
  return parts;
}

/** All the text of a message (what I typed). */
export const textOf = (message: ChatMessage) =>
  message.parts.filter((part) => part.type === "text").map((part) => asString(part.text)).join("\n").trim();

/** Up to three skills, the ones I asked for first. */
export function shownSkills(card: HackyCard) {
  const matched = new Set(card.matchedSkills.map((skill) => skill.toLowerCase()));
  return [...card.skills].sort((a, b) => Number(matched.has(b.toLowerCase())) - Number(matched.has(a.toLowerCase()))).slice(0, 3);
}

/** Why Hacky picked them: its own reason, or the skills that matched. */
export const whyLine = (card: HackyCard) =>
  card.reason || (card.matchedSkills.length ? `Knows ${card.matchedSkills.slice(0, 3).join(", ")}.` : "");

export function firstName(name: string) {
  return name.trim().split(/\s+/)[0] || "there";
}

/** SendRequestBody.intro: 1–500 characters, no links. Same rules as mobile's IntroRules. */
export function introProblem(intro: string): string | null {
  const text = intro.trim();
  if (!text) return "Write a short intro first.";
  if (text.length > 500) return "Keep it under 500 characters.";
  if (/https?:\/\/|www\./i.test(text)) return "Intros can’t contain links.";
  return null;
}

export const openingIntro = (myName: string, them: string) =>
  `Hi ${firstName(them)}! I’m ${firstName(myName)}. Hacky thought we could team up. Want to chat?`;

let sent = 0;
/** A message id the server accepts (letters, numbers, _ and -). */
export const newMessageId = () => `web-${Date.now()}-${sent++}`;
