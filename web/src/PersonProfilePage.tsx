import { useEffect, useState, type FormEvent } from "react";
import { Link, useLocation, useNavigate, useParams } from "react-router-dom";
import { Notice, useFormAction } from "./components";
import { PersonAvatar, useSignedIn } from "./SignedInShell";
import { api, ApiClientError } from "./lib/api";
import { acceptConnectionRequest, blockPerson, chatPath, eventPath, getPerson, hideConnectionRequest, type ConnectionRequest, type PersonDetail } from "./lib/connections";
import { firstName, introProblem } from "./lib/hacky";
import "./connections.css";

type ProfileLoad = { person: PersonDetail } | { problem: string; missing: boolean };
type ProfileAction = "send" | "accept" | "hide" | "block";

const backLinks = { "/app": "Home", "/hacky": "Hacky", "/requests": "Requests" } as const;

function profileBackPath(from: unknown) {
  return from === "/app" || from === "/hacky" || from === "/requests" ? from : "/search";
}

export function PersonProfilePage() {
  const { me, event, onExpired } = useSignedIn();
  const { handle } = useParams<"handle">();
  const { state } = useLocation();
  const origin = state as { from?: unknown; search?: unknown } | null;
  const backTo = profileBackPath(origin?.from);

  if (!event || !handle) return <section className="workspace-card workspace-empty">
    <h1 tabIndex={-1}>{event ? "This profile isn’t available" : "Join an event first"}</h1>
    <Link className="button primary" to={event ? "/search" : "/app"}>{event ? "Go to People" : "Go to Home"}</Link>
  </section>;

  return <PersonProfile key={JSON.stringify([me.profile.userId, event.slug, handle])}
    slug={event.slug} handle={handle} selfId={me.profile.userId} backTo={backTo} onExpired={onExpired} search={origin?.search} />;
}

function PersonProfile({ slug, handle, selfId, backTo, onExpired, search }: {
  slug: string;
  handle: string;
  selfId: string;
  backTo: ReturnType<typeof profileBackPath>;
  onExpired: () => void;
  search?: unknown;
}) {
  const navigate = useNavigate();
  const [loaded, setLoaded] = useState<ProfileLoad | null>(null);
  const [retry, setRetry] = useState(0);
  const [intro, setIntro] = useState<string | null>(null);
  const [hidden, setHidden] = useState(false);
  const [confirmBlock, setConfirmBlock] = useState(false);
  const [message, setMessage] = useState("");
  const [operation, setOperation] = useState<ProfileAction>();
  const action = useFormAction();

  useEffect(() => {
    const controller = new AbortController();
    getPerson(slug, handle, controller.signal)
      .then(person => {
        if (!controller.signal.aborted) setLoaded({ person });
      })
      .catch((error: unknown) => {
        if (controller.signal.aborted) return;
        if (error instanceof ApiClientError && error.status === 401) {
          onExpired();
          return;
        }
        setLoaded({
          problem: error instanceof Error ? error.message : "Couldn’t load this profile.",
          missing: error instanceof ApiClientError && error.status === 404,
        });
      });
    return () => controller.abort();
  }, [slug, handle, retry, onExpired]);

  const backState = backTo === "/search" ? { search } : undefined;
  const back = <Link className="connection-back" to={eventPath(backTo, slug)} state={backState}>
    ← Back to {backTo === "/search" ? "People" : backLinks[backTo]}
  </Link>;

  if (!loaded) return <>{back}<p role="status">Loading profile…</p></>;
  if ("problem" in loaded) return <>
    {back}
    <section className="workspace-card workspace-empty">
      <h1 tabIndex={-1}>{loaded.missing ? "This profile isn’t available" : "Couldn’t load this profile"}</h1>
      {loaded.missing ? <p>They may have left the event.</p> : <>
        <Notice error>{loaded.problem}</Notice>
        <button type="button" className="button secondary" onClick={() => { setLoaded(null); setRetry(value => value + 1); }}>Try again</button>
      </>}
    </section>
  </>;

  const { person } = loaded;
  const { state: relationState, requestId, conversationId } = person.relation;
  const name = firstName(person.name);
  const isSelf = person.userId === selfId;

  function run(operation: ProfileAction, callback: (signal: AbortSignal) => Promise<void>) {
    if (action.busy) return;
    setOperation(operation);
    setMessage("");
    void action.run(async signal => {
      try {
        await callback(signal);
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

  function updateRelation(request: ConnectionRequest) {
    setLoaded({ person: { ...person, relation: {
      state: request.status === "accepted" ? "accepted" : "outgoing",
      requestId: request.id,
      conversationId: request.conversationId,
    } } });
    if (request.status === "accepted") setMessage(`You and ${name} are connected. Say hi!`);
  }

  function send(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const text = intro?.trim() ?? "";
    const problem = introProblem(text);
    if (problem) { action.setError(problem); return; }

    run("send", async signal => {
      const { request } = await api.sendRequest(slug, { toUserId: person.userId, intro: text, source: "profile" }, signal);
      if (signal.aborted) return;
      updateRelation(request);
      setIntro(null);
    });
  }

  function accept(id: string) {
    run("accept", async signal => {
      const { request } = await acceptConnectionRequest(id, signal);
      if (!signal.aborted) updateRelation(request);
    });
  }

  function hide(id: string) {
    run("hide", async signal => {
      await hideConnectionRequest(id, signal);
      if (signal.aborted) return;
      setHidden(true);
      setMessage(`Hidden. ${name} isn’t told.`);
    });
  }

  function block() {
    run("block", async signal => {
      await blockPerson(person.userId, signal);
      if (!signal.aborted) navigate(eventPath(backTo, slug), { replace: true, state: backState });
    });
  }

  function connectionActions() {
    if (confirmBlock) return <>
      <p>Block {name}? They won’t be told, and your chat disappears for both of you.</p>
      <div className="workspace-actions">
        <button type="button" className="button primary connection-danger" disabled={action.busy} onClick={block}>
          {action.busy ? "Blocking…" : "Block"}
        </button>
        <button type="button" className="button secondary" disabled={action.busy}
          onClick={() => { action.setError(null); setConfirmBlock(false); }}>Cancel</button>
      </div>
    </>;

    if (isSelf) return <Link className="button primary" to="/profile">Edit my profile</Link>;

    if (relationState === "accepted") return conversationId
      ? <Link className="button primary" to={chatPath(conversationId, slug)}>Message {name}</Link>
      : <p>You’re connected.</p>;

    if (relationState === "outgoing") return <>
      <p><strong>Request sent.</strong> Waiting for {name} to accept.</p>
    </>;

    if (relationState === "incoming") return <>
      <p>{name} wants to connect with you.</p>
      {requestId && <div className="workspace-actions">
        <button type="button" className="button primary" disabled={action.busy}
          onClick={() => accept(requestId)}>{action.busy && operation === "accept" ? "Accepting…" : "Accept"}</button>
        {!hidden && <button type="button" className="button secondary" disabled={action.busy}
          onClick={() => hide(requestId)}>{action.busy && operation === "hide" ? "Hiding…" : "Not now"}</button>}
      </div>}
    </>;

    if (intro === null) return <button type="button" className="button primary" onClick={() => setIntro("")}>
      Connect with {name}
    </button>;

    return <form className="connection-intro" aria-label={"Connect with " + name} onSubmit={send}>
      <label htmlFor="profile-intro">Say why you’d like to connect</label>
      <textarea id="profile-intro" value={intro} maxLength={500} rows={3}
        placeholder={"Hi " + name + "! I’m building…"} onChange={event => setIntro(event.target.value)} />
      <div className="workspace-row">
        <div className="workspace-actions">
          <button type="submit" className="button primary" disabled={action.busy || !intro.trim()}>
            {action.busy ? "Sending…" : "Send request"}
          </button>
          <button type="button" className="button secondary" disabled={action.busy}
            onClick={() => { setIntro(null); action.setError(null); }}>Cancel</button>
        </div>
        <span className="connection-count">{intro.trim().length}/500</span>
      </div>
    </form>;
  }

  return <>
    <div className="workspace-row">
      {back}
      {!isSelf && !confirmBlock && <button type="button" className="button secondary connection-danger"
        disabled={action.busy} onClick={() => { action.setError(null); setConfirmBlock(true); }}>
        Block
      </button>}
    </div>
    <section className="workspace-card workspace-identity connection-identity">
      <PersonAvatar name={person.name} photoUrl={person.photoUrl} />
      <h1 tabIndex={-1}>{person.name}</h1>
      <p>@{person.handle} · <span className="connection-role">{person.role}</span>{person.verified && person.role !== "hacker" && " · Verified"}</p>
      <ul className="workspace-chips" aria-label="Availability">
        <li className="connection-role">{person.availability}</li>
        {person.looking && <li>Looking for a team</li>}
      </ul>

      <div className="connection-profile-actions" aria-busy={action.busy}>
        {connectionActions()}
        {message && <Notice>{message}</Notice>}
        {action.error && <Notice error>{action.error}</Notice>}
      </div>
    </section>
    <ProfileDetails person={person} />
  </>;
}

function ProfileDetails({ person }: { person: PersonDetail }) {
  const about = person.bio || person.summary;
  const links = [
    { label: "GitHub", url: person.links.github },
    { label: "LinkedIn", url: person.links.linkedin },
    { label: "Website", url: person.links.website },
  ].filter(({ url }) => url?.startsWith("https://"));

  if (!about && !person.skills.length && !person.skillsWanted.length && !person.track
    && !person.idea && !person.interests.length && !links.length) return null;

  return <section className="workspace-card connection-profile-details" aria-label="Profile details">
    {about && <div><h2>About</h2><p>{about}</p></div>}
    <ProfileTags title="Skills" values={person.skills} />
    <ProfileTags title="Wants to learn" values={person.skillsWanted} />
    {person.track && <div><h2>Track</h2><p>{person.track}</p></div>}
    {person.idea && <div><h2>Idea</h2><p>{person.idea}</p></div>}
    <ProfileTags title="Interests" values={person.interests} />
    {links.length > 0 && <div>
      <h2>Links</h2>
      <ul className="workspace-list workspace-actions">
        {links.map(({ label, url }) => <li key={label}>
          <a href={url} target="_blank" rel="noreferrer" className="button secondary">{label}</a>
        </li>)}
      </ul>
    </div>}
  </section>;
}

function ProfileTags({ title, values }: { title: string; values: string[] }) {
  if (!values.length) return null;
  return <div>
    <h2>{title}</h2>
    <ul className="workspace-chips">{values.map((value, index) => <li key={`${value}-${index}`}>{value}</li>)}</ul>
  </div>;
}
