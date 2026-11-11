import { useEffect, useState } from "react";

export type Theme = "light" | "dark";
const key = "hacky-theme";

function saved(): Theme | null {
  try {
    const value = window.localStorage.getItem(key);
    return value === "dark" || value === "light" ? value : null;
  } catch {
    return null;
  }
}

const system = (): Theme =>
  typeof window.matchMedia === "function" && window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";

/** Light or dark for the signed-in workspace: my saved choice, else the system's. */
export function useTheme() {
  const [theme, setTheme] = useState<Theme>(() => saved() ?? system());
  useEffect(() => {
    document.documentElement.dataset.theme = theme;
    return () => { delete document.documentElement.dataset.theme; };
  }, [theme]);
  function toggle() {
    const next: Theme = theme === "dark" ? "light" : "dark";
    setTheme(next);
    try { window.localStorage.setItem(key, next); } catch { /* private mode: the choice lasts this visit */ }
  }
  return { theme, toggle };
}

/** True while the viewport matches (false where matchMedia is missing). */
export function useMedia(query: string) {
  const read = () => typeof window.matchMedia === "function" && window.matchMedia(query).matches;
  const [matches, setMatches] = useState(read);
  useEffect(() => {
    if (typeof window.matchMedia !== "function") return;
    const media = window.matchMedia(query);
    const update = () => setMatches(media.matches);
    update();
    media.addEventListener("change", update);
    return () => media.removeEventListener("change", update);
  }, [query]);
  return matches;
}
