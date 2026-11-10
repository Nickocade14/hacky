import { describe, expect, it, vi } from "vitest";
import { ApiClientError, createApiClient } from "../src/lib/api";

const json = (data: unknown, status = 200) => new Response(JSON.stringify(data), { status, headers: { "Content-Type": "application/json" } });

describe("contract API client", () => {
  it("uses all six public auth paths without leaking a saved Bearer token", async () => {
    const fetcher = vi.fn<typeof fetch>().mockImplementation(async () => json({ ok: true }));
    const getToken = vi.fn(() => "saved-jwt");
    const client = createApiClient({ baseUrl: "https://hacky.example/api/", fetch: fetcher, getToken });
    const register = { name: "Ethan", handle: "ethan_z", email: "ethan@example.com", password: "valid-password" };
    const verify = { email: register.email, code: "012345" };
    const reset = { email: register.email, code: "067890", password: register.password };
    await client.register(register);
    await client.verifyEmail(verify);
    await client.resendVerification({ email: register.email });
    await client.login({ email: register.email, password: register.password });
    await client.forgotPassword({ email: register.email });
    await client.resetPassword(reset);
    expect(fetcher.mock.calls.map(([url]) => String(url))).toEqual(["register", "verify-email", "resend-verification", "login", "forgot-password", "reset-password"].map(path => `https://hacky.example/api/auth/${path}`));
    expect(JSON.parse(String(fetcher.mock.calls[0]![1]?.body))).toEqual(register);
    expect(JSON.parse(String(fetcher.mock.calls[1]![1]?.body))).toEqual(verify);
    expect(JSON.parse(String(fetcher.mock.calls[5]![1]?.body))).toEqual(reset);
    for (const [, init] of fetcher.mock.calls) {
      expect(init?.method).toBe("POST");
      expect(new Headers(init?.headers).has("Authorization")).toBe(false);
      expect(new Headers(init?.headers).get("Content-Type")).toBe("application/json");
      expect(init?.credentials).toBe("omit");
    }
    expect(getToken).not.toHaveBeenCalled();
  });

  it("adds the Bearer token and abort signal to protected requests", async () => {
    const fetcher = vi.fn<typeof fetch>().mockResolvedValue(json({ profile: {}, events: [] }));
    const client = createApiClient({ baseUrl: " /api/ ", fetch: fetcher, getToken: () => "jwt-value" });
    const controller = new AbortController();
    await client.getMe(controller.signal);
    const [url, init] = fetcher.mock.calls[0]!;
    expect(url).toBe("/api/me");
    expect(init?.method).toBe("GET");
    expect(init?.signal).toBe(controller.signal);
    expect(init?.body).toBeUndefined();
    expect(new Headers(init?.headers).get("Authorization")).toBe("Bearer jwt-value");
  });

  it("does not send a protected request without a session", async () => {
    const fetcher = vi.fn<typeof fetch>();
    const client = createApiClient({ fetch: fetcher, getToken: () => null });
    await expect(client.getMe()).rejects.toMatchObject({ status: 401, code: "unauthorized" });
    expect(fetcher).not.toHaveBeenCalled();
  });

  it("preserves the contract's error message, code, status, and details", async () => {
    const details = { field: "code" };
    const fetcher = vi.fn<typeof fetch>().mockResolvedValue(json({ error: { code: "invalid_code", message: "This code has expired.", details } }, 400));
    const client = createApiClient({ fetch: fetcher });
    await expect(client.verifyEmail({ email: "a@example.com", code: "012345" })).rejects.toMatchObject({ message: "This code has expired.", status: 400, code: "invalid_code", details });
  });

  it("distinguishes network failures, unavailable routes, and unexpected HTML", async () => {
    const fetcher = vi.fn<typeof fetch>();
    const client = createApiClient({ fetch: fetcher });
    fetcher.mockRejectedValueOnce(new TypeError("Failed to fetch"));
    await expect(client.forgotPassword({ email: "a@example.com" })).rejects.toMatchObject({ kind: "network" });
    fetcher.mockResolvedValueOnce(new Response("Not found", { status: 404 }));
    await expect(client.forgotPassword({ email: "a@example.com" })).rejects.toMatchObject({ kind: "unavailable", status: 404 });
    fetcher.mockResolvedValueOnce(new Response("<!doctype html><title>SPA fallback</title>"));
    await expect(client.forgotPassword({ email: "a@example.com" })).rejects.toMatchObject({ kind: "server", status: 200 });
    fetcher.mockResolvedValueOnce(json({ error: { code: "internal", message: "Please try later." } }, 500));
    await expect(client.forgotPassword({ email: "a@example.com" })).rejects.toMatchObject({ kind: "server", status: 500, message: "Please try later." });
  });

  it("preserves aborts from fetch and response reading", async () => {
    const abort = new DOMException("Cancelled", "AbortError");
    const fetcher = vi.fn<typeof fetch>().mockRejectedValueOnce(abort);
    const client = createApiClient({ fetch: fetcher });
    const verify = { email: "a@example.com", code: "012345" };
    await expect(client.verifyEmail(verify)).rejects.toBe(abort);
    const response = json({ ok: true });
    vi.spyOn(response, "json").mockRejectedValueOnce(abort);
    fetcher.mockResolvedValueOnce(response);
    await expect(client.verifyEmail(verify)).rejects.toBe(abort);
    expect(abort).not.toBeInstanceOf(ApiClientError);
  });
});
