import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { cleanup, render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter, Outlet, Route, Routes, useLocation } from "react-router-dom";
import { PersonProfilePage } from "../src/PersonProfilePage";
import { RequestsPage } from "../src/RequestsPage";
import { SearchPage } from "../src/SearchPage";
import type { SignedInContext } from "../src/SignedInShell";
import type { ConnectionRequest, PersonDetail } from "../src/lib/connections";
import { clearSession, saveSession } from "../src/lib/session";

const event = { slug: "knighthacks-ix", name: "Knight Hacks IX", role: "hacker", verified: false } as const;
const person: PersonDetail = {
  userId: "191915a6d127f8637ee63a88",
  name: "Maya Patel",
  handle: "maya_ml",
  role: "hacker",
  verified: false,
  photoUrl: null,
  bio: "I build accessibility tools.",
  hackyStyle: {},
  links: {},
  isDemo: false,
  availability: "available",
  looking: true,
  skills: ["React"],
  skillsWanted: ["TypeScript"],
  track: null,
  idea: null,
  interests: [],
  summary: null,
  experience: null,
  goal: null,
  motivations: [],
  relation: { state: "none", requestId: null, conversationId: null },
};
const context = {
  me: {
    profile: { userId: "6717a3f2c9e1b04d2a5e8f10", name: "Ethan Zeng", handle: "ethan_z", photoUrl: null, bio: null, hackyStyle: {}, links: {}, isDemo: false },
    events: [event],
  },
  event,
  selectEvent: vi.fn(),
  onJoined: vi.fn(),
  onProfileChanged: vi.fn(),
  onExpired: vi.fn(),
};
const request: ConnectionRequest = {
  id: "191915a6d127f8637ee63a87",
  direction: "incoming",
  status: "pending",
  source: "profile",
  intro: "Want to build an accessibility tool?",
  person,
  team: null,
  conversationId: null,
  createdAt: "2026-11-11T14:00:00Z",
  respondedAt: null,
};
const conversationId = "191915a6d127f8637ee63a86";
const fetchMock = vi.fn<typeof fetch>();
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

function ConversationStub() {
  const location = useLocation();
  return <h1>{location.pathname + location.search}</h1>;
}

function renderAt(path: string) {
  return render(<MemoryRouter initialEntries={[path]}>
    <Routes>
      <Route element={<Outlet context={context satisfies SignedInContext} />}>
        <Route path="/search" element={<SearchPage />} />
        <Route path="/people/:handle" element={<PersonProfilePage />} />
        <Route path="/requests" element={<RequestsPage />} />
        <Route path="/chats/:conversationId" element={<ConversationStub />} />
      </Route>
    </Routes>
  </MemoryRouter>);
}

beforeEach(() => {
  fetchMock.mockReset();
  vi.stubGlobal("fetch", fetchMock);
  saveSession({ token: "test-token", expiresAt: new Date(Date.now() + 60_000).toISOString(), me: context.me });
});

afterEach(() => {
  cleanup();
  clearSession();
  vi.unstubAllGlobals();
});

describe("event connections", () => {
  it("opens a search match in its event and sends a profile request", async () => {
    fetchMock.mockResolvedValueOnce(json({ results: [{ ...person, matchedSkills: [] }] }));
    fetchMock.mockResolvedValueOnce(json(person));
    fetchMock.mockResolvedValueOnce(json({ request: { ...request, direction: "outgoing" } }, 201));
    const user = userEvent.setup();
    renderAt("/search");

    await user.type(screen.getByRole("searchbox"), "may");
    const match = await screen.findByRole("link", { name: /Maya Patel/i });
    expect(match.getAttribute("href")).toBe("/people/maya_ml?event=knighthacks-ix");
    expect(match.querySelector("mark")?.textContent).toBe("May");
    await user.click(match);
    await user.click(await screen.findByRole("button", { name: "Connect with Maya" }));
    await user.type(screen.getByLabelText("Say why you’d like to connect"), "Let’s work together!");
    await user.click(screen.getByRole("button", { name: "Send request" }));

    expect(await screen.findByText(/Waiting for Maya to accept/)).not.toBeNull();
    const [path, options] = fetchMock.mock.calls[2]!;
    expect(path).toBe("/api/events/knighthacks-ix/requests");
    expect(new Headers(options?.headers).get("Authorization")).toBe("Bearer test-token");
    expect(JSON.parse(String(options?.body))).toEqual({
      toUserId: person.userId, intro: "Let’s work together!", source: "profile",
    });
  });

  it("can accept a hidden incoming request and opens its event conversation", async () => {
    fetchMock.mockResolvedValueOnce(json({ requests: [request] }));
    fetchMock.mockResolvedValueOnce(json({ ok: true }));
    fetchMock.mockResolvedValueOnce(json({ request: { ...request, status: "accepted", conversationId } }));
    const user = userEvent.setup();
    renderAt("/requests");

    await user.click(await screen.findByRole("button", { name: "Not now" }));
    expect(await screen.findByText("No incoming requests.")).not.toBeNull();
    await user.click(screen.getByText("Hidden (1)"));
    const hidden = screen.getByText("Hidden (1)").parentElement!;
    expect(within(hidden).queryByRole("button", { name: "Not now" })).toBeNull();
    await user.click(within(hidden).getByRole("button", { name: "Accept" }));

    expect(await screen.findByRole("heading", { name: "/chats/" + conversationId + "?event=knighthacks-ix" })).not.toBeNull();
    expect(fetchMock.mock.calls.map(([url, options]) => [url, options?.method])).toEqual([
      ["/api/events/knighthacks-ix/requests", "GET"],
      ["/api/requests/" + request.id + "/hide", "POST"],
      ["/api/requests/" + request.id + "/accept", "POST"],
    ]);
  });
});
