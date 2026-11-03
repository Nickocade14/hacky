import { StrictMode } from "react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { act, cleanup, render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter } from "react-router-dom";
import { App } from "../src/App";
import { clearSession, readSession, saveSession } from "../src/lib/session";
import type { LoginResult } from "../src/lib/contracts";

const fetchMock = vi.fn<typeof fetch>();

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function renderApp(path = "/", strict = false) {
  const app = <MemoryRouter initialEntries={[path]}><App /></MemoryRouter>;
  return render(strict ? <StrictMode>{app}</StrictMode> : app);
}

function loginResult(): LoginResult {
  return {
    token: "test-jwt",
    expiresAt: new Date(Date.now() + 60_000).toISOString(),
    me: {
      profile: {
        userId: "6717a3f2c9e1b04d2a5e8f10",
        handle: "ethan_z",
        name: "Ethan Zeng",
        hackyStyle: {},
        photoUrl: null,
        bio: null,
        links: {},
        isDemo: false,
      },
      events: [{ slug: "knighthacks-ix", name: "Knight Hacks IX", role: "hacker", verified: false }],
    },
  };
}

async function fillLogin(user: ReturnType<typeof userEvent.setup>, email = "ethan@example.com") {
  await user.type(screen.getByLabelText("Email address"), email);
  await user.type(screen.getByLabelText("Password", { exact: true }), "correct-password");
}

beforeEach(() => {
  window.localStorage.clear();
  clearSession();
  window.history.replaceState({}, "", "/");
  fetchMock.mockReset();
  fetchMock.mockRejectedValue(new Error("Unexpected API call in this test"));
  vi.stubGlobal("fetch", fetchMock);
});

afterEach(() => {
  cleanup();
  clearSession();
  vi.unstubAllGlobals();
});

describe("authentication pages", () => {
  it("starts signed-out visitors at login and connects registration and recovery", async () => {
    const user = userEvent.setup();
    renderApp();

    expect(screen.getByRole("heading", { level: 1 }).textContent).toBe("Welcome back.");
    await user.click(screen.getByRole("link", { name: "Create an account" }));
    expect(screen.getByRole("heading", { level: 1 }).textContent).toContain("make it happen");
    expect(screen.getByLabelText("Handle")).not.toBeNull();

    await user.click(within(screen.getByRole("navigation", { name: "Account" })).getByRole("link", { name: "Log in" }));
    await user.click(screen.getByRole("link", { name: "Forgot password?" }));
    expect(screen.getByRole("heading", { level: 1 }).textContent).toBe("Forgot your password?");
    await user.click(screen.getByRole("link", { name: "Back to log in" }));
    expect(screen.getByRole("heading", { level: 1 }).textContent).toBe("Welcome back.");
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("registers with the required handle and normalized email, then shows inbox instructions", async () => {
    const user = userEvent.setup();
    fetchMock.mockResolvedValueOnce(jsonResponse({ ok: true }, 201));
    renderApp("/register");

    await user.type(screen.getByLabelText("Your name"), "Ethan Zeng");
    await user.type(screen.getByLabelText("Handle"), "ethan_z");
    await user.type(screen.getByLabelText("Email address"), "ETHAN@EXAMPLE.COM");
    await user.type(screen.getByLabelText("Password", { exact: true }), "correct-password");
    await user.click(screen.getByRole("button", { name: "Create account" }));

    expect(await screen.findByRole("heading", { level: 1, name: "Check your inbox." })).not.toBeNull();
    expect(screen.getByText("ethan@example.com", { exact: true })).not.toBeNull();
    expect(fetchMock).toHaveBeenCalledTimes(1);
    const [url, options] = fetchMock.mock.calls[0]!;
    expect(String(url)).toBe("/api/auth/register");
    expect(options?.method).toBe("POST");
    expect(JSON.parse(String(options?.body))).toEqual({ name: "Ethan Zeng", handle: "ethan_z", email: "ethan@example.com", password: "correct-password" });
    expect(readSession()).toBeNull();
  });

  it("keeps an unverified user signed out and offers a resend path with their email", async () => {
    const user = userEvent.setup();
    fetchMock.mockResolvedValueOnce(jsonResponse({ error: { code: "email_not_verified", message: "Check your inbox before logging in." } }, 403));
    renderApp("/login");
    await fillLogin(user);
    await user.click(screen.getByRole("button", { name: "Log in" }));

    expect((await screen.findByRole("alert")).textContent).toBe("Check your inbox before logging in.");
    expect(readSession()).toBeNull();
    await user.click(screen.getByRole("link", { name: "Resend your verification email" }));
    expect((screen.getByLabelText("Email address") as HTMLInputElement).value).toBe("ethan@example.com");
    expect(screen.getByRole("button", { name: "Resend verification link" })).not.toBeNull();
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });

  it("uses the login response to show the account and clears the session on sign-out", async () => {
    const user = userEvent.setup();
    const result = loginResult();
    fetchMock.mockResolvedValueOnce(jsonResponse(result));
    renderApp();
    await fillLogin(user);
    await user.click(screen.getByRole("button", { name: "Log in" }));

    expect(await screen.findByRole("heading", { level: 1, name: /Ethan/ })).not.toBeNull();
    expect(screen.getByRole("heading", { name: "Ethan Zeng", level: 2 })).not.toBeNull();
    expect(screen.getByText("@ethan_z")).not.toBeNull();
    expect(screen.getByText("Knight Hacks IX", { selector: "strong" })).not.toBeNull();
    expect(readSession()).toEqual({ token: result.token, expiresAt: result.expiresAt });
    expect(fetchMock).toHaveBeenCalledTimes(1);

    await user.click(screen.getByRole("button", { name: "Sign out" }));
    expect(screen.getByRole("heading", { level: 1 }).textContent).toBe("Welcome back.");
    expect(readSession()).toBeNull();
  });

  it("disables submission while login is pending and sends only one request", async () => {
    const user = userEvent.setup();
    let finishRequest!: (response: Response) => void;
    fetchMock.mockReturnValueOnce(new Promise<Response>(resolve => { finishRequest = resolve; }));
    renderApp("/login");
    await fillLogin(user);
    const submit = screen.getByRole("button", { name: "Log in" }) as HTMLButtonElement;
    await user.click(submit);

    expect(submit.disabled).toBe(true);
    expect(screen.getByRole("form", { name: "Log in" }).getAttribute("aria-busy")).toBe("true");
    await user.click(submit);
    expect(fetchMock).toHaveBeenCalledTimes(1);

    await act(async () => { finishRequest(jsonResponse(loginResult())); });
    expect(await screen.findByRole("heading", { level: 1, name: /Ethan/ })).not.toBeNull();
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });

  it("returns a restored but rejected session to login", async () => {
    const result = loginResult();
    saveSession(result);
    fetchMock.mockResolvedValueOnce(jsonResponse({ error: { code: "unauthorized", message: "Your session expired." } }, 401));
    renderApp("/app");

    expect(await screen.findByRole("form", { name: "Log in" })).not.toBeNull();
    expect(readSession()).toBeNull();
    expect(String(fetchMock.mock.calls[0]?.[0])).toBe("/api/me");
  });

  it("blocks mismatched reset passwords before sending a request", async () => {
    const user = userEvent.setup();
    renderApp("/reset?token=reset-token");
    await user.type(screen.getByLabelText("New password", { exact: true }), "correct-password");
    await user.type(screen.getByLabelText("Confirm password", { exact: true }), "different-password");
    await user.click(screen.getByRole("button", { name: "Save new password" }));

    expect(screen.getByRole("alert").textContent).toContain("passwords don’t match");
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it.each([
    { boundary: "seven Unicode code points", password: "🦄".repeat(7), message: "at least 8 characters" },
    { boundary: "73 UTF-8 bytes", password: `${"🦄".repeat(18)}a`, message: "at most 72 UTF-8 bytes" },
  ])("blocks a password with $boundary before calling the server", async ({ password, message }) => {
    const user = userEvent.setup();
    renderApp("/reset?token=reset-token");
    await user.type(screen.getByLabelText("New password", { exact: true }), password);
    await user.type(screen.getByLabelText("Confirm password", { exact: true }), password);
    await user.click(screen.getByRole("button", { name: "Save new password" }));

    expect(screen.getByRole("alert").textContent).toContain(message);
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it.each([
    { boundary: "eight Unicode code points", password: "🦄".repeat(8) },
    { boundary: "72 UTF-8 bytes", password: "🦄".repeat(18) },
  ])("accepts a password at the $boundary boundary", async ({ password }) => {
    const user = userEvent.setup();
    fetchMock.mockResolvedValueOnce(jsonResponse({ ok: true }));
    renderApp("/reset?token=reset-token");
    await user.type(screen.getByLabelText("New password", { exact: true }), password);
    await user.type(screen.getByLabelText("Confirm password", { exact: true }), password);
    await user.click(screen.getByRole("button", { name: "Save new password" }));

    expect(await screen.findByRole("heading", { level: 1, name: "Welcome back." })).not.toBeNull();
    expect(fetchMock).toHaveBeenCalledTimes(1);
    expect(JSON.parse(String(fetchMock.mock.calls[0]?.[1]?.body))).toEqual({ token: "reset-token", password });
  });

  it("sends only the reset token and password, then returns to login with confirmation", async () => {
    const user = userEvent.setup();
    fetchMock.mockResolvedValueOnce(jsonResponse({ ok: true }));
    saveSession(loginResult());
    renderApp("/reset?token=reset-token");
    await user.type(screen.getByLabelText("New password", { exact: true }), "new-password");
    await user.type(screen.getByLabelText("Confirm password", { exact: true }), "new-password");
    await user.click(screen.getByRole("button", { name: "Save new password" }));

    expect(await screen.findByRole("heading", { level: 1, name: "Welcome back." })).not.toBeNull();
    expect(screen.getByRole("status").textContent).toBe("Password updated. Log in with your new password.");
    expect(String(fetchMock.mock.calls[0]?.[0])).toBe("/api/auth/reset-password");
    expect(JSON.parse(String(fetchMock.mock.calls[0]?.[1]?.body))).toEqual({ token: "reset-token", password: "new-password" });
    expect(readSession()).toBeNull();
  });

  it("verifies only on an explicit click and makes one request in StrictMode", async () => {
    const user = userEvent.setup();
    fetchMock.mockResolvedValueOnce(jsonResponse({ ok: true }));
    renderApp("/verify?token=verification-token", true);

    expect(fetchMock).not.toHaveBeenCalled();
    await user.click(screen.getByRole("button", { name: "Verify my email" }));
    expect(await screen.findByRole("heading", { level: 1, name: "Email verified." })).not.toBeNull();
    expect(fetchMock).toHaveBeenCalledTimes(1);
    expect(String(fetchMock.mock.calls[0]?.[0])).toBe("/api/auth/verify-email");
    expect(JSON.parse(String(fetchMock.mock.calls[0]?.[1]?.body))).toEqual({ token: "verification-token" });
    await user.click(screen.getByRole("link", { name: "Continue to log in" }));
    expect(screen.getByRole("heading", { level: 1 }).textContent).toBe("Welcome back.");
  });

  it("offers recovery for a missing reset token without submitting", async () => {
    const user = userEvent.setup();
    renderApp("/reset");

    expect(screen.getByRole("alert").textContent).toContain("reset link is missing or invalid");
    expect(screen.queryByLabelText("New password", { exact: true })).toBeNull();
    await user.click(screen.getByRole("link", { name: "Request a reset link" }));
    expect(screen.getByRole("heading", { level: 1 }).textContent).toBe("Forgot your password?");
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("lets a user without a verification token request a fresh link", async () => {
    const user = userEvent.setup();
    fetchMock.mockResolvedValueOnce(jsonResponse({ ok: true }));
    renderApp("/verify");

    expect(screen.queryByRole("button", { name: "Verify my email" })).toBeNull();
    await user.type(screen.getByLabelText("Email address"), "ETHAN@EXAMPLE.COM");
    await user.click(screen.getByRole("button", { name: "Resend verification link" }));
    expect((await screen.findByRole("status")).textContent).toContain("If this address has an unverified account");
    expect(String(fetchMock.mock.calls[0]?.[0])).toBe("/api/auth/resend-verification");
    expect(JSON.parse(String(fetchMock.mock.calls[0]?.[1]?.body))).toEqual({ email: "ethan@example.com" });
  });

  it("shows a generic recovery confirmation without disclosing whether the email exists", async () => {
    const user = userEvent.setup();
    fetchMock.mockResolvedValueOnce(jsonResponse({ ok: true }));
    renderApp("/forgot-password");
    await user.type(screen.getByLabelText("Email address"), "unknown@example.com");
    await user.click(screen.getByRole("button", { name: "Send reset link" }));

    expect(await screen.findByRole("heading", { level: 1, name: "Check your inbox." })).not.toBeNull();
    expect(screen.getByText("If an account exists for that email, a password reset link is on its way.")).not.toBeNull();
    expect(String(fetchMock.mock.calls[0]?.[0])).toBe("/api/auth/forgot-password");
    expect(JSON.parse(String(fetchMock.mock.calls[0]?.[1]?.body))).toEqual({ email: "unknown@example.com" });
  });
});
