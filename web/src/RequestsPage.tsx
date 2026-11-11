import { useEffect, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { Notice, useFormAction } from "./components";
import { PersonAvatar, useSignedIn } from "./SignedInShell";
import { ApiClientError } from "./lib/api";
import {
  acceptConnectionRequest,
  chatPath,
  hideConnectionRequest,
  listConnectionRequests,
  personPath,
  type ConnectionRequest,
} from "./lib/connections";
import "./connections.css";

type Direction = ConnectionRequest["direction"];
type Inbox = { requests: ConnectionRequest[] } | { error: string };
type Operation = { id: string; type: "accept" | "hide" };

const requestSources: Record<ConnectionRequest["source"], string> = {
  agent: "Via Hacky",
  profile: "Via profile",
  qr: "Via QR code",
};

export function RequestsPage() {
  const { event, me, onExpired } = useSignedIn();
  if (!event) return <>
    <header className="workspace-heading"><h1 tabIndex={-1}>Requests</h1></header>
    <section className="workspace-card workspace-empty">
      <h2>Join an event first</h2>
      <p>Connection requests are specific to a hackathon.</p>
      <Link className="button primary" to="/app">Go to Home</Link>
    </section>
  </>;

  return <EventRequests key={JSON.stringify([me.profile.userId, event.slug])}
    slug={event.slug} onExpired={onExpired} />;
}

function EventRequests({ slug, onExpired }: { slug: string; onExpired: () => void }) {
  const navigate = useNavigate();
  const action = useFormAction();
  const [inbox, setInbox] = useState<Inbox | null>(null);
  const [direction, setDirection] = useState<Direction>("incoming");
  const [operation, setOperation] = useState<Operation>();
  const [message, setMessage] = useState("");
  const [retry, setRetry] = useState(0);

  useEffect(() => {
    const controller = new AbortController();
    listConnectionRequests(slug, controller.signal)
      .then(requests => {
        if (!controller.signal.aborted) setInbox({ requests });
      })
      .catch((error: unknown) => {
        if (controller.signal.aborted) return;
        if (error instanceof ApiClientError && error.status === 401) {
          onExpired();
          return;
        }
        setInbox({ error: error instanceof Error ? error.message : "Couldn’t load requests." });
      });
    return () => controller.abort();
  }, [slug, retry, onExpired]);

  function updateRequest(id: string, update: (request: ConnectionRequest) => ConnectionRequest) {
    setInbox(current => current && "requests" in current
      ? { requests: current.requests.map(request => request.id === id ? update(request) : request) }
      : current);
  }

  function respond(id: string, type: Operation["type"]) {
    if (action.busy) return;
    setOperation({ id, type });
    setMessage("");
    void action.run(async signal => {
      try {
        if (type === "hide") {
          await hideConnectionRequest(id, signal);
          if (signal.aborted) return;
          const hiddenAt = new Date().toISOString();
          updateRequest(id, request => ({ ...request, hiddenAt }));
          setMessage("Request moved to Hidden.");
          return;
        }
        const { request } = await acceptConnectionRequest(id, signal);
        if (signal.aborted) return;
        updateRequest(id, () => request);
        if (request.conversationId) {
          navigate(chatPath(request.conversationId, slug));
        } else {
          setMessage("Request accepted.");
        }
      } catch (error) {
        if (signal.aborted) return;
        if (error instanceof ApiClientError && error.status === 401) {
          onExpired();
          return;
        }
        if (error instanceof ApiClientError && (error.status === 404 || error.status === 409)) {
          setRetry(value => value + 1);
        }
        throw error;
      }
    });
  }

  const requests = inbox && "requests" in inbox ? inbox.requests : [];
  const incoming = requests.filter(({ direction, status, hiddenAt }) =>
    direction === "incoming" && status === "pending" && !hiddenAt);
  const outgoing = requests.filter(({ direction, status }) => direction === "outgoing" && status === "pending");
  const hidden = requests.filter(({ direction, status, hiddenAt }) =>
    direction === "incoming" && status === "pending" && hiddenAt);
  const pending = direction === "incoming" ? incoming : outgoing;
  const accepted = requests.filter(request => request.direction === direction && request.status === "accepted");

  function renderRequest(request: ConnectionRequest) {
    return <RequestCard key={request.id} request={request} slug={slug} busy={action.busy}
      operation={operation?.id === request.id ? operation.type : undefined} onRespond={respond} />;
  }

  return <>
    <header className="workspace-heading">
      <h1 tabIndex={-1}>Requests</h1>
      <p>See who wants to connect and follow up on your requests.</p>
    </header>
    {!inbox && <p role="status">Loading requests…</p>}
    {inbox && "error" in inbox && <section className="workspace-card">
      <Notice error>{inbox.error}</Notice>
      <button type="button" className="button secondary" onClick={() => { setInbox(null); setRetry(value => value + 1); }}>Try again</button>
    </section>}
    {inbox && "requests" in inbox && <>
      <div className="connection-tabs" role="group" aria-label="Request direction">
        <button type="button" className="button secondary" aria-pressed={direction === "incoming"}
          onClick={() => setDirection("incoming")}>Incoming ({incoming.length})</button>
        <button type="button" className="button secondary" aria-pressed={direction === "outgoing"}
          onClick={() => setDirection("outgoing")}>Outgoing ({outgoing.length})</button>
      </div>
      {message && <Notice>{message}</Notice>}
      {action.error && <Notice error>{action.error}</Notice>}
      <section className="connection-request-group" aria-label={direction === "incoming" ? "Incoming requests" : "Outgoing requests"}>
        {pending.length > 0 ? <ul className="workspace-list connection-request-list">{pending.map(renderRequest)}</ul>
          : <div className="workspace-card workspace-empty"><p>{direction === "incoming" ? "No incoming requests." : "No outgoing requests."}</p></div>}
      </section>
      {accepted.length > 0 && <section className="connection-request-group" aria-labelledby="accepted-requests">
        <h2 id="accepted-requests">Accepted</h2>
        <ul className="workspace-list connection-request-list">{accepted.map(renderRequest)}</ul>
      </section>}
      {direction === "incoming" && hidden.length > 0 && <details className="workspace-card connection-hidden">
        <summary>Hidden ({hidden.length})</summary>
        <ul className="workspace-list connection-request-list">{hidden.map(renderRequest)}</ul>
      </details>}
    </>}
  </>;
}

function RequestCard({ request, slug, busy, operation, onRespond }: {
  request: ConnectionRequest;
  slug: string;
  busy: boolean;
  operation?: Operation["type"];
  onRespond: (id: string, type: Operation["type"]) => void;
}) {
  const { id, person, direction, status, source, intro, createdAt, hiddenAt, team, conversationId } = request;
  const timestamp = new Date(createdAt);
  const date = Number.isNaN(timestamp.valueOf()) ? null : timestamp.toLocaleDateString(undefined, { month: "short", day: "numeric" });

  return <li className="workspace-card connection-request">
    <Link className="connection-request-person" to={personPath(person.handle, slug)} state={{ from: "/requests" }}>
      <PersonAvatar name={person.name} photoUrl={person.photoUrl} />
      <div>
        <h3>{person.name}</h3>
        <p>@{person.handle} · <span className="connection-role">{person.role}</span></p>
      </div>
    </Link>
    <p className="connection-request-meta">
      {requestSources[source]}{team && <> · {team.name}</>}{date && <> · <time dateTime={createdAt}>{date}</time></>}
    </p>
    {intro && <p className="connection-request-intro">{intro}</p>}
    {status === "pending" && direction === "incoming" && <div className="workspace-actions">
      <button type="button" className="button primary" disabled={busy} onClick={() => onRespond(id, "accept")}>
        {busy && operation === "accept" ? "Accepting…" : "Accept"}
      </button>
      {!hiddenAt && <button type="button" className="button secondary" disabled={busy} onClick={() => onRespond(id, "hide")}>
        {busy && operation === "hide" ? "Hiding…" : "Not now"}
      </button>}
    </div>}
    {status === "pending" && direction === "outgoing" && <p>Waiting for a response.</p>}
    {status === "accepted" && conversationId && <Link className="button secondary" to={chatPath(conversationId, slug)}>Message</Link>}
  </li>;
}
