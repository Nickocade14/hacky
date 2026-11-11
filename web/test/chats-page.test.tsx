import { afterEach, beforeEach, expect, it, vi } from "vitest";
import { act, cleanup, render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter } from "react-router-dom";
import { App } from "../src/App";
import { clearSession, saveSession } from "../src/lib/session";
import type { Me } from "../src/lib/contracts";
import type { components } from "../src/lib/schema";

type Message = components["schemas"]["Message"];
type SendMessageBody = components["schemas"]["SendMessageBody"];
const userId = "000000000000000000000001";
const peerId = "000000000000000000000002";
const threadId = "000000000000000000000003";
const firstId = "000000000000000000000004";
const initialId = "000000000000000000000005";
const replyId = "000000000000000000000006";
const sentId = "000000000000000000000007";
const eventSlug = "knighthacks-ix";
const createdAt = "2026-10-24T22:00:00.000Z";
const messagesPath = "/api/conversations/" + threadId + "/messages";

const me: Me = {
  profile: { userId, name: "Ethan", handle: "ethan", hackyStyle: {}, photoUrl: null, bio: null, links: {}, isDemo: false },
  events: [{ slug: eventSlug, name: "Knight Hacks IX", role: "hacker", verified: false }],
};

function message(id: string, body: string, senderId = peerId, clientId: string | null = null): Message {
  return { id, conversationId: threadId, senderId, clientId, body, kind: "text", createdAt };
}

const initial = message(initialId, "Want to work on a project?");
const conversation: components["schemas"]["ConversationSummary"] = {
  id: threadId,
  kind: "dm",
  peer: { userId: peerId, name: "Maya", handle: "maya", hackyStyle: {}, photoUrl: null, role: "hacker" },
  team: null,
  helpRequest: null,
  lastMessage: initial,
  lastMessageAt: createdAt,
  unreadCount: 1,
  peerLastReadAt: null,
  createdAt,
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
const fetchMock = vi.fn<typeof fetch>();
let postCount = 0;
let poll: (() => Promise<void>) | undefined;
let sent: Message | undefined;

beforeEach(() => {
  window.localStorage.clear();
  clearSession();
  saveSession({ token: "test-jwt", expiresAt: new Date(Date.now() + 60_000).toISOString() });
  postCount = 0;
  sent = undefined;
  poll = undefined;
  const startTimer = window.setInterval.bind(window);
  vi.spyOn(window, "setInterval").mockImplementation((handler, timeout, ...args) => {
    if (timeout === 10_000 && typeof handler === "function") {
      poll = handler as () => Promise<void>;
      return startTimer(() => {}, timeout);
    }
    return startTimer(handler, timeout, ...args);
  });
  fetchMock.mockReset();
  fetchMock.mockImplementation(async (url, init) => {
    const path = String(url);
    if (path === "/api/me") return json(me);
    if (path === "/api/events/" + eventSlug + "/conversations") return json({ conversations: [conversation] });
    if (path === "/api/conversations/" + threadId + "/read" && init?.method === "POST") return json({ lastReadAt: createdAt });
    if (path === messagesPath + "?before=" + initialId) return json({ messages: [message(firstId, "Hi Ethan")], hasMore: false });
    if (path === messagesPath + "?after=" + initialId + "&limit=100") {
      return json({ messages: [message(replyId, "I can work on React."), sent], hasMore: false });
    }
    if (path === messagesPath + "/" + sentId && init?.method === "DELETE") return json({ error: { code: "not_found", message: "Already gone." } }, 404);
    if (path === messagesPath && init?.method === "POST") {
      const body: SendMessageBody = JSON.parse(String(init.body));
      postCount += 1;
      if (postCount === 1) return json({ error: { code: "internal", message: "Try again." } }, 500);
      sent = message(sentId, body.body, userId, body.clientId);
      return json({ message: sent }, 201);
    }
    if (path === messagesPath) return json({ messages: [initial], hasMore: true });
    throw new Error("Unexpected API call in this test: " + path);
  });
  vi.stubGlobal("fetch", fetchMock);
});

afterEach(() => {
  cleanup();
  clearSession();
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

it("loads a conversation, retries with the same client ID, polls from the last listed message and unsends", async () => {
  const user = userEvent.setup();
  render(<MemoryRouter initialEntries={["/chats"]}><App /></MemoryRouter>);
  const link = await screen.findByRole("link", { name: /Maya/ });
  expect(link.getAttribute("href")).toBe("/chats/" + threadId + "?event=" + eventSlug);
  await user.click(link);
  expect(await screen.findByText(initial.body)).not.toBeNull();
  await waitFor(() => expect(fetchMock.mock.calls.some(([path, init]) => String(path).endsWith("/read") && init?.method === "POST")).toBe(true));

  await user.click(screen.getByRole("button", { name: "Load earlier messages" }));
  expect(await screen.findByText("Hi Ethan")).not.toBeNull();

  await user.type(screen.getByLabelText("Message"), "Sounds good!");
  await user.click(screen.getByRole("button", { name: "Send", exact: true }));
  await user.click(await screen.findByRole("button", { name: "Retry", exact: true }));
  await screen.findByRole("button", { name: "Unsend", exact: true });
  const sends = fetchMock.mock.calls.filter(([path, init]) => String(path) === messagesPath && init?.method === "POST");
  expect(sends).toHaveLength(2);
  expect(sends[1]?.[1]?.body).toBe(sends[0]?.[1]?.body);
  expect(sends[1]?.[1]?.headers).toBeInstanceOf(Headers);
  expect((sends[1]?.[1]?.headers as Headers).get("Authorization")).toBe("Bearer test-jwt");

  // The send response has a later ID than the peer reply. Poll from the last
  // message list cursor so the peer reply still arrives and my copy dedupes.
  expect(poll).toBeDefined();
  await act(async () => { await poll?.(); });
  expect(screen.getByText("I can work on React.")).not.toBeNull();
  expect(screen.getAllByText("Sounds good!")).toHaveLength(1);

  await user.click(screen.getByRole("button", { name: "Unsend", exact: true }));
  await user.click(screen.getByRole("button", { name: "Unsend for everyone" }));
  await waitFor(() => expect(screen.queryByText("Sounds good!")).toBeNull());
});
