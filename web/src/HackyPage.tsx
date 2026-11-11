import { useCallback, useEffect, useLayoutEffect, useRef, useState, type FormEvent, type ReactNode } from "react";
import { Link, Navigate } from "react-router-dom";
import { Notice } from "./components";
import { useSignedIn } from "./SignedInShell";
import { api, ApiClientError } from "./lib/api";
import { chatPath, eventPath, listConnectionRequests, personPath } from "./lib/connections";
import type { ChatMessage, Me } from "./lib/contracts";
import {
  firstName, introProblem, newMessageId, openingIntro, partsOf, shownSkills, textOf, whyLine,
  type HackyCard, type HackyPart,
} from "./lib/hacky";
import { useMedia } from "./lib/theme";
import { KnitAvatar } from "./workspace/KnitAvatar";
import { Icon } from "./workspace/icons";

// Hacky chat on web, laid out like mlhacky.com (seeko-codes/Hacky react/src/hacky):
// the opening brief with four starting points, then the conversation. It loads my
// history, sends each message with ?format=json, shows Hacky's text and person or
// mentor cards, and sends connection requests from the cards.

/** The four starting points under the brief: what the button says, and what it asks Hacky. */
export const starters = [
  { label: "Find hackers", prompt: "Find a teammate for my project", art: "/assets/people/mika.webp" },
  { label: "Pick a track", prompt: "Help me pick a track", art: "/assets/shortcuts/event.svg" },
  { label: "Find mentor", prompt: "Find a mentor", art: "/assets/people/aya.webp", crown: true },
  { label: "Open teams", prompt: "Who’s looking for a team?", art: "/assets/shortcuts/sponsor.svg" },
] as const;

const clips = {
  brief: { moving: "/assets/mascots/video/hacky-chat.webp", still: "/assets/mascots/video/hacky-chat.png" },
  thinking: { moving: "/assets/mascots/video/hacky-thinking.webp", still: "/assets/mascots/video/hacky-thinking.png" },
};

/** One of Hacky's clips; a still frame for anyone who asked for less motion. Decorative. */
function Film({ clip, className }: { clip: keyof typeof clips; className: string }) {
  const still = useMedia("(prefers-reduced-motion: reduce)");
  return <img className={className} src={still ? clips[clip].still : clips[clip].moving} alt="" decoding="async" draggable={false} />;
}

/** **bold** in Hacky's text, the rest as written. */
function RichText({ text }: { text: string }) {
  return <>{text.split(/(\*\*[^*]+\*\*)/g).map((piece, i) =>
    piece.startsWith("**") && piece.endsWith("**") && piece.length > 4
      ? <strong key={i}>{piece.slice(2, -2)}</strong>
      : piece)}</>;
}

type Sent = { status: "pending" | "accepted"; conversationId: string | null };

export function HackyPage() {
  const { me, event, onExpired } = useSignedIn();
  // Hacky finds people inside a hackathon, so Home (where you join one) comes first.
  if (!event) return <Navigate to="/app" replace />;
  // A new event starts a new conversation.
  return <HackyChat key={event.slug} slug={event.slug} me={me} onExpired={onExpired} />;
}

// "New chat" clears what this browser shows; the server keeps the history.
const startKey = (userId: string, slug: string) => `hacky-chat-start:${userId}:${slug}`;
function readStart(userId: string, slug: string) {
  try { return window.localStorage.getItem(startKey(userId, slug)); } catch { return null; }
}

function HackyChat({ slug, me, onExpired }: { slug: string; me: Me; onExpired: () => void }) {
  const userId = me.profile.userId;
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [load, setLoad] = useState<{ loading: boolean; error?: string }>({ loading: true });
  const [retryLoad, setRetryLoad] = useState(0);
  const [thinking, setThinking] = useState(false);
  const [failures, setFailures] = useState<Record<string, string>>({});
  const [sent, setSent] = useState<Record<string, Sent>>({});
  const [draft, setDraft] = useState("");
  const [startAfter, setStartAfter] = useState(() => readStart(userId, slug));
  const [confirmNew, setConfirmNew] = useState(false);
  const feed = useRef<HTMLDivElement>(null);
  const input = useRef<HTMLTextAreaElement>(null);
  const alive = useRef(true);
  useEffect(() => { alive.current = true; return () => { alive.current = false; }; }, []);

  useEffect(() => {
    const controller = new AbortController();
    setLoad({ loading: true });
    api.getChatHistory(slug, controller.signal)
      .then((result) => { if (!controller.signal.aborted) { setMessages(result.messages); setLoad({ loading: false }); } })
      .catch((failure: unknown) => {
        if (controller.signal.aborted) return;
        if (failure instanceof ApiClientError && failure.status === 401) onExpired();
        else setLoad({ loading: false, error: failure instanceof Error ? failure.message : "Couldn’t load your chat." });
      });
    listConnectionRequests(slug, controller.signal).then(requests => {
      if (controller.signal.aborted) return;
      const saved: Record<string, Sent> = {};
      for (const request of requests) {
        if (!request.team && (request.status === "accepted" || request.direction === "outgoing")) {
          saved[request.person.userId] = { status: request.status === "accepted" ? "accepted" : "pending", conversationId: request.conversationId };
        }
      }
      setSent(current => ({ ...saved, ...current }));
    }).catch((failure: unknown) => {
      if (!controller.signal.aborted && failure instanceof ApiClientError && failure.status === 401) onExpired();
    });
    return () => controller.abort();
  }, [slug, retryLoad, onExpired]);

  const startIndex = startAfter ? messages.findIndex(message => message.id === startAfter) : -1;
  const shown = startIndex >= 0 ? messages.slice(startIndex + 1) : messages;

  // Keep the latest turn in view; a fresh page with no conversation starts at the brief.
  useLayoutEffect(() => {
    const node = feed.current;
    if (node && (shown.length || thinking)) node.scrollTop = node.scrollHeight;
  }, [shown.length, thinking, load.loading]);

  // The message box grows with what I type, up to a few lines.
  useLayoutEffect(() => {
    const node = input.current;
    if (!node) return;
    node.style.height = "40px";
    node.style.height = `${Math.max(40, Math.min(116, node.scrollHeight))}px`;
  }, [draft]);

  const send = useCallback(async (message: ChatMessage) => {
    setMessages((list) => [...list, message]);
    setThinking(true);
    try {
      const { message: answer } = await api.sendChat(slug, { message });
      if (alive.current) setMessages((list) => [...list, answer]);
    } catch (failure) {
      if (!alive.current) return;
      if (failure instanceof ApiClientError && failure.status === 401) { onExpired(); return; }
      setFailures((all) => ({ ...all, [message.id]: failure instanceof Error ? failure.message : "Something went wrong. Please try again." }));
    } finally {
      if (alive.current) setThinking(false);
    }
  }, [slug, onExpired]);

  const busy = thinking || load.loading || !!load.error;

  function ask(text: string) {
    const trimmed = text.trim();
    if (!trimmed || busy) return;
    setDraft("");
    void send({ id: newMessageId(), role: "user", parts: [{ type: "text", text: trimmed }] });
  }

  // A failed message moves to the end and goes again with the same id, so the
  // server answers with its saved reply if the first try did get through.
  function retry(message: ChatMessage) {
    if (thinking) return;
    setMessages((list) => list.filter((item) => item !== message));
    setFailures(({ [message.id]: _, ...rest }) => rest);
    void send(message);
  }

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    ask(draft);
  }

  function startNew() {
    const last = messages.at(-1)?.id ?? null;
    setStartAfter(last);
    setConfirmNew(false);
    try {
      if (last) window.localStorage.setItem(startKey(userId, slug), last);
    } catch { /* private mode: the fresh start lasts this visit */ }
    input.current?.focus();
  }

  return <section className="hk-pane" aria-label="Hacky chat">
    <div className="hk-pane-bar">
      {confirmNew ? <div className="hk-new-confirm" role="group" aria-label="Start a new chat?">
        <span>Clear this screen? Hacky keeps your history.</span>
        <button type="button" className="hk-text-button" onClick={() => setConfirmNew(false)}>Keep</button>
        <button type="button" className="hk-text-button strong" onClick={startNew}>Start new</button>
      </div> : <button type="button" className="hk-toggle" disabled={thinking || shown.length === 0} onClick={() => setConfirmNew(true)}>
        <Icon name="restart" /> New chat
      </button>}
    </div>

    <div className="hk-feed" ref={feed}>
      <div className="hk-brief">
        <Film clip="brief" className="hk-brief-film" />
        <h1 tabIndex={-1}>What can I help you with?</h1>
        <p>Pick a starting point, or tell me what you’re trying to do.</p>
        <div className="hk-starters" role="group" aria-label="Starting points">
          {starters.map((starter) => <button key={starter.label} type="button" className="hk-starter" aria-label={starter.label} disabled={busy} onClick={() => ask(starter.prompt)}>
            <img src={starter.art} alt="" className={starter.art.endsWith(".svg") ? "art" : "face"} />
            {"crown" in starter
              ? <span>Find mento<span className="hk-crowned">r<svg className="hk-crown" aria-hidden="true" viewBox="0 0 16 12"><path d="M2 9 1 3l4 3 3-5 3 5 4-3-1 6Z" /><path d="M3 11h10" /></svg></span></span>
              : starter.label}
          </button>)}
        </div>
      </div>

      <div className="hk-thread" role="log" aria-label="Conversation with Hacky" aria-busy={thinking}>
        {load.loading && <p className="hk-quiet" role="status">Loading your chat…</p>}
        {load.error && <div className="hk-load-error">
          <Notice error>{load.error}</Notice>
          <button type="button" className="hk-button secondary" onClick={() => setRetryLoad((n) => n + 1)}>Try again</button>
        </div>}
        {!load.loading && !load.error && shown.map((message) => message.role === "user"
          ? <UserTurn key={message.id} text={textOf(message)} failure={failures[message.id]} onRetry={thinking ? undefined : () => retry(message)} />
          : message.role === "assistant"
            ? <AssistantTurn key={message.id} parts={partsOf(message)} me={me} slug={slug} sent={sent} onExpired={onExpired}
                onSent={(id, request) => setSent((all) => ({ ...all, [id]: request }))} />
            : null)}
        {thinking && <div className="hk-thinking" role="status">
          <Film clip="thinking" className="hk-thinking-film" />
          <span className="visually-hidden">Hacky is thinking…</span>
          <span className="hk-dots" aria-hidden="true"><i /><i /><i /></span>
        </div>}
      </div>
    </div>

    <div className="hk-compose-wrap">
      <form className="hk-composer" onSubmit={submit} aria-label="Write to Hacky">
        <label className="visually-hidden" htmlFor="hacky-message">Message Hacky</label>
        <textarea ref={input} id="hacky-message" rows={1} value={draft} placeholder="Ask Hacky…" maxLength={1000} enterKeyHint="send"
          disabled={!!load.error} onChange={(change) => setDraft(change.target.value)}
          onKeyDown={(press) => {
            if (press.key === "Enter" && !press.shiftKey && !press.nativeEvent.isComposing) {
              press.preventDefault();
              ask(draft);
            }
          }} />
        <button className="hk-send" type="submit" disabled={busy || !draft.trim()} aria-label={thinking ? "Hacky is thinking" : "Send to Hacky"}><Icon name="send" /></button>
      </form>
      <p className="hk-note">Hacky drafts. You decide what gets sent.</p>
    </div>
  </section>;
}

function UserTurn({ text, failure, onRetry }: { text: string; failure?: string; onRetry?: () => void }) {
  if (!text) return null;
  return <div className="hk-turn mine">
    <p className={`hk-bubble mine${failure ? " failed" : ""}`}>{text}</p>
    {failure && <p className="hk-failed" role="alert">
      Not sent. {failure}{" "}
      <button type="button" className="hk-text-button" onClick={onRetry} disabled={!onRetry}>Retry</button>
    </p>}
  </div>;
}

type CardProps = { me: Me; slug: string; sent: Record<string, Sent>; onSent: (userId: string, request: Sent) => void; onExpired: () => void };

function AssistantTurn({ parts, ...cardProps }: { parts: HackyPart[] } & CardProps) {
  if (!parts.length) return null;
  return <div className="hk-turn">
    {parts.map((part, i) => part.type === "text"
      ? <p key={i} className="hk-bubble"><RichText text={part.text} /></p>
      : <div key={i} className="hk-matches">
        <span className="hk-matches-count">{part.cards.length} {part.cards.length === 1 ? (part.mentors ? "mentor" : "person") : (part.mentors ? "mentors" : "people")}</span>
        {part.cards.map((card) => <PersonCard key={card.person.userId} card={card} {...cardProps} />)}
      </div>)}
  </div>;
}

function PersonCard({ card, me, slug, sent, onSent, onExpired }: { card: HackyCard } & CardProps) {
  const { person } = card;
  const [intro, setIntro] = useState<string | null>(null);
  const [problem, setProblem] = useState<string | null>(null);
  const [sending, setSending] = useState(false);
  const matched = new Set(card.matchedSkills.map((skill) => skill.toLowerCase()));
  const connection = sent[person.userId];
  const why = whyLine(card);
  const facts = [`@${person.handle}`, card.mentor ? "Mentor" : "Hacker", ...(card.mentor && card.verified ? ["Verified"] : [])];

  async function sendRequest(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const text = intro ?? "";
    const local = introProblem(text);
    if (local) { setProblem(local); return; }
    setSending(true); setProblem(null);
    try {
      const { request } = await api.sendRequest(slug, { toUserId: person.userId, intro: text.trim(), source: "agent" });
      onSent(person.userId, { status: request.status === "accepted" ? "accepted" : "pending", conversationId: request.conversationId });
      setIntro(null);
    } catch (failure) {
      if (failure instanceof ApiClientError && failure.status === 401) { onExpired(); return; }
      setProblem(failure instanceof Error ? failure.message : "Couldn’t send the request. Please try again.");
    } finally {
      setSending(false);
    }
  }

  return <article className="hk-match" aria-label={person.name}>
    <div className="hk-match-head">
      <KnitAvatar person={person} size={56} />
      <div className="hk-match-who">
        <h3><Link to={personPath(person.handle, slug)} state={{ from: "/hacky" }}>{person.name}</Link></h3>
        <p>{facts.join(" · ")}</p>
      </div>
      {card.mentor && card.availability && <span className="hk-tag">{card.availability}</span>}
    </div>
    {why && <p className="hk-match-why">{why}</p>}
    {card.skills.length > 0 && <ul className="hk-skills" aria-label="Skills">
      {shownSkills(card).map((skill) => <li key={skill} className={matched.has(skill.toLowerCase()) ? "matched" : undefined}>{skill}</li>)}
    </ul>}
    {connection?.status === "accepted" && <p className="hk-match-status" role="status">You’re connected. {connection.conversationId
      ? <Link to={chatPath(connection.conversationId, slug)}>Open chat</Link>
      : <Link to={eventPath("/chats", slug)}>View chats</Link>}</p>}
    {connection?.status === "pending" && <p className="hk-match-status" role="status">Request sent. <Link to={eventPath("/requests", slug)}>View requests</Link></p>}
    {!connection && intro === null && <button type="button" className="hk-button" onClick={() => { setIntro(openingIntro(me.profile.name, person.name)); setProblem(null); }}>Connect</button>}
    {!connection && intro !== null && <form className="hk-intro" onSubmit={sendRequest} aria-label={`Request to ${person.name}`}>
      <label htmlFor={`intro-${person.userId}`}>Intro for {firstName(person.name)}</label>
      <textarea id={`intro-${person.userId}`} value={intro} onChange={(change) => setIntro(change.target.value)} maxLength={500} rows={3} />
      {problem && <Notice error>{problem}</Notice>}
      <div className="hk-intro-actions">
        <button type="submit" className="hk-button" disabled={sending}>{sending ? "Sending…" : "Send request"}</button>
        <button type="button" className="hk-button secondary" disabled={sending} onClick={() => { setIntro(null); setProblem(null); }}>Cancel</button>
      </div>
    </form>}
  </article>;
}
