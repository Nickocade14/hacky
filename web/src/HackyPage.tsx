import { useCallback, useEffect, useRef, useState, type FormEvent, type ReactNode } from "react";
import { Link } from "react-router-dom";
import { Notice } from "./components";
import { PersonAvatar, useSignedIn } from "./SignedInShell";
import { api, ApiClientError } from "./lib/api";
import type { ChatMessage, Me } from "./lib/contracts";
import {
  firstName, introProblem, newMessageId, openingIntro, partsOf, shownSkills, textOf, whyLine,
  type HackyCard, type HackyPart,
} from "./lib/hacky";

// 12 Hacky chat on web, like mobile/lib/screens/hacky_chat_screen.dart:
// loads my history, sends each message with ?format=json, shows Hacky's text
// and person/mentor cards, and sends connection requests from the cards.

export const suggestions = [
  "Find a teammate who knows React",
  "Find a mentor",
  "Who’s looking for a team?",
  "Help me pick a track",
];

const mascot = "/assets/mascots/hacky-knit.webp";

/** **bold** in Hacky's text, the rest as written. */
function RichText({ text }: { text: string }) {
  return <>{text.split(/(\*\*[^*]+\*\*)/g).map((piece, i) =>
    piece.startsWith("**") && piece.endsWith("**") && piece.length > 4
      ? <strong key={i}>{piece.slice(2, -2)}</strong>
      : piece)}</>;
}

type Sent = { status: "pending" | "accepted" };

export function HackyPage() {
  const { me, event, onExpired } = useSignedIn();
  if (!event) {
    return <section className="workspace-card workspace-empty">
      <h1 tabIndex={-1}>Join an event first</h1>
      <p>Hacky finds people inside a hackathon. Pick yours on Home.</p>
      <Link className="button primary" to="/app">Go to Home</Link>
    </section>;
  }
  // A new event starts a new conversation.
  return <HackyChat key={event.slug} slug={event.slug} me={me} onExpired={onExpired} />;
}

function HackyChat({ slug, me, onExpired }: { slug: string; me: Me; onExpired: () => void }) {
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [load, setLoad] = useState<{ loading: boolean; error?: string }>({ loading: true });
  const [retryLoad, setRetryLoad] = useState(0);
  const [thinking, setThinking] = useState(false);
  const [failures, setFailures] = useState<Record<string, string>>({});
  const [sent, setSent] = useState<Record<string, Sent>>({});
  const [draft, setDraft] = useState("");
  const end = useRef<HTMLDivElement>(null);
  const alive = useRef(true);
  const name = firstName(me.profile.name);

  useEffect(() => { alive.current = true; return () => { alive.current = false; }; }, []);

  useEffect(() => {
    const controller = new AbortController();
    setLoad({ loading: true });
    api.getChatHistory(slug, controller.signal)
      .then((result) => { setMessages(result.messages); setLoad({ loading: false }); })
      .catch((failure: unknown) => {
        if (controller.signal.aborted) return;
        if (failure instanceof ApiClientError && failure.status === 401) onExpired();
        else setLoad({ loading: false, error: failure instanceof Error ? failure.message : "Couldn’t load your chat." });
      });
    return () => controller.abort();
  }, [slug, retryLoad, onExpired]);

  useEffect(() => { end.current?.scrollIntoView?.({ block: "end" }); }, [messages, thinking]);

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

  function ask(text: string) {
    const trimmed = text.trim();
    if (!trimmed || thinking) return;
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

  const busy = thinking || load.loading || !!load.error;

  return <section className="hacky" aria-label="Hacky chat">
    <header className="hacky-header">
      <img className="hacky-avatar" src={mascot} alt="" />
      <div>
        <h1 tabIndex={-1}>Hacky</h1>
        <p>{thinking ? "Thinking…" : "Your hackathon helper"}</p>
      </div>
    </header>

    <div className="hacky-thread" role="log" aria-label="Conversation with Hacky" aria-busy={thinking}>
      {load.loading && <p role="status">Loading your chat…</p>}
      {load.error && <>
        <Notice error>{load.error}</Notice>
        <button type="button" className="button secondary" onClick={() => setRetryLoad((n) => n + 1)}>Try again</button>
      </>}
      {!load.loading && !load.error && messages.length === 0 && <div className="hacky-welcome">
        <img src={mascot} alt="" />
        <h2>Hi {name}!</h2>
        <p>What are you building, and who do you need? I can find you teammates, mentors and open teams.</p>
        <span className="eyebrow">Try asking</span>
        <Chips prompts={suggestions} disabled={busy} onPick={ask} />
      </div>}
      {!load.loading && !load.error && messages.length > 0 && <>
        <HackyTurn><p className="hacky-bubble">Hi {name}! What are you building, and who do you need?</p></HackyTurn>
        {messages.map((message) => message.role === "user"
          ? <UserTurn key={message.id} text={textOf(message)} failure={failures[message.id]} onRetry={thinking ? undefined : () => retry(message)} />
          : message.role === "assistant"
            ? <AssistantTurn key={message.id} parts={partsOf(message)} me={me} slug={slug} sent={sent} onExpired={onExpired}
                onSent={(userId, status) => setSent((all) => ({ ...all, [userId]: { status } }))} />
            : null)}
        {thinking && <HackyTurn><p className="hacky-thinking" role="status"><span aria-hidden="true">• • •</span> Hacky is thinking…</p></HackyTurn>}
      </>}
      <div ref={end} />
    </div>

    <form className="hacky-composer" onSubmit={submit} aria-label="Write to Hacky">
      <label className="visually-hidden" htmlFor="hacky-message">Message Hacky</label>
      <input id="hacky-message" value={draft} onChange={(change) => setDraft(change.target.value)} placeholder="Message Hacky…"
        maxLength={1000} autoComplete="off" disabled={!!load.error} />
      <button className="button primary" type="submit" disabled={busy || !draft.trim()}>{thinking ? "Thinking…" : "Send"}</button>
    </form>
  </section>;
}

function Chips({ prompts, disabled, onPick }: { prompts: string[]; disabled: boolean; onPick: (text: string) => void }) {
  return <div className="hacky-chips">
    {prompts.map((prompt) => <button key={prompt} type="button" className="hacky-chip" disabled={disabled} onClick={() => onPick(prompt)}>{prompt}</button>)}
  </div>;
}

function HackyTurn({ children }: { children: ReactNode }) {
  return <div className="hacky-turn">
    <img className="hacky-avatar small" src={mascot} alt="Hacky" />
    <div className="hacky-turn-body">{children}</div>
  </div>;
}

function UserTurn({ text, failure, onRetry }: { text: string; failure?: string; onRetry?: () => void }) {
  if (!text) return null;
  return <div className="hacky-user">
    <p className={`hacky-user-bubble${failure ? " failed" : ""}`}>{text}</p>
    {failure && <p className="hacky-failed" role="alert">
      Not sent. {failure}{" "}
      <button type="button" className="link-button" onClick={onRetry} disabled={!onRetry}>Retry</button>
    </p>}
  </div>;
}

type CardProps = { me: Me; slug: string; sent: Record<string, Sent>; onSent: (userId: string, status: Sent["status"]) => void; onExpired: () => void };

function AssistantTurn({ parts, ...cardProps }: { parts: HackyPart[] } & CardProps) {
  if (!parts.length) return null;
  return <HackyTurn>
    {parts.map((part, i) => part.type === "text"
      ? <p key={i} className="hacky-bubble"><RichText text={part.text} /></p>
      : <div key={i} className="hacky-cards">
        <span className="eyebrow">{part.cards.length} {part.cards.length === 1 ? (part.mentors ? "mentor" : "person") : (part.mentors ? "mentors" : "people")}</span>
        {part.cards.map((card) => <PersonCard key={card.person.userId} card={card} {...cardProps} />)}
      </div>)}
  </HackyTurn>;
}

function PersonCard({ card, me, slug, sent, onSent, onExpired }: { card: HackyCard } & CardProps) {
  const { person } = card;
  const [intro, setIntro] = useState<string | null>(null);
  const [problem, setProblem] = useState<string | null>(null);
  const [sending, setSending] = useState(false);
  const matched = new Set(card.matchedSkills.map((skill) => skill.toLowerCase()));
  const status = sent[person.userId]?.status;
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
      onSent(person.userId, request.status === "accepted" ? "accepted" : "pending");
      setIntro(null);
    } catch (failure) {
      if (failure instanceof ApiClientError && failure.status === 401) { onExpired(); return; }
      setProblem(failure instanceof Error ? failure.message : "Couldn’t send the request. Please try again.");
    } finally {
      setSending(false);
    }
  }

  return <article className="workspace-card hacky-card" aria-label={person.name}>
    <div className="hacky-card-head">
      <PersonAvatar name={person.name} photoUrl={person.photoUrl} />
      <div>
        <h3>{person.name}</h3>
        <p>{facts.join(" · ")}</p>
      </div>
      {card.mentor && card.availability && <span className="workspace-chip">{card.availability}</span>}
    </div>
    {why && <p className="hacky-why">{why}</p>}
    {card.skills.length > 0 && <ul className="workspace-chips hacky-skills" aria-label="Skills">
      {shownSkills(card).map((skill) => <li key={skill} className={matched.has(skill.toLowerCase()) ? "matched" : undefined}>{skill}</li>)}
    </ul>}
    {status === "accepted" && <p className="hacky-status" role="status">You’re connected. Say hi in Chats.</p>}
    {status === "pending" && <p className="hacky-status" role="status">Request sent. You’ll see it in Requests.</p>}
    {!status && intro === null && <button type="button" className="button primary" onClick={() => { setIntro(openingIntro(me.profile.name, person.name)); setProblem(null); }}>Connect</button>}
    {!status && intro !== null && <form className="hacky-intro" onSubmit={sendRequest} aria-label={`Request to ${person.name}`}>
      <label htmlFor={`intro-${person.userId}`}>Intro for {firstName(person.name)}</label>
      <textarea id={`intro-${person.userId}`} value={intro} onChange={(change) => setIntro(change.target.value)} maxLength={500} rows={3} />
      {problem && <Notice error>{problem}</Notice>}
      <div className="workspace-actions">
        <button type="submit" className="button primary" disabled={sending}>{sending ? "Sending…" : "Send request"}</button>
        <button type="button" className="button secondary" disabled={sending} onClick={() => { setIntro(null); setProblem(null); }}>Cancel</button>
      </div>
    </form>}
  </article>;
}
