import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { clearSession, readSession, saveSession, SESSION_STORAGE_KEY } from "../src/lib/session";

function fakeStorage() {
  const entries = new Map<string, string>();
  return {
    getItem: vi.fn((key: string) => entries.get(key) ?? null),
    setItem: vi.fn((key: string, value: string) => { entries.set(key, value); }),
    removeItem: vi.fn((key: string) => { entries.delete(key); }),
  };
}
let storage: ReturnType<typeof fakeStorage>;
const session = () => ({ token: "jwt-value", expiresAt: new Date(Date.now() + 60_000).toISOString() });

beforeEach(() => { storage = fakeStorage(); vi.stubGlobal("localStorage", storage); clearSession(); });
afterEach(() => { clearSession(); vi.unstubAllGlobals(); vi.useRealTimers(); });

describe("JWT session", () => {
  it("stores only token and expiry even when passed the full login response", () => {
    const expected = session();
    saveSession({ ...expected, me: { name: "Private profile" }, password: "never-persist" } as typeof expected);
    expect(JSON.parse(storage.getItem(SESSION_STORAGE_KEY)!)).toEqual(expected);
    expect(readSession()).toEqual(expected);
  });

  it("discards malformed, corrupt, and expired stored sessions", () => {
    for (const raw of ["broken-json", "null", "{}", JSON.stringify({ token: "jwt", expiresAt: "yesterday" }), JSON.stringify({ token: "jwt", expiresAt: new Date(Date.now() - 1).toISOString() })]) {
      storage.setItem(SESSION_STORAGE_KEY, raw);
      expect(readSession()).toBeNull();
      expect(storage.getItem(SESSION_STORAGE_KEY)).toBeNull();
    }
  });

  it("honors a logout from another tab rather than reusing memory", () => {
    saveSession(session());
    storage.removeItem(SESSION_STORAGE_KEY);
    expect(readSession()).toBeNull();
  });

  it("keeps working in memory when persistent storage is blocked", () => {
    const expected = session();
    storage.setItem.mockImplementation(() => { throw new Error("Storage blocked"); });
    storage.getItem.mockImplementation(() => { throw new Error("Storage blocked"); });
    storage.removeItem.mockImplementation(() => { throw new Error("Storage blocked"); });
    saveSession(expected);
    expect(readSession()).toEqual(expected);
    clearSession();
    expect(readSession()).toBeNull();
  });

  it("expires memory fallback sessions and never resurrects a failed logout", () => {
    vi.useFakeTimers();
    const expected = session();
    storage.setItem(SESSION_STORAGE_KEY, JSON.stringify(expected));
    storage.setItem.mockImplementation(() => { throw new Error("Quota exceeded"); });
    storage.removeItem.mockImplementation(() => { throw new Error("Storage blocked"); });
    saveSession(expected);
    expect(readSession()).toEqual(expected);
    vi.setSystemTime(Date.now() + 60_001);
    expect(readSession()).toBeNull();
    vi.setSystemTime(Date.now() - 60_001);
    expect(readSession()).toBeNull();
  });

  it("rejects an invalid login expiry instead of persisting a broken session", () => {
    expect(() => saveSession({ token: "jwt", expiresAt: "not-a-date" })).toThrow("session is invalid");
    expect(readSession()).toBeNull();
  });
});
