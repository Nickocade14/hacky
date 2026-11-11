import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { cleanup, render, screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter } from "react-router-dom";
import { App } from "../src/App";
import { clearSession, saveSession } from "../src/lib/session";
import type { ChatMessage, LoginResult, Me } from "../src/lib/contracts";
import { introProblem, partsOf, shownSkills, whyLine } from "../src/lib/hacky";

const fetchMock = vi.fn<typeof fetch>();

const me: Me = {
  profile: { userId: "6717a3f2c9e1b04d2a5e8f10", handle: "ethan_z", name: "Ethan Zeng", hackyStyle: {}, photoUrl: null, bio: null, links: {}, isDemo: false },
  events: [{ slug: "knighthacks-ix", name: "Knight Hacks IX", role: "hacker", verified: false }],
};

const session = (): LoginResult => ({ token: "test-jwt", expiresAt: new Date(Date.now() + 60_000).toISOString(), me });

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

const owen = {
  card: "person",
  person: { userId: "191915a6d127f8637ee63a88", handle: "owen_react", name: "Owen Castellano", hackyStyle: {}, photoUrl: null, role: "hacker" },
  skills: ["TypeScript", "Tailwind CSS", "React", "Next.js"],
  evidence: { matchedSkills: ["React"] },
  reason: "Intermediate frontend dev who builds with React and Next.js.",
};

const answer = (id: string, cards: unknown[] = [owen], kind = "hacker"): ChatMessage => ({
  id: `reply-${id}`,
  role: "assistant",
  parts: [
    { type: "text", text: "Here are some **strong** React teammates." },
    { type: "tool-search_people", toolCallId: "call-1", state: "output-available", input: { query: "x" }, output: { status: "matches", kind, cards } },
  ],
});

// Each test sets what the chat endpoints answer.
let history: ChatMessage[] = [];
let reply: (body: { message: ChatMessage }) => Response = (body) => json({ message: answer(body.message.id) });
let requestReply: () => Response = () => json({ request: { status: "pending" } }, 201);
let savedRequests: unknown[] = [];

function renderHacky() {
  saveSession(session());
  return render(<MemoryRouter initialEntries={["/hacky"]}><App /></MemoryRouter>);
}

const sends = () => fetchMock.mock.calls.filter(([url, init]) => String(url).includes("/chat?format=json") && init?.method === "POST");

beforeEach(() => {
  window.localStorage.clear();
  clearSession();
  history = [];
  reply = (body) => json({ message: answer(body.message.id) });
  requestReply = () => json({ request: { status: "pending" } }, 201);
  savedRequests = [];
  fetchMock.mockReset();
  fetchMock.mockImplementation(async (url, init) => {
    const path = String(url);
    if (path === "/api/me") return json(me);
    if (path === "/api/events/knighthacks-ix/chat" && init?.method === "GET") return json({ messages: history });
    if (path === "/api/events/knighthacks-ix/chat?format=json") return reply(JSON.parse(String(init?.body)));
    if (path === "/api/events/knighthacks-ix/requests") {
      return init?.method === "POST" ? requestReply() : json({ requests: savedRequests });
    }
    throw new Error(`Unexpected API call in this test: ${path}`);
  });
  vi.stubGlobal("fetch", fetchMock);
});

afterEach(() => {
  cleanup();
  clearSession();
  vi.unstubAllGlobals();
});

describe("Hacky chat page", () => {
  it("greets me with suggestions, and a suggestion asks Hacky and shows the cards", async () => {
    const user = userEvent.setup();
    renderHacky();

    expect(await screen.findByRole("heading", { name: "Hi Ethan!" })).not.toBeNull();
    expect(screen.getByRole("link", { name: /Hacky/, current: "page" })).not.toBeNull();
    await user.click(screen.getByRole("button", { name: "Find a teammate who knows React" }));

    const card = await screen.findByRole("article", { name: "Owen Castellano" });
    expect(within(card).getByText("@owen_react · Hacker")).not.toBeNull();
    expect(within(card).getByText("Intermediate frontend dev who builds with React and Next.js.")).not.toBeNull();
    // The skill I asked for comes first and is highlighted.
    const skills = within(card).getAllByRole("listitem").map((item) => [item.textContent, item.className]);
    expect(skills).toEqual([["React", "matched"], ["TypeScript", ""], ["Tailwind CSS", ""]]);
    expect(screen.getByText("strong").tagName).toBe("STRONG");
    expect(screen.getByText("Find a teammate who knows React")).not.toBeNull();

    const [, init] = sends()[0]!;
    const body = JSON.parse(String(init?.body));
    expect(body.message.role).toBe("user");
    expect(body.message.id).toMatch(/^[A-Za-z0-9_-]{1,100}$/);
    expect(body.message.parts).toEqual([{ type: "text", text: "Find a teammate who knows React" }]);
    expect(init?.headers instanceof Headers ? init.headers.get("Authorization") : null).toBe("Bearer test-jwt");
  });

  it("loads the saved history and sends what I type", async () => {
    const user = userEvent.setup();
    history = [
      { id: "web-1", role: "user", parts: [{ type: "text", text: "Find a mentor" }] },
      answer("web-1", [{ ...owen, card: "mentor", verified: true, evidence: { matchedSkills: [], availability: "available" }, person: { ...owen.person, role: "mentor" } }], "mentor"),
    ];
    renderHacky();

    expect(await screen.findByText("Hi Ethan! What are you building, and who do you need?")).not.toBeNull();
    expect(screen.getByText("@owen_react · Mentor · Verified")).not.toBeNull();
    expect(screen.getByText("1 mentor")).not.toBeNull();

    await user.type(screen.getByLabelText("Message Hacky"), "  Who knows Flutter?  {Enter}");
    await waitFor(() => expect(sends()).toHaveLength(1));
    expect(JSON.parse(String(sends()[0]![1]?.body)).message.parts[0].text).toBe("Who knows Flutter?");
    expect((screen.getByLabelText("Message Hacky") as HTMLInputElement).value).toBe("");
    expect(await screen.findAllByRole("article", { name: "Owen Castellano" })).toHaveLength(2);
  });

  it("keeps a failed message with the server's reason and retries it with the same id", async () => {
    const user = userEvent.setup();
    reply = () => json({ error: { code: "ai_unavailable", message: "Hacky is offline right now. Please try again later." } }, 503);
    renderHacky();

    await user.click(await screen.findByRole("button", { name: "Find a mentor" }));
    expect((await screen.findByRole("alert")).textContent).toContain("Not sent. Hacky is offline right now.");

    reply = (body) => json({ message: answer(body.message.id) });
    await user.click(screen.getByRole("button", { name: "Retry" }));
    expect(await screen.findByRole("article", { name: "Owen Castellano" })).not.toBeNull();
    expect(screen.queryByRole("alert")).toBeNull();
    const ids = sends().map(([, init]) => JSON.parse(String(init?.body)).message.id);
    expect(ids).toHaveLength(2);
    expect(ids[1]).toBe(ids[0]);
  });

  it("sends a connection request from a card with an editable intro", async () => {
    const user = userEvent.setup();
    history = [{ id: "web-1", role: "user", parts: [{ type: "text", text: "React?" }] }, answer("web-1")];
    renderHacky();

    const card = await screen.findByRole("article", { name: "Owen Castellano" });
    await user.click(within(card).getByRole("button", { name: "Connect" }));
    const intro = within(card).getByLabelText("Intro for Owen") as HTMLTextAreaElement;
    expect(intro.value).toBe("Hi Owen! I’m Ethan. Hacky thought we could team up. Want to chat?");

    await user.clear(intro);
    await user.type(intro, "see www.example.com");
    await user.click(within(card).getByRole("button", { name: "Send request" }));
    expect(within(card).getByRole("alert").textContent).toBe("Intros can’t contain links.");
    expect(fetchMock.mock.calls.some(([url, init]) => String(url).endsWith("/requests") && init?.method === "POST")).toBe(false);

    await user.clear(intro);
    await user.type(intro, "Hi Owen, want to build something?");
    await user.click(within(card).getByRole("button", { name: "Send request" }));
    expect((await within(card).findByRole("link", { name: "View requests" })).getAttribute("href")).toBe("/requests?event=knighthacks-ix");
    const call = fetchMock.mock.calls.find(([url, init]) => String(url).endsWith("/requests") && init?.method === "POST")!;
    expect(JSON.parse(String(call[1]?.body))).toEqual({ toUserId: owen.person.userId, intro: "Hi Owen, want to build something?", source: "agent" });
    expect(within(card).queryByRole("button", { name: "Connect" })).toBeNull();
  });

  it("links a recommendation to the person's profile and an existing chat", async () => {
    history = [answer("web-1")];
    savedRequests = [{ direction: "outgoing", status: "accepted", person: owen.person, team: null, conversationId: "1234" }];
    renderHacky();

    const card = await screen.findByRole("article", { name: "Owen Castellano" });
    expect(within(card).getByRole("link", { name: "Owen Castellano" }).getAttribute("href")).toBe("/people/owen_react?event=knighthacks-ix");
    expect((await within(card).findByRole("link", { name: "Open chat" })).getAttribute("href")).toBe("/chats/1234?event=knighthacks-ix");
  });

  it("asks me to join an event when I'm not in one", async () => {
    fetchMock.mockImplementation(async (url) => {
      if (String(url) === "/api/me") return json({ ...me, events: [] });
      throw new Error(`Unexpected API call: ${String(url)}`);
    });
    saveSession(session());
    render(<MemoryRouter initialEntries={["/hacky"]}><App /></MemoryRouter>);
    expect(await screen.findByRole("heading", { name: "Join an event first" })).not.toBeNull();
    expect(screen.getByRole("link", { name: "Go to Home" }).getAttribute("href")).toBe("/app");
  });
});

describe("reading Hacky's parts", () => {
  it("keeps text and valid cards, and skips anything it can't show", () => {
    const parts = partsOf({
      id: "reply-1", role: "assistant",
      parts: [
        { type: "text", text: "  " },
        { type: "step-start" },
        { type: "tool-search_people", output: { kind: "hacker", cards: [owen, { card: "person", person: { name: "No id" } }] } },
        { type: "text", text: "Done." },
      ],
    });
    expect(parts.map((part) => part.type)).toEqual(["cards", "text"]);
    expect(parts[0]!.type === "cards" && parts[0]!.cards.map((card) => card.person.handle)).toEqual(["owen_react"]);
  });

  it("explains the pick and checks intros like mobile", () => {
    const [text, cards] = partsOf(answer("x"));
    expect(text!.type).toBe("text");
    if (cards?.type !== "cards") throw new Error("expected cards");
    const card = cards.cards[0]!;
    expect(whyLine({ ...card, reason: "" })).toBe("Knows React.");
    expect(whyLine(card)).toBe(owen.reason);
    expect(shownSkills(card)[0]).toBe("React");
    expect(introProblem("   ")).toBe("Write a short intro first.");
    expect(introProblem("x".repeat(501))).toBe("Keep it under 500 characters.");
    expect(introProblem("Hi there")).toBeNull();
  });
});
