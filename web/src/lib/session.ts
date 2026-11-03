import type { LoginResult } from "./contracts";

export type Session = Pick<LoginResult, "token" | "expiresAt">;
export const SESSION_STORAGE_KEY = "hacky.session.v1";
let memorySession: Session | null = null;
let useMemoryFallback = false;

function parseSession(input: unknown): Session | null {
  if (!input || typeof input !== "object") return null;
  const candidate = input as Partial<Session>;
  if (typeof candidate.token !== "string" || !candidate.token.trim() || typeof candidate.expiresAt !== "string") return null;
  const expiration = Date.parse(candidate.expiresAt);
  if (!Number.isFinite(expiration) || expiration <= Date.now()) return null;
  return { token: candidate.token, expiresAt: candidate.expiresAt };
}

export function clearSession(): void {
  memorySession = null;
  try { globalThis.localStorage.removeItem(SESSION_STORAGE_KEY); useMemoryFallback = false; }
  catch { useMemoryFallback = true; }
}

export function readSession(): Session | null {
  if (useMemoryFallback) {
    const session = parseSession(memorySession);
    if (!session) clearSession();
    return session;
  }
  let raw: string | null;
  try { raw = globalThis.localStorage.getItem(SESSION_STORAGE_KEY); }
  catch {
    useMemoryFallback = true;
    const session = parseSession(memorySession);
    if (!session) clearSession();
    return session;
  }
  if (!raw) { memorySession = null; return null; }
  try {
    const session = parseSession(JSON.parse(raw));
    if (!session) { clearSession(); return null; }
    memorySession = session;
    return { ...session };
  } catch { clearSession(); return null; }
}

export function saveSession(input: Session): void {
  const session = parseSession(input);
  if (!session) { clearSession(); throw new Error("Your session is invalid. Please log in again."); }
  memorySession = session;
  try { globalThis.localStorage.setItem(SESSION_STORAGE_KEY, JSON.stringify(session)); useMemoryFallback = false; }
  catch { useMemoryFallback = true; }
}
