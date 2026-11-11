import { useCallback, useEffect, useRef, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { ChatThread, getConversations, isStatus, previewOf, titleOf, type Conversation } from "../ChatsPage";
import {
  acceptConnectionRequest, chatPath, eventPath, hideConnectionRequest, listConnectionRequests, personPath,
  type ConnectionRequest,
} from "../lib/connections";
import type { Me, MyEvent } from "../lib/contracts";
import { KnitAvatar } from "./KnitAvatar";
import { Icon } from "./icons";

// The Chats panel from mlhacky.com (seeko-codes/Hacky react/src/social/Lists.jsx):
// my event, the requests waiting on me or on them, then my conversations.
// Opening a conversation shows it here, so Hacky stays on screen beside it.

const refreshEvery = 5_000;
const roleNames: Record<string, string> = { hacker: "Hacker", mentor: "Mentor", sponsor: "Sponsor", organizer: "Organizer", judge: "Judge" };

export function RoleChip({ role }: { role: string }) {
  return <span className="hk-role" data-role={role}>{roleNames[role] ?? role}</span>;
}

type Inbox = { requests: ConnectionRequest[]; conversations: Conversation[] };

/** Requests and conversations for one event, refreshed while the tab is in view. */
export function useInbox(slug: string | undefined, onExpired: () => void) {
  const [inbox, setInbox] = useState<Inbox | null>(null);
  const [failed, setFailed] = useState(false);
  const [revision, setRevision] = useState(0);
  const reload = useCallback(() => setRevision(value => value + 1), []);

  useEffect(() => {
    setInbox(null);
    setFailed(false);
  }, [slug]);

  useEffect(() => {
    if (!slug) return;
    const controller = new AbortController();
    const { signal } = controller;
    let loading = false;
    async function load() {
      if (loading) return;
      loading = true;
      try {
        const [requests, list] = await Promise.all([listConnectionRequests(slug!, signal), getConversations(slug!, signal)]);
        if (signal.aborted) return;
        setInbox({ requests, conversations: list.conversations });
        setFailed(false);
      } catch (error) {
        if (signal.aborted) return;
        if (isStatus(error, 401)) onExpired();
        else setFailed(true);
      } finally {
        loading = false;
      }
    }
    void load();
    const timer = window.setInterval(() => {
      if (document.visibilityState !== "hidden") void load();
    }, refreshEvery);
    return () => { window.clearInterval(timer); controller.abort(); };
  }, [slug, revision, onExpired]);

  return { inbox, failed, reload };
}

/** What the Chats button should flag: requests for me to answer, plus unread messages. */
export function waitingCount(inbox: Inbox | null) {
  if (!inbox) return 0;
  return inbox.requests.filter(request => request.direction === "incoming" && request.status === "pending" && !request.hiddenAt).length
    + inbox.conversations.reduce((sum, conversation) => sum + conversation.unreadCount, 0);
}

function EventBadge({ event }: { event: MyEvent | undefined }) {
  if (!event) return <div className="hk-event"><span>No hackathon yet<br /><small><Link to="/app">Pick yours on Home</Link></small></span></div>;
  const role = (roleNames[event.role] ?? event.role).toLowerCase();
  const initials = event.name.split(/\s+/).slice(0, 2).map(word => Array.from(word)[0]).join("").toUpperCase();
  return <div className="hk-event">
    <span className="hk-event-initials" aria-hidden="true">{initials}</span>
    <span className="hk-event-divider" />
    <span>{event.name}<br /><small>You’re here as a {role}{event.verified && event.role !== "hacker" ? " · Verified" : ""}</small></span>
  </div>;
}

function RequestRow({ request, slug, onChanged, onExpired }: { request: ConnectionRequest; slug: string; onChanged: () => void; onExpired: () => void }) {
  const navigate = useNavigate();
  const [busy, setBusy] = useState(false);
  const [problem, setProblem] = useState("");
  const alive = useRef(true);
  useEffect(() => { alive.current = true; return () => { alive.current = false; }; }, []);
  const incoming = request.direction === "incoming";
  const { person } = request;

  async function run(action: () => Promise<void>) {
    if (busy) return;
    setBusy(true);
    setProblem("");
    try {
      await action();
    } catch (error) {
      if (isStatus(error, 401)) onExpired();
      else if (alive.current) setProblem(error instanceof Error ? error.message : "That didn’t work. Try again.");
    } finally {
      if (alive.current) setBusy(false);
    }
  }

  return <li className="hk-contact hk-request">
    <Link className="hk-contact-avatar" to={personPath(person.handle, slug)} state={{ from: "/requests" }} aria-label={`View ${person.name}’s profile`}>
      <KnitAvatar person={person} size={44} />
    </Link>
    <div className="hk-contact-info">
      <span className="hk-contact-name">{person.name}</span>
      <span className="hk-tags">
        <RoleChip role={person.role} />
        {request.team && <span className="hk-tag">Team {request.team.name}</span>}
        {!incoming && <span className="hk-tag pending">Pending</span>}
      </span>
      {request.intro && <p className="hk-request-intro">{request.intro}</p>}
      {incoming && <span className="hk-request-actions">
        <button type="button" className="hk-button" disabled={busy} onClick={() => void run(async () => {
          const { request: accepted } = await acceptConnectionRequest(request.id);
          onChanged();
          if (accepted.conversationId) navigate(chatPath(accepted.conversationId, slug));
        })}>Accept</button>
        <button type="button" className="hk-button secondary" disabled={busy} onClick={() => void run(async () => {
          await hideConnectionRequest(request.id);
          onChanged();
        })}>Not now</button>
      </span>}
      {problem && <span className="hk-contact-problem" role="alert">{problem}</span>}
    </div>
  </li>;
}

function ChatRow({ conversation, slug, userId }: { conversation: Conversation; slug: string; userId: string }) {
  const title = titleOf(conversation);
  const unread = conversation.unreadCount;
  return <li>
    <Link className="hk-contact hk-chat-row" to={chatPath(conversation.id, slug)}>
      {conversation.peer
        ? <KnitAvatar person={conversation.peer} size={44} />
        : <span className="hk-team-avatar" aria-hidden="true">
          <KnitAvatar person={{ name: title, userId: conversation.id + "a" }} size={29} />
          <KnitAvatar person={{ name: title, userId: conversation.id + "b" }} size={29} />
        </span>}
      <span className="hk-contact-info">
        <span className="hk-contact-name">{title}</span>
        <span className="hk-tags">
          {conversation.peer ? <RoleChip role={conversation.peer.role} /> : <span className="hk-tag">Team chat</span>}
          {conversation.helpRequest && <span className="hk-tag">{conversation.helpRequest.title}</span>}
        </span>
        <span className={unread ? "hk-preview unread" : "hk-preview"}>{previewOf(conversation, userId)}</span>
      </span>
      {unread > 0 && <span className="hk-unread">{unread > 99 ? "99+" : unread}<span className="visually-hidden"> unread</span></span>}
    </Link>
  </li>;
}

type SidebarProps = {
  me: Me;
  event: MyEvent | undefined;
  threadId: string | undefined;
  inbox: Inbox | null;
  failed: boolean;
  reload: () => void;
  onClose: () => void;
  onExpired: () => void;
  signOut: () => void;
};

export function Sidebar({ me, event, threadId, inbox, failed, reload, onClose, onExpired, signOut }: SidebarProps) {
  const slug = event?.slug;
  const userId = me.profile.userId;
  const pending = inbox?.requests.filter(request => request.status === "pending") ?? [];
  const waiting = pending.filter(request => request.direction === "incoming" && !request.hiddenAt);
  const sent = pending.filter(request => request.direction === "outgoing");
  const hidden = pending.filter(request => request.direction === "incoming" && request.hiddenAt).length;
  const thread = threadId ? inbox?.conversations.find(conversation => conversation.id === threadId) : undefined;

  if (slug && threadId) {
    return <div className="hk-side-inner in-thread">
      <div className="hk-thread-bar">
        <Link className="hk-icon" to={eventPath("/chats", slug)} aria-label="Back to chats"><Icon name="back" /></Link>
        {thread?.peer && <RoleChip role={thread.peer.role} />}
        {thread && !thread.peer && <span className="hk-tag">Team chat</span>}
        <button type="button" className="hk-icon hk-thread-close" onClick={onClose} aria-label="Close chats"><Icon name="close" /></button>
      </div>
      <ChatThread key={slug + ":" + threadId} id={threadId} slug={slug} userId={userId} onExpired={onExpired} embedded />
    </div>;
  }

  return <div className="hk-side-inner">
    <div className="hk-side-header">
      <h2>Chats</h2>
      <button type="button" className="hk-icon" onClick={onClose} aria-label="Close chats"><Icon name="close" /></button>
    </div>
    <EventBadge event={event} />
    <div className="hk-contacts">
      {!slug && <p className="hk-side-empty">Join a hackathon and your requests and chats show up here.</p>}
      {slug && !inbox && !failed && <p className="hk-side-empty" role="status">Loading your chats…</p>}
      {slug && !inbox && failed && <p className="hk-side-empty" role="alert">
        Couldn’t load your chats. <button type="button" className="hk-text-button" onClick={reload}>Try again</button>
      </p>}
      {slug && inbox && <>
        <div className="hk-label-row">
          <h3 className="hk-label">Requests</h3>
          <Link className="hk-label-link" to={eventPath("/requests", slug)}>{hidden ? `See all · ${hidden} hidden` : "See all"}</Link>
        </div>
        {waiting.length + sent.length === 0
          ? <p className="hk-side-empty slim">Nothing waiting. Ask Hacky to find someone and send a request.</p>
          : <ul className="hk-list">
            {[...waiting, ...sent].map(request => <RequestRow key={request.id} request={request} slug={slug} onChanged={reload} onExpired={onExpired} />)}
          </ul>}
        <h3 className="hk-label chats">Chats</h3>
        {inbox.conversations.length === 0
          ? <p className="hk-side-empty slim">No chats yet. They start when a request is accepted.</p>
          : <ul className="hk-list">
            {inbox.conversations.map(conversation => <ChatRow key={conversation.id} conversation={conversation} slug={slug} userId={userId} />)}
          </ul>}
      </>}
    </div>
    <div className="hk-side-foot">
      <span>@{me.profile.handle}</span>
      <button type="button" className="hk-text-button" onClick={signOut}>Sign out</button>
    </div>
  </div>;
}
