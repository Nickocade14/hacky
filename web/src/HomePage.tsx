import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { Notice, useFormAction } from "./components";
import { PersonAvatar, useSignedIn } from "./SignedInShell";
import { api, ApiClientError } from "./lib/api";
import type { EventInfo, EventMe, MyEvent } from "./lib/contracts";

const dateFormat = new Intl.DateTimeFormat(undefined, { dateStyle: "medium" });

function eventDates({ startsAt, endsAt }: EventInfo) {
  if (startsAt && endsAt) return dateFormat.formatRange(new Date(startsAt), new Date(endsAt));
  const date = startsAt ?? endsAt;
  return date ? dateFormat.format(new Date(date)) : "Dates coming soon";
}

function EventCard({ event, onExpired }: { event: MyEvent; onExpired: () => void }) {
  const [details, setDetails] = useState<{ info: EventInfo; membership: EventMe } | null>(null);
  const [error, setError] = useState<string>();
  const [retry, setRetry] = useState(0);
  const { slug } = event;

  useEffect(() => {
    const controller = new AbortController();
    const { signal } = controller;
    Promise.all([api.getEvent(slug, signal), api.getEventMe(slug, signal)])
      .then(([info, membership]) => { if (!signal.aborted) setDetails({ info, membership }); })
      .catch((failure: unknown) => {
        if (signal.aborted) return;
        if (failure instanceof ApiClientError && failure.status === 401) onExpired();
        else setError(failure instanceof Error ? failure.message : "Couldn’t load your event.");
      });
    return () => controller.abort();
  }, [slug, retry, onExpired]);

  return <section className="workspace-card" aria-labelledby="home-event">
    <div className="workspace-row">
      <span className="eyebrow">Your event</span><span className="workspace-chip">{event.role}</span>
    </div>
    <h2 id="home-event">{event.name}</h2>
    {!details && !error && <p role="status">Loading event details…</p>}
    {error && <>
      <Notice error>{error}</Notice>
      <button type="button" className="button secondary" onClick={() => { setError(undefined); setRetry(value => value + 1); }}>Try again</button>
    </>}
    {details && <>
      <p>{eventDates(details.info)}</p>
      {details.info.tracks.length > 0 && <ul className="workspace-chips" aria-label="Event tracks">
        {details.info.tracks.map(track => <li key={track}>{track}</li>)}
      </ul>}
      <dl className="workspace-event-status">
        <div className="workspace-row"><dt>Looking for a team</dt><dd>{details.membership.looking ? "Yes" : "No"}</dd></div>
        <div className="workspace-row"><dt>Availability</dt><dd className="workspace-chip">{details.membership.availability}</dd></div>
      </dl>
    </>}
  </section>;
}

function JoinEvents({ onJoined }: { onJoined: (event: MyEvent) => void }) {
  const { me, onExpired } = useSignedIn();
  const [events, setEvents] = useState<EventInfo[] | null>(null);
  const [error, setError] = useState<string>();
  const [retry, setRetry] = useState(0);
  const [joiningSlug, setJoiningSlug] = useState<string>();
  const joinAction = useFormAction();

  useEffect(() => {
    const controller = new AbortController();
    const { signal } = controller;
    api.listEvents(signal).then(result => { if (!signal.aborted) setEvents(result.events); })
      .catch((failure: unknown) => {
        if (signal.aborted) return;
        if (failure instanceof ApiClientError && failure.status === 401) onExpired();
        else setError(failure instanceof Error ? failure.message : "Couldn’t load events.");
      });
    return () => controller.abort();
  }, [retry, onExpired]);

  function join(event: EventInfo) {
    setJoiningSlug(event.slug);
    void joinAction.run(async signal => {
      try {
        const membership = await api.joinEvent(event.slug, signal);
        if (!signal.aborted) onJoined({ slug: event.slug, name: event.name, role: membership.role, verified: membership.verified });
      } catch (failure) {
        if (signal.aborted) return;
        if (failure instanceof ApiClientError && failure.status === 401) onExpired();
        else throw failure;
      }
    });
  }

  const available = events?.filter(event => !me.events.some(({ slug }) => slug === event.slug));
  return <section aria-label="Events to join" aria-busy={joinAction.busy}>
    {!events && !error && <p role="status">Loading events…</p>}
    {error && <>
      <Notice error>{error}</Notice>
      <button type="button" className="button secondary" onClick={() => { setError(undefined); setRetry(value => value + 1); }}>Try again</button>
    </>}
    {joinAction.error && <Notice error>{joinAction.error}</Notice>}
    {available?.length === 0 && <p>No events to join right now. Check back soon.</p>}
    {!!available?.length && <ul className="workspace-list workspace-event-list">
      {available.map(event => <li key={event.slug} className="workspace-card workspace-row">
        <div>
          <h2>{event.name}</h2>
          <p>{eventDates(event)}</p>
        </div>
        <button type="button" className="button primary" disabled={joinAction.busy} onClick={() => join(event)}>
          {joinAction.busy && joiningSlug === event.slug ? "Joining…" : "Join"}
        </button>
      </li>)}
    </ul>}
  </section>;
}

export function HomePage() {
  const { me, event, selectEvent, onJoined, onExpired } = useSignedIn();
  const [showJoin, setShowJoin] = useState(false);

  return <>
    {event ? <>
      <section className="workspace-identity">
        <PersonAvatar name={me.profile.name} photoUrl={me.profile.photoUrl} />
        <h1 tabIndex={-1}>{me.profile.name}</h1>
        <p>@{me.profile.handle}</p>
      </section>
      {me.events.length > 1 && <div className="field">
        <label htmlFor="home-event-selector">Event</label>
        <select id="home-event-selector" value={event.slug} onChange={change => selectEvent(change.target.value)}>
          {me.events.map(item => <option key={item.slug} value={item.slug}>{item.name}</option>)}
        </select>
      </div>}
      <EventCard key={event.slug} event={event} onExpired={onExpired} />
      <div className="workspace-actions">
        <Link className="button primary" to="/search">Find people</Link>
        <button type="button" className="button secondary" aria-expanded={showJoin} onClick={() => setShowJoin(value => !value)}>
          {showJoin ? "Hide other events" : "Join another event"}
        </button>
      </div>
    </> : <header className="workspace-heading">
      <h1 tabIndex={-1}>Pick your hackathon</h1>
      <p>Join an event to meet people, find a team and chat with Hacky.</p>
    </header>}
    {(!event || showJoin) && <JoinEvents onJoined={joined => { onJoined(joined); setShowJoin(false); }} />}
  </>;
}
