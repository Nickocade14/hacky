import { useEffect, useLayoutEffect, useRef, useState, type FormEvent } from "react";
import { Link, useParams } from "react-router-dom";
import { Notice } from "./components";
import { PersonAvatar, useSignedIn } from "./SignedInShell";
import { api, ApiClientError } from "./lib/api";
import { chatPath, eventPath, personPath } from "./lib/connections";
import type { components, operations } from "./lib/schema";
import "./chats.css";

type Conversation = components["schemas"]["ConversationSummary"];
type Message = components["schemas"]["Message"];
type MessagePage = components["schemas"]["MessagePage"];
type SendMessageBody = components["schemas"]["SendMessageBody"];
type ConversationList = operations["listConversations"]["responses"][200]["content"]["application/json"];
type SentMessage = operations["sendMessage"]["responses"][201]["content"]["application/json"];
type MessageQuery = NonNullable<operations["listMessages"]["parameters"]["query"]>;
type ReadReceipt = operations["markRead"]["responses"][200]["content"]["application/json"];
type Ok = components["schemas"]["Ok"];

type PendingMessage = SendMessageBody & { error?: string };
type Thread = { messages: Message[]; pending: PendingMessage[]; before?: string };

const pollInterval = 10_000;
const messageLimit = 4000;

const conversationPath = (id: string) => "/conversations/" + encodeURIComponent(id);

function getConversations(slug: string, signal: AbortSignal) {
  return api.authenticated<ConversationList>("/events/" + encodeURIComponent(slug) + "/conversations", { signal });
}

function getMessages(id: string, signal: AbortSignal, query?: MessageQuery) {
  const params = new URLSearchParams();
  if (query?.before) params.set("before", query.before);
  if (query?.after) params.set("after", query.after);
  if (query?.limit) params.set("limit", String(query.limit));
  const search = params.size ? "?" + params : "";
  return api.authenticated<MessagePage>(conversationPath(id) + "/messages" + search, { signal });
}

function isStatus(error: unknown, status: number) {
  return error instanceof ApiClientError && error.status === status;
}

function errorText(error: unknown, fallback: string) {
  return error instanceof Error ? error.message : fallback;
}

function titleOf(conversation: Conversation) {
  return conversation.team?.name ?? conversation.peer?.name ?? conversation.helpRequest?.title ?? "Conversation";
}

const messageBody = (message: Message) => message.kind === "card" ? "Shared a card" : message.body;

function previewOf(conversation: Conversation, userId: string) {
  const last = conversation.lastMessage;
  if (!last) return conversation.helpRequest ? "Help: " + conversation.helpRequest.title : "Say hi";
  return (last.kind !== "system" && last.senderId === userId ? "You: " : "") + messageBody(last);
}

function newestOwnMessage(messages: Message[], userId: string) {
  for (let index = messages.length - 1; index >= 0; index -= 1) {
    const message = messages[index];
    if (message.senderId === userId && message.kind !== "system") return message;
  }
}

function newClientId() {
  if (typeof crypto.randomUUID === "function") return crypto.randomUUID();
  const bytes = crypto.getRandomValues(new Uint8Array(16));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  const hex = Array.from(bytes, byte => byte.toString(16).padStart(2, "0")).join("");
  return [hex.slice(0, 8), hex.slice(8, 12), hex.slice(12, 16), hex.slice(16, 20), hex.slice(20)].join("-");
}

function timeOf(value: string, short = false) {
  const time = Date.parse(value);
  if (!Number.isFinite(time)) return "";
  return new Intl.DateTimeFormat(undefined, short ? { timeStyle: "short" } : { dateStyle: "medium", timeStyle: "short" }).format(time);
}

function mergeMessages(thread: Thread, messages: Message[], userId: string, removed: Set<string>): Thread {
  const byId = new Map(thread.messages.map(message => [message.id, message]));
  const delivered = new Set<string>();
  for (const message of messages) {
    if (!removed.has(message.id)) byId.set(message.id, message);
    if (message.senderId === userId && message.clientId) delivered.add(message.clientId);
  }
  return {
    ...thread,
    messages: [...byId.values()].sort((left, right) => left.id.localeCompare(right.id)),
    pending: thread.pending.filter(message => !delivered.has(message.clientId)),
  };
}

const olderCursor = (page: MessagePage) => page.hasMore ? page.messages[0]?.id : undefined;

export function ConversationsPage() {
  const { me, event, onExpired } = useSignedIn();
  if (!event) return <JoinFirst />;
  return <ConversationListPage key={event.slug} slug={event.slug} userId={me.profile.userId} onExpired={onExpired} />;
}

function JoinFirst() {
  return <section className="workspace-card workspace-empty">
    <h1 tabIndex={-1}>Join an event first</h1>
    <p>Your chats are grouped by hackathon. Pick yours on Home.</p>
    <Link className="button primary" to="/app">Go to Home</Link>
  </section>;
}

function ConversationListPage({ slug, userId, onExpired }: { slug: string; userId: string; onExpired: () => void }) {
  const [conversations, setConversations] = useState<Conversation[] | null>(null);
  const [problem, setProblem] = useState("");
  const [revision, refresh] = useState(0);
  useEffect(() => {
    const controller = new AbortController();
    setProblem("");
    getConversations(slug, controller.signal).then(({ conversations }) => {
      if (!controller.signal.aborted) setConversations(conversations);
    }).catch((error: unknown) => {
      if (controller.signal.aborted) return;
      if (isStatus(error, 401)) onExpired();
      else setProblem(errorText(error, "Couldn’t load your chats."));
    });
    return () => controller.abort();
  }, [slug, revision, onExpired]);

  return <>
    <header className="workspace-heading chat-list-heading">
      <h1 tabIndex={-1}>Chats</h1>
      <Link className="button secondary" to={eventPath("/requests", slug)}>Requests</Link>
    </header>
    {problem && <div className="workspace-card">
      <Notice error>{problem}</Notice>
      <button className="button secondary" type="button" onClick={() => refresh(value => value + 1)}>Try again</button>
    </div>}
    {!conversations && !problem && <p role="status">Loading chats…</p>}
    {conversations?.length === 0 && <section className="workspace-card workspace-empty">
      <h2>No conversations yet</h2>
      <p>Accept a request or ask Hacky to find people.</p>
      <Link className="button primary" to={eventPath("/hacky", slug)}>Ask Hacky</Link>
    </section>}
    {conversations && conversations.length > 0 && <ul className="workspace-card workspace-list chat-list" aria-label="Conversations">
      {conversations.map(conversation => <li key={conversation.id}>
        <Link className="chat-list-row" to={chatPath(conversation.id, slug)}>
          <PersonAvatar name={titleOf(conversation)} photoUrl={conversation.peer?.photoUrl} />
          <div className="chat-list-copy">
            <strong>{titleOf(conversation)}</strong>
            <p>{previewOf(conversation, userId)}</p>
          </div>
          <div className="chat-list-meta">
            <time dateTime={conversation.lastMessageAt}>{timeOf(conversation.lastMessageAt)}</time>
            {conversation.unreadCount > 0 && <span className="workspace-chip">{conversation.unreadCount > 99 ? "99+" : conversation.unreadCount}<span className="visually-hidden"> unread</span></span>}
          </div>
        </Link>
      </li>)}
    </ul>}
  </>;
}

export function ChatThreadPage() {
  const { conversationId } = useParams();
  const { me, event, onExpired } = useSignedIn();
  const slug = event?.slug;

  if (!slug) return <JoinFirst />;
  if (!conversationId) return <Link className="button secondary" to={eventPath("/chats", slug)}>Back to Chats</Link>;
  return <ChatThread key={slug + ":" + conversationId} id={conversationId} slug={slug} userId={me.profile.userId} onExpired={onExpired} />;
}

function ChatThread({ id, slug, userId, onExpired }: { id: string; slug: string; userId: string; onExpired: () => void }) {
  const [thread, setThread] = useState<Thread | null>(null);
  const [conversation, setConversation] = useState<Conversation>();
  const [problem, setProblem] = useState("");
  const [revision, refresh] = useState(0);
  const [draft, setDraft] = useState("");
  const [sending, setSending] = useState(false);
  const [loadingOlder, setLoadingOlder] = useState(false);
  const [olderProblem, setOlderProblem] = useState("");
  const [deleteTarget, setDeleteTarget] = useState<string>();
  const [deleting, setDeleting] = useState(false);
  const [deleteProblem, setDeleteProblem] = useState("");

  const lifetime = useRef<AbortController | null>(null);
  const synced = useRef<string | undefined>(undefined);
  const removed = useRef(new Set<string>());
  const sendingNow = useRef(false);
  const feed = useRef<HTMLDivElement>(null);
  const scroll = useRef<"bottom" | { height: number; top: number } | null>(null);
  const loaded = thread !== null;

  useEffect(() => {
    const controller = new AbortController();
    lifetime.current = controller;
    return () => controller.abort();
  }, []);

  useLayoutEffect(() => {
    const node = feed.current;
    const position = scroll.current;
    if (node && position) {
      node.scrollTop = position === "bottom" ? node.scrollHeight : node.scrollHeight - position.height + position.top;
      scroll.current = null;
    }
  }, [thread]);

  function markRead(signal: AbortSignal) {
    void api.authenticated<ReadReceipt>(conversationPath(id) + "/read", { method: "POST", signal }).catch((error: unknown) => {
      if (!signal.aborted && isStatus(error, 401)) onExpired();
    });
  }

  useEffect(() => {
    const controller = new AbortController();
    const { signal } = controller;
    setProblem("");
    Promise.all([getConversations(slug, signal), getMessages(id, signal)]).then(([list, page]) => {
      if (signal.aborted) return;
      const summary = list.conversations.find(item => item.id === id);
      if (!summary) {
        setProblem("This conversation isn’t available in this event.");
        return;
      }
      synced.current = page.messages.at(-1)?.id;
      scroll.current = "bottom";
      setConversation(summary);
      setThread({ messages: page.messages, before: olderCursor(page), pending: [] });
      markRead(signal);
    }).catch((error: unknown) => {
      if (signal.aborted) return;
      if (isStatus(error, 401)) onExpired();
      else setProblem(errorText(error, "Couldn’t load this conversation."));
    });
    return () => controller.abort();
  }, [id, slug, revision, onExpired]);

  useEffect(() => {
    if (!loaded) return;
    const controller = new AbortController();
    const { signal } = controller;
    let polling = false;

    const timer = window.setInterval(async () => {
      if (polling || document.visibilityState === "hidden") return;
      polling = true;
      const after = synced.current;
      try {
        const [page, list] = await Promise.all([
          getMessages(id, signal, { after, limit: 100 }),
          getConversations(slug, signal),
        ]);
        if (signal.aborted) return;
        const summary = list.conversations.find(item => item.id === id);
        if (summary) setConversation(summary);
        if (!page.messages.length) return;
        synced.current = page.messages.at(-1)?.id;
        const node = feed.current;
        if (!scroll.current && node && node.scrollHeight - node.scrollTop - node.clientHeight < 80) scroll.current = "bottom";
        setThread(current => {
          if (!current) return current;
          const merged = mergeMessages(current, page.messages, userId, removed.current);
          return after ? merged : { ...merged, before: olderCursor(page) };
        });
        if (page.messages.some(message => message.senderId !== userId)) markRead(signal);
      } catch (error) {
        if (!signal.aborted && isStatus(error, 401)) onExpired();
      } finally {
        polling = false;
      }
    }, pollInterval);
    return () => { window.clearInterval(timer); controller.abort(); };
  }, [loaded, id, slug, userId, onExpired]);

  async function loadOlder() {
    const signal = lifetime.current?.signal;
    if (!signal || signal.aborted || !thread?.before || loadingOlder) return;
    setLoadingOlder(true);
    setOlderProblem("");
    try {
      const page = await getMessages(id, signal, { before: thread.before });
      if (signal.aborted) return;
      const node = feed.current;
      if (node) scroll.current = { height: node.scrollHeight, top: node.scrollTop };
      setThread(current => current && { ...mergeMessages(current, page.messages, userId, removed.current), before: olderCursor(page) });
    } catch (error) {
      if (signal.aborted) return;
      if (isStatus(error, 401)) onExpired();
      else setOlderProblem(errorText(error, "Couldn’t load earlier messages."));
    } finally {
      if (!signal.aborted) setLoadingOlder(false);
    }
  }

  async function deliver(body: SendMessageBody) {
    const signal = lifetime.current?.signal;
    if (!signal || signal.aborted || sendingNow.current) return;
    sendingNow.current = true;
    setSending(true);
    scroll.current = "bottom";
    setThread(current => {
      if (!current) return current;
      const pending = current.pending.some(message => message.clientId === body.clientId)
        ? current.pending.map(message => message.clientId === body.clientId ? body : message)
        : [...current.pending, body];
      return { ...current, pending };
    });
    try {
      const { message } = await api.authenticated<SentMessage>(conversationPath(id) + "/messages", { method: "POST", body, signal });
      if (!signal.aborted) setThread(current => current && mergeMessages(current, [message], userId, removed.current));
    } catch (error) {
      if (signal.aborted) return;
      if (isStatus(error, 401)) onExpired();
      else setThread(current => current && {
        ...current,
        pending: current.pending.map(message => message.clientId === body.clientId
          ? { ...message, error: errorText(error, "Couldn’t send this message.") }
          : message),
      });
    } finally {
      if (!signal.aborted) {
        sendingNow.current = false;
        setSending(false);
      }
    }
  }

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const body = draft.trim();
    if (!body || !thread || sendingNow.current) return;
    setDraft("");
    void deliver({ clientId: newClientId(), body });
  }

  async function unsend(messageId: string) {
    const signal = lifetime.current?.signal;
    if (!signal || signal.aborted || deleting) return;
    setDeleting(true);
    setDeleteProblem("");
    try {
      try {
        await api.authenticated<Ok>(conversationPath(id) + "/messages/" + encodeURIComponent(messageId), { method: "DELETE", signal });
      } catch (error) {
        if (!isStatus(error, 404)) throw error;
      }
      if (signal.aborted) return;
      removed.current.add(messageId);
      setThread(current => current && { ...current, messages: current.messages.filter(message => message.id !== messageId) });
      setDeleteTarget(undefined);
    } catch (error) {
      if (signal.aborted) return;
      if (isStatus(error, 401)) onExpired();
      else setDeleteProblem(errorText(error, "Couldn’t unsend this message."));
    } finally {
      if (!signal.aborted) setDeleting(false);
    }
  }

  const peer = conversation?.peer;
  const title = conversation ? titleOf(conversation) : "Conversation";
  const lastOwn = thread && newestOwnMessage(thread.messages, userId);
  const seen = lastOwn && conversation?.kind !== "team" && conversation?.peerLastReadAt && Date.parse(conversation.peerLastReadAt) >= Date.parse(lastOwn.createdAt)
    ? lastOwn.id : undefined;

  return <>
    <Link className="chat-back" to={eventPath("/chats", slug)}>Back to Chats</Link>
    <section className="workspace-card chat-thread">
      <header className="chat-thread-heading">
        {peer ? <Link className="chat-identity" to={personPath(peer.handle, slug)}>
          <PersonAvatar name={title} photoUrl={peer.photoUrl} />
          <h1 tabIndex={-1}>{title}</h1>
        </Link> : <h1 tabIndex={-1}>{title}</h1>}
      </header>
      {problem && <><Notice error>{problem}</Notice>
        <button className="button secondary" type="button" onClick={() => refresh(value => value + 1)}>Try again</button>
      </>}
      {!thread && !problem && <p role="status">Loading messages…</p>}
      {thread && <>
        <div className="chat-feed" role="log" aria-label="Messages" ref={feed}>
          {thread.before && <div className="chat-older">
            {olderProblem && <Notice error>{olderProblem}</Notice>}
            <button type="button" className="button secondary" disabled={loadingOlder} onClick={() => void loadOlder()}>
              {loadingOlder ? "Loading…" : olderProblem ? "Retry earlier messages" : "Load earlier messages"}
            </button>
          </div>}
          {!thread.messages.length && !thread.pending.length && <p className="chat-empty">No messages yet. Say hi and share what you’re building.</p>}
          {thread.messages.map(message => {
            if (message.kind === "system") return <p key={message.id} className="chat-system">{message.body}</p>;
            const mine = message.senderId === userId;
            return <div key={message.id} className={mine ? "chat-message mine" : "chat-message"}>
              <p className="chat-bubble">{messageBody(message)}</p>
              <div className="chat-message-meta">
                <time dateTime={message.createdAt}>{timeOf(message.createdAt, true)}</time>
                {seen === message.id && <span>Seen</span>}
                {mine && deleteTarget !== message.id && <button type="button" className="chat-action" disabled={deleting} onClick={() => {
                  setDeleteProblem("");
                  setDeleteTarget(message.id);
                }}>Unsend</button>}
              </div>
              {deleteTarget === message.id && <div className="chat-confirm">
                <p>Remove this message for everyone?</p>
                {deleteProblem && <Notice error>{deleteProblem}</Notice>}
                <div className="workspace-actions">
                  <button type="button" className="button secondary" disabled={deleting} onClick={() => setDeleteTarget(undefined)}>Cancel</button>
                  <button type="button" className="button primary" disabled={deleting} onClick={() => void unsend(message.id)}>
                    {deleting ? "Unsending…" : "Unsend for everyone"}
                  </button>
                </div>
              </div>}
            </div>;
          })}
          {thread.pending.map(message => <div key={message.clientId} className="chat-message mine">
            <p className="chat-bubble">{message.body}</p>
            {message.error ? <div className="chat-message-meta" role="alert">
              <span>{message.error}</span>
              <button type="button" className="chat-action" disabled={sending} onClick={() => void deliver({ clientId: message.clientId, body: message.body })}>Retry</button>
              <button type="button" className="chat-action" onClick={() => setThread(current => current && {
                ...current, pending: current.pending.filter(item => item.clientId !== message.clientId),
              })}>Dismiss</button>
            </div> : <p className="chat-message-meta">Sending…</p>}
          </div>)}
        </div>
        <form className="chat-composer" onSubmit={submit}>
          <label htmlFor="chat-message" className="visually-hidden">Message</label>
          <textarea id="chat-message" placeholder="Write a message…" rows={2} maxLength={messageLimit} value={draft} onChange={event => setDraft(event.target.value)} />
          <button className="button primary" type="submit" disabled={sending || !draft.trim()}>{sending ? "Sending…" : "Send"}</button>
        </form>
      </>}
    </section>
  </>;
}
