import { useState } from "react";
import type { components } from "../lib/schema";

type HackyStyle = components["schemas"]["HackyStyle"];
type Person = { userId?: string; name: string; photoUrl?: string | null; hackyStyle?: HackyStyle };

// The knit avatars from mlhacky.com (seeko-codes/Hacky react/public/assets/mascots/avatars).
const colors = ["original", "berry", "mint", "sunset", "rose", "ice"] as const;

function hash(text: string) {
  let value = 0;
  for (const char of text) value = (value * 31 + char.charCodeAt(0)) >>> 0;
  return value;
}

/** The person's chosen knit color, or a steady one picked from their id so lists don't look identical. */
export function knitAvatarUrl(person: Person) {
  const chosen = person.hackyStyle?.color;
  const color = typeof chosen === "string" && (colors as readonly string[]).includes(chosen)
    ? chosen
    : colors[hash(person.userId ?? person.name) % colors.length];
  return `/assets/mascots/avatars/knit-${color}-none.webp`;
}

/** Their photo (unless they chose to show their Hacky), else a knit Hacky, else initials. Decorative. */
export function KnitAvatar({ person, size = 40 }: { person: Person; size?: number }) {
  const photo = person.hackyStyle?.avatar !== "hacky" && person.photoUrl ? person.photoUrl : null;
  const sources = [photo, knitAvatarUrl(person)].filter((source): source is string => !!source);
  const [failed, setFailed] = useState<string[]>([]);
  const source = sources.find(item => !failed.includes(item));
  const initials = person.name.trim().split(/\s+/).slice(0, 2).map(part => Array.from(part)[0]).join("").toUpperCase();
  return <span className={`hk-avatar${source === photo && photo ? " photo" : ""}`} style={{ width: size, height: size }} aria-hidden="true">
    {source
      ? <img key={source} src={source} alt="" loading="lazy" decoding="async" onError={() => setFailed(list => [...list, source])} />
      : initials}
  </span>;
}
