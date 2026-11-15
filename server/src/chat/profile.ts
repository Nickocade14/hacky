import { randomUUID } from "node:crypto";
import { EXPERIENCE } from "../models/enums.js";

// "Add frontend to my skills", "agrega que tengo experiencia en frontend",
// or a pasted LinkedIn/GitHub link: Hacky proposes a profile change as a
// tool-update_profile card. Nothing is saved here; the client saves the
// proposal with the existing PATCH endpoints when the user taps Save.

const LINK = /(?:https?:\/\/)?(?:www\.)?(?:linkedin\.com|github\.com)\/[^\s<>"')]+/i;
const OWN_PROFILE = /\b(my|mi|mis)\s+(profile|perfil|skills?|bio|habilidades|intereses|interests|links?|linkedin|github|website|web)\b/i;
const EDIT_VERB = /\b(add|agrega|agregar|añade|añadir|anade|pon|put|remove|quita|quitar|borra|borrar|delete|update|actualiza|change|cambia|set)\b/i;
const I_KNOW = /\b(i\s+(have|know|do|am\s+good\s+at)|i'm\s+good\s+at|(yo\s+)?(tengo|s[eé]))\b.{0,40}\b(experience|experiencia|skills?)\b/i;
const FIND = /\b(find|busca|buscar|encuentra|looking\s+for|who|qui[eé]n|someone|somebody|alguien|teammates?|mentors?|people|gente)\b/i;

export function wantsProfileEdit(text: string): boolean {
  if (LINK.test(text) && !FIND.test(text)) return true;
  if (OWN_PROFILE.test(text) && (EDIT_VERB.test(text) || I_KNOW.test(text))) return true;
  // "I have experience in frontend", unless they're asking for people.
  return I_KNOW.test(text) && !FIND.test(text);
}

export type Links = { github?: string; linkedin?: string; website?: string };

// Links only ever come from what the user typed, never from the model.
export function linksFrom(text: string): Links {
  const links: Links = {};
  const urls = text.match(/(?:https?:\/\/|www\.)[^\s<>"')]+|(?:linkedin\.com|github\.com)\/[^\s<>"')]+/gi) ?? [];
  for (const raw of urls) {
    const url = normalizeUrl(raw);
    if (!url) continue;
    const host = new URL(url).hostname.replace(/^www\./, "");
    const key = host === "github.com" ? "github" : host === "linkedin.com" || host.endsWith(".linkedin.com") ? "linkedin" : "website";
    links[key] ??= url;
  }
  return links;
}

function normalizeUrl(raw: string): string | null {
  const trimmed = raw.replace(/[.,;:!?]+$/, "");
  const withScheme = /^https?:\/\//i.test(trimmed) ? trimmed.replace(/^http:/i, "https:") : `https://${trimmed}`;
  try {
    const url = new URL(withScheme);
    if (url.protocol !== "https:" || !url.hostname.includes(".") || withScheme.length > 300) return null;
    return url.toString();
  } catch {
    return null;
  }
}

export type Experience = (typeof EXPERIENCE)[number];

// What the model may return (gemini.ts validates the shape).
export interface ProfileEdit {
  reply: string;
  addSkills: string[];
  removeSkills: string[];
  addSkillsWanted: string[];
  addInterests: string[];
  experience: Experience | null;
  bio: string | null;
}

export interface CurrentProfile {
  skills: string[];
  skillsWanted: string[];
  interests: string[];
  experience: string | null;
  bio: string | null;
  links: Links;
}

type Change = { field: string; label: string; added?: string[]; removed?: string[]; value?: string };

export interface Proposal {
  status: "proposed";
  profile: { bio?: string; links?: Links };
  intake: { skills?: string[]; skillsWanted?: string[]; interests?: string[]; experience?: Experience };
  changes: Change[];
}

const cleanTag = (tag: string) => tag.replace(/\s+/g, " ").trim().slice(0, 40);
const key = (tag: string) => tag.toLowerCase();

// current + added - removed, case-insensitive, keeping the user's spelling. At most 30 (the contract's Tags).
function mergeTags(current: string[], add: string[], remove: string[] = []) {
  const removeKeys = new Set(remove.map(cleanTag).map(key));
  const have = new Set(current.map(key));
  const added: string[] = [];
  for (const tag of add.map(cleanTag)) {
    if (!tag || have.has(key(tag)) || removeKeys.has(key(tag))) continue;
    have.add(key(tag));
    added.push(tag);
  }
  const removed = current.filter((tag) => removeKeys.has(key(tag)));
  const next = [...current.filter((tag) => !removeKeys.has(key(tag))), ...added].slice(0, 30);
  return { next, added: added.filter((tag) => next.includes(tag)), removed };
}

const LIST_LABELS = { skills: "Skills", skillsWanted: "Skills you want on your team", interests: "Interests" } as const;
const LINK_LABELS = { github: "GitHub", linkedin: "LinkedIn", website: "Website" } as const;

// Turns the model's edit and the typed links into ready-to-send PATCH bodies.
// Returns null when nothing would change.
export function buildProposal(current: CurrentProfile, edit: ProfileEdit | null, links: Links): Proposal | null {
  const proposal: Proposal = { status: "proposed", profile: {}, intake: {}, changes: [] };

  const lists = [
    ["skills", edit?.addSkills ?? [], edit?.removeSkills ?? []],
    ["skillsWanted", edit?.addSkillsWanted ?? [], []],
    ["interests", edit?.addInterests ?? [], []],
  ] as const;
  for (const [field, add, remove] of lists) {
    const { next, added, removed } = mergeTags(current[field], [...add], [...remove]);
    if (!added.length && !removed.length) continue;
    proposal.intake[field] = next;
    proposal.changes.push({ field, label: LIST_LABELS[field], ...(added.length ? { added } : {}), ...(removed.length ? { removed } : {}) });
  }

  if (edit?.experience && (EXPERIENCE as readonly string[]).includes(edit.experience) && edit.experience !== current.experience) {
    proposal.intake.experience = edit.experience;
    proposal.changes.push({ field: "experience", label: "Experience", value: edit.experience });
  }

  const bio = edit?.bio?.replace(/\s+/g, " ").trim().slice(0, 500);
  if (bio && bio !== current.bio) {
    proposal.profile.bio = bio;
    proposal.changes.push({ field: "bio", label: "Bio", value: bio });
  }

  // PATCH /api/me/profile replaces the whole set of links, so keep the others.
  const newLinks = (Object.keys(LINK_LABELS) as (keyof Links)[]).filter((k) => links[k] && links[k] !== current.links[k]);
  if (newLinks.length) {
    proposal.profile.links = { ...current.links };
    for (const k of newLinks) {
      proposal.profile.links[k] = links[k];
      proposal.changes.push({ field: k, label: LINK_LABELS[k], value: links[k] });
    }
  }

  return proposal.changes.length ? proposal : null;
}

export function proposalPart(proposal: Proposal, text: string) {
  return {
    type: "tool-update_profile",
    toolCallId: `call-${randomUUID()}`,
    state: "output-available",
    input: { query: text },
    output: proposal,
  };
}

export const PROFILE_REPLIES = {
  proposed: "Here's what I'd change. Check it and tap Save to update your profile.",
  linksOnly: "I found your link. Check it and tap Save to add it to your profile.",
  nothing: "I couldn't tell what to change. Try \"add React to my skills\" or paste your LinkedIn link.",
};
