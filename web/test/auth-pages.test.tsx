import { StrictMode } from "react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { act, cleanup, render, screen, waitFor, within } from "@testing-library/react";
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

async function fillRegistration(user: ReturnType<typeof userEvent.setup>) {
  await user.type(screen.getByLabelText("Your name"), "Ethan Zeng");
  await user.type(screen.getByLabelText("Username"), "ethan_z");
  await user.type(screen.getByLabelText("Email address"), "ETHAN@EXAMPLE.COM");
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
    expect(screen.getByLabelText("Username")).not.toBeNull();

    await user.click(within(screen.getByRole("navigation", { name: "Account" })).getByRole("link", { name: "Log in" }));
    await user.click(screen.getByRole("link", { name: "Forgot password?" }));
    expect(screen.getByRole("heading", { level: 1 }).textContent).toBe("Forgot your password?");
    await user.click(screen.getByRole("link", { name: "Back to log in" }));
    expect(screen.getByRole("heading", { level: 1 }).textContent).toBe("Welcome back.");
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("registers with the required handle and normalized email, then shows inbox instructions", async () => {
    const user = userEvent.setup();
    fetchMock.mockResolvedValueOnce(jsonResponse({ ok: true }));
    renderApp("/register");

    await fillRegistration(user);
    await user.click(screen.getByRole("button", { name: "Create account" }));

    expect(await screen.findByRole("heading", { level: 1, name: "Check your inbox." })).not.toBeNull();
    expect(screen.getByText("ethan@example.com", { exact: true })).not.toBeNull();
    expect(screen.getByLabelText("Code")).not.toBeNull();
    expect(fetchMock).toHaveBeenCalledTimes(1);
    const [url, options] = fetchMock.mock.calls[0]!;
    expect(String(url)).toBe("/api/auth/register");
    expect(options?.method).toBe("POST");
    expect(JSON.parse(String(options?.body))).toEqual({ name: "Ethan Zeng", handle: "ethan_z", email: "ethan@example.com", password: "correct-password" });
    expect(readSession()).toBeNull();
  });

  it("offers link instructions and resend when registration returns 201", async () => {
    const user = userEvent.setup();
    fetchMock.mockResolvedValueOnce(jsonResponse({ ok: true }, 201)).mockResolvedValueOnce(jsonResponse({ ok: true }));
    renderApp("/register");
    await fillRegistration(user);
    await user.click(screen.getByRole("button", { name: "Create account" }));

    expect(await screen.findByText(/Open the verification link emailed to/)).not.toBeNull();
    expect(screen.queryByLabelText("Code")).toBeNull();
    await user.click(screen.getByRole("button", { name: "Send a new email" }));
    expect((await screen.findByRole("status")).textContent).toContain("If your sign-up is still active");
    expect(String(fetchMock.mock.calls[1]?.[0])).toBe("/api/auth/resend-verification");
    expect(JSON.parse(String(fetchMock.mock.calls[1]?.[1]?.body))).toEqual({ email: "ethan@example.com" });
  });

  it("keeps a legacy unverified user signed out and offers password recovery", async () => {
    const user = userEvent.setup();
    fetchMock.mockResolvedValueOnce(jsonResponse({ error: { code: "email_not_verified", message: "Check your inbox before logging in." } }, 403));
    renderApp("/login");
    await fillLogin(user);
    await user.click(screen.getByRole("button", { name: "Log in" }));

    expect((await screen.findByRole("alert")).textContent).toBe("Check your inbox before logging in.");
    expect(readSession()).toBeNull();
    await user.click(screen.getByRole("link", { name: "Forgot password?" }));
    expect(screen.getByRole("button", { name: "Send email" })).not.toBeNull();
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

  it("searches the current event with the saved token and drops stale results", async () => {
    const user = userEvent.setup();
    const session = loginResult();
    saveSession(session);
    const person = {
      userId: "6717a3f2c9e1b04d2a5e8f11", handle: "go_mentor", name: "Go Mentor", role: "mentor",
      skills: ["Go"], matchedSkills: ["Go"], photoUrl: null, hackyStyle: {},
    };
    let finishFirst!: (response: Response) => void;
    fetchMock.mockResolvedValueOnce(jsonResponse(session.me));
    fetchMock.mockReturnValueOnce(new Promise<Response>((resolve) => { finishFirst = resolve; }));
    fetchMock.mockResolvedValueOnce(jsonResponse({ results: [person] }));
    renderApp("/search");

    const input = await screen.findByRole("searchbox", { name: "Name, handle, or skill" });
    await user.type(input, "C++");
    await waitFor(() => expect(fetchMock).toHaveBeenCalledTimes(2));
    const [path, request] = fetchMock.mock.calls[1]!;
    expect(path).toBe("/api/search?event=knighthacks-ix&q=C%2B%2B");
    expect(new Headers(request?.headers).get("Authorization")).toBe(`Bearer ${session.token}`);

    await user.clear(input);
    await user.type(input, "Go");
    expect(await screen.findByRole("heading", { name: "Go Mentor" })).not.toBeNull();
    expect(request?.signal?.aborted).toBe(true);
    await act(async () => { finishFirst(jsonResponse({ results: [{ ...person, name: "Old Match" }] })); });
    expect(screen.queryByRole("heading", { name: "Old Match" })).toBeNull();
  });

  async function requestResetCode(user: ReturnType<typeof userEvent.setup>, email = "ethan@example.com") {
    await user.type(screen.getByLabelText("Email address"), email);
    await user.click(screen.getByRole("button", { name: "Send email" }));
    return screen.findByLabelText("Code");
  }

  it.each([
    { boundary: "seven Unicode code points", password: "🦄".repeat(7), message: "at least 8 characters" },
    { boundary: "73 UTF-8 bytes", password: `${"🦄".repeat(18)}a`, message: "at most 72 UTF-8 bytes" },
  ])("blocks a password with $boundary before calling reset", async ({ password, message }) => {
    const user = userEvent.setup();
    fetchMock.mockResolvedValueOnce(jsonResponse({ ok: true }));
    renderApp("/forgot-password");
    await user.type(await requestResetCode(user), "012345");
    await user.type(screen.getByLabelText("New password", { exact: true }), password);
    await user.click(screen.getByRole("button", { name: "Reset password" }));

    expect(screen.getByRole("alert").textContent).toContain(message);
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });

  it.each([
    { boundary: "eight Unicode code points", password: "🦄".repeat(8) },
    { boundary: "72 UTF-8 bytes", password: "🦄".repeat(18) },
  ])("accepts a password at the $boundary boundary and signs in after reset", async ({ password }) => {
    const user = userEvent.setup();
    const result = loginResult();
    fetchMock.mockResolvedValueOnce(jsonResponse({ ok: true })).mockResolvedValueOnce(jsonResponse(result));
    renderApp("/forgot-password");
    await user.type(await requestResetCode(user, "ETHAN@EXAMPLE.COM"), "012345");
    await user.type(screen.getByLabelText("New password", { exact: true }), password);
    await user.click(screen.getByRole("button", { name: "Reset password" }));

    expect(await screen.findByRole("heading", { level: 1, name: /Ethan/ })).not.toBeNull();
    expect(fetchMock).toHaveBeenCalledTimes(2);
    expect(String(fetchMock.mock.calls[1]?.[0])).toBe("/api/auth/reset-password");
    expect(JSON.parse(String(fetchMock.mock.calls[1]?.[1]?.body))).toEqual({ email: "ethan@example.com", code: "012345", password });
    expect(readSession()).toEqual({ token: result.token, expiresAt: result.expiresAt });
  });

  it("verifies only on submit and saves the returned session in StrictMode", async () => {
    const user = userEvent.setup();
    const result = loginResult();
    fetchMock.mockResolvedValueOnce(jsonResponse(result));
    renderApp("/verify", true);

    await user.type(screen.getByLabelText("Email address"), "ETHAN@EXAMPLE.COM");
    await user.type(screen.getByLabelText("Code"), "012345");
    expect(fetchMock).not.toHaveBeenCalled();
    await user.click(screen.getByRole("button", { name: "Verify and continue" }));

    expect(await screen.findByRole("heading", { level: 1, name: /Ethan/ })).not.toBeNull();
    expect(fetchMock).toHaveBeenCalledTimes(1);
    expect(String(fetchMock.mock.calls[0]?.[0])).toBe("/api/auth/verify-email");
    expect(JSON.parse(String(fetchMock.mock.calls[0]?.[1]?.body))).toEqual({ email: "ethan@example.com", code: "012345" });
    expect(readSession()).toEqual({ token: result.token, expiresAt: result.expiresAt });
  });

  it("keeps the server's invalid-code message and can resend without a code", async () => {
    const user = userEvent.setup();
    fetchMock.mockResolvedValueOnce(jsonResponse({ error: { code: "invalid_code", message: "This code has expired." } }, 400))
      .mockResolvedValueOnce(jsonResponse({ ok: true }));
    renderApp("/verify");
    await user.type(screen.getByLabelText("Email address"), "ETHAN@EXAMPLE.COM");
    const code = screen.getByLabelText<HTMLInputElement>("Code");
    await user.type(code, "12345");
    await user.click(screen.getByRole("button", { name: "Verify and continue" }));
    expect(screen.getByRole("alert").textContent).toBe("Enter the 6-digit code from the email.");
    expect(fetchMock).not.toHaveBeenCalled();

    await user.type(code, "6");
    await user.click(screen.getByRole("button", { name: "Verify and continue" }));
    expect((await screen.findByRole("alert")).textContent).toBe("This code has expired.");
    await user.clear(code);
    await user.click(screen.getByRole("button", { name: "Send a new code" }));
    expect((await screen.findByRole("status")).textContent).toContain("If your sign-up is still active");
    expect(screen.getByRole("link", { name: "Back to create account" })).not.toBeNull();
    expect(String(fetchMock.mock.calls[1]?.[0])).toBe("/api/auth/resend-verification");
    expect(JSON.parse(String(fetchMock.mock.calls[1]?.[1]?.body))).toEqual({ email: "ethan@example.com" });
  });

  it.each(["handle_taken", "email_taken"])("offers registration again when verification returns %s", async (errorCode) => {
    const user = userEvent.setup();
    const message = "Someone verified first. Try again.";
    fetchMock.mockResolvedValueOnce(jsonResponse({ error: { code: errorCode, message } }, 409));
    renderApp("/verify");
    await user.type(screen.getByLabelText("Email address"), "ethan@example.com");
    await user.type(screen.getByLabelText("Code"), "123456");
    await user.click(screen.getByRole("button", { name: "Verify and continue" }));

    expect((await screen.findByRole("alert")).textContent).toBe(message);
    await user.click(screen.getByRole("link", { name: "Back to create account" }));
    expect(screen.getByLabelText("Username")).not.toBeNull();
    expect(readSession()).toBeNull();
  });

  it("keeps recovery generic and can resend or use a different email", async () => {
    const user = userEvent.setup();
    fetchMock.mockResolvedValueOnce(jsonResponse({ ok: true }))
      .mockResolvedValueOnce(jsonResponse({ error: { code: "invalid_code", message: "This code is no longer valid." } }, 400))
      .mockResolvedValueOnce(jsonResponse({ ok: true }));
    renderApp("/forgot-password");
    const code = await requestResetCode(user, "unknown@example.com");
    expect(screen.getByRole("heading", { level: 1, name: "Check your inbox." })).not.toBeNull();
    expect(screen.getByText(/If an account exists for/)).not.toBeNull();
    await user.type(code, "123456");
    await user.type(screen.getByLabelText("New password", { exact: true }), "new-password");
    await user.click(screen.getByRole("button", { name: "Reset password" }));
    expect((await screen.findByRole("alert")).textContent).toBe("This code is no longer valid.");
    await user.click(screen.getByRole("button", { name: "Send a new code" }));
    expect(await screen.findByRole("status")).not.toBeNull();
    expect((code as HTMLInputElement).value).toBe("");
    expect(fetchMock.mock.calls.map(([url, init]) => [String(url), JSON.parse(String(init?.body))])).toEqual([
      ["/api/auth/forgot-password", { email: "unknown@example.com" }],
      ["/api/auth/reset-password", { email: "unknown@example.com", code: "123456", password: "new-password" }],
      ["/api/auth/forgot-password", { email: "unknown@example.com" }],
    ]);

    await user.click(screen.getByRole("button", { name: "Use a different email" }));
    expect(screen.getByLabelText("Email address")).not.toBeNull();
    expect(screen.queryByLabelText("Code")).toBeNull();
    expect(fetchMock).toHaveBeenCalledTimes(3);
  });

  it("verifies an email link on explicit submit and returns to login without a session", async () => {
    const user = userEvent.setup();
    fetchMock.mockResolvedValueOnce(jsonResponse({ ok: true }));
    renderApp("/verify?token=verify-link", true);
    expect(fetchMock).not.toHaveBeenCalled();
    await user.click(screen.getByRole("button", { name: "Verify my email" }));

    expect((await screen.findByRole("status")).textContent).toBe("Email verified. Log in to continue.");
    expect(fetchMock).toHaveBeenCalledTimes(1);
    expect(String(fetchMock.mock.calls[0]?.[0])).toBe("/api/auth/verify-email");
    expect(JSON.parse(String(fetchMock.mock.calls[0]?.[1]?.body))).toEqual({ token: "verify-link" });
    expect(readSession()).toBeNull();
  });

  it("resets a password from an emailed link and then clears the previous session", async () => {
    const user = userEvent.setup();
    saveSession(loginResult());
    fetchMock.mockResolvedValueOnce(jsonResponse({ ok: true }));
    renderApp("/reset?token=reset-link");

    await user.type(screen.getByLabelText("New password", { exact: true }), "new-password");
    const confirmation = screen.getByLabelText("Confirm password", { exact: true });
    await user.type(confirmation, "other-password");
    await user.click(screen.getByRole("button", { name: "Save new password" }));
    expect((await screen.findByRole("alert")).textContent).toContain("passwords don’t match");
    expect(fetchMock).not.toHaveBeenCalled();
    expect(readSession()).not.toBeNull();

    await user.clear(confirmation);
    await user.type(confirmation, "new-password");
    await user.click(screen.getByRole("button", { name: "Save new password" }));
    expect((await screen.findByRole("status")).textContent).toBe("Password updated. Log in with your new password.");
    expect(String(fetchMock.mock.calls[0]?.[0])).toBe("/api/auth/reset-password");
    expect(JSON.parse(String(fetchMock.mock.calls[0]?.[1]?.body))).toEqual({ token: "reset-link", password: "new-password" });
    expect(readSession()).toBeNull();
  });

  it("offers code recovery if a reset link is no longer accepted", async () => {
    const user = userEvent.setup();
    saveSession(loginResult());
    fetchMock.mockResolvedValueOnce(jsonResponse({ error: { code: "invalid_input", message: "Invalid input" } }, 400));
    renderApp("/reset?token=expired-link");
    await user.type(screen.getByLabelText("New password", { exact: true }), "new-password");
    await user.type(screen.getByLabelText("Confirm password", { exact: true }), "new-password");
    await user.click(screen.getByRole("button", { name: "Save new password" }));

    expect((await screen.findByRole("alert")).textContent).toBe("Invalid input");
    expect(readSession()).not.toBeNull();
    await user.click(screen.getByRole("link", { name: "Request a new email" }));
    expect(await screen.findByRole("heading", { level: 1, name: "Forgot your password?" })).not.toBeNull();
  });
});
