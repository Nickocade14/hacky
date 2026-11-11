import type { components } from "./schema";

export type PublicProfile = components["schemas"]["PublicProfile"];
type ProfilePatch = components["schemas"]["UpdateProfileBody"];
type EventMe = components["schemas"]["EventMe"];
type EventPatch = components["schemas"]["UpdateEventMeBody"];

export const linkFields = [
  ["github", "GitHub"], ["linkedin", "LinkedIn"], ["website", "Website"],
] as const;

export const styleOptions = {
  color: { original: "Original", berry: "Berry", mint: "Mint", sunset: "Sunset", rose: "Rose", ice: "Ice" },
  flair: { none: "Just Hacky", stars: "Star power", hearts: "Love bug" },
  move: { idle: "Chill", bounce: "Happy bounce", dance: "Happy dance", hype: "Victory hop" },
} as const;

type LinkField = typeof linkFields[number][0];
type HackyLook = Record<keyof typeof styleOptions, string>;

export type ProfileDraft = {
  name: string;
  bio: string;
  links: Record<LinkField, string>;
  look: HackyLook;
};

export type EventDraft = Required<EventPatch>;
export const tagFields = ["skills", "skillsWanted", "interests"] as const;

function styleChoice(value: unknown, options: Record<string, string>, fallback: string) {
  return typeof value === "string" && Object.hasOwn(options, value) ? value : fallback;
}

export function profileDraft(profile: PublicProfile): ProfileDraft {
  const { color, flair, move } = profile.hackyStyle;
  return {
    name: profile.name,
    bio: profile.bio ?? "",
    links: { github: profile.links.github ?? "", linkedin: profile.links.linkedin ?? "", website: profile.links.website ?? "" },
    look: {
      color: styleChoice(color, styleOptions.color, "original"),
      flair: styleChoice(flair === "sparks" ? "stars" : flair, styleOptions.flair, "none"),
      move: styleChoice(move, styleOptions.move, "idle"),
    },
  };
}

function normalizeLink(value: string) {
  const link = value.trim();
  return link && !link.includes("://") ? `https://${link}` : link;
}

export function profileChanges(draft: ProfileDraft, saved: PublicProfile): ProfilePatch {
  const baseline = profileDraft(saved);
  const patch: ProfilePatch = {};
  const name = draft.name.trim();
  const bio = draft.bio.trim() || null;
  if (name !== saved.name) patch.name = name;
  if (bio !== (saved.bio?.trim() || null)) patch.bio = bio;
  const links = {} as NonNullable<ProfilePatch["links"]>;
  let linksChanged = false;
  for (const [field] of linkFields) {
    const url = normalizeLink(draft.links[field]);
    if (url) links[field] = url;
    if (url !== normalizeLink(baseline.links[field])) linksChanged = true;
  }
  if (linksChanged) patch.links = links;
  if (Object.keys(styleOptions).some(key => {
    const field = key as keyof HackyLook;
    return baseline.look[field] !== draft.look[field];
  })) {
    patch.hackyStyle = { ...saved.hackyStyle, look: "knit", ...draft.look };
  }
  return patch;
}

export function profileProblem(patch: ProfilePatch): string | null {
  if (patch.name !== undefined && (patch.name.length < 1 || patch.name.length > 80)) {
    return "Enter a name from 1 to 80 characters.";
  }
  if (patch.bio && patch.bio.length > 500) return "Keep your bio to 500 characters.";
  for (const [field, label] of linkFields) {
    const value = patch.links?.[field];
    if (!value) continue;
    if (!value.startsWith("https://") || value.length > 300 || /\s/.test(value)) {
      return `Enter a full HTTPS link for ${label}, up to 300 characters.`;
    }
    try {
      if (!new URL(value).hostname.includes(".")) return `Enter a full HTTPS link for ${label}.`;
    } catch {
      return `Enter a full HTTPS link for ${label}.`;
    }
  }
  if (patch.hackyStyle && JSON.stringify(patch.hackyStyle).length > 2000) return "Hacky style is too large.";
  return null;
}

export function eventDraft({ intake, availability, looking }: EventMe): EventDraft {
  return {
    skills: intake.skills ?? [],
    skillsWanted: intake.skillsWanted ?? [],
    interests: intake.interests ?? [],
    experience: intake.experience ?? null,
    wantsExperienced: intake.wantsExperienced ?? false,
    goal: intake.goal ?? null,
    track: intake.track ?? null,
    idea: intake.idea ?? null,
    motivations: intake.motivations ?? [],
    availability,
    looking,
  };
}

function normalizeEventDraft(draft: EventDraft): EventDraft {
  const normalized = { ...draft, idea: draft.idea?.trim() || null, track: draft.track?.trim() || null };
  for (const field of tagFields) {
    normalized[field] = [...new Set(draft[field].map(tag => tag.trim()).filter(Boolean))];
  }
  return normalized;
}

export function eventChanges(draft: EventDraft, saved: EventMe): EventPatch {
  const next = normalizeEventDraft(draft);
  const before = normalizeEventDraft(eventDraft(saved));
  const patch: EventPatch = {};
  function compare<Field extends keyof EventDraft>(field: Field) {
    if (JSON.stringify(next[field]) !== JSON.stringify(before[field])) patch[field] = next[field];
  }
  for (const field of Object.keys(next) as (keyof EventDraft)[]) compare(field);
  return patch;
}

export function eventProblem(patch: EventPatch): string | null {
  for (const field of tagFields) {
    const tags = patch[field];
    if (tags && (tags.length > 30 || tags.some(tag => tag.length > 40))) {
      return "Add up to 30 entries per list, with at most 40 characters per entry.";
    }
  }
  if (patch.track && patch.track.length > 80) return "Keep your track to 80 characters.";
  if (patch.idea && patch.idea.length > 2000) return "Keep your idea to 2,000 characters.";
  return null;
}
