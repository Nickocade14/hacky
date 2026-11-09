import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { Arrow, Field, Notice, PageHeading } from "./components";
import { api, ApiClientError } from "./lib/api";
import type { Me, SearchQuery, SearchResults } from "./lib/contracts";

type Role = NonNullable<SearchQuery["role"]>;
const roles: Record<Role, string> = {
  hacker: "Hacker",
  mentor: "Mentor",
  sponsor: "Sponsor",
  organizer: "Organizer",
};

type Outcome = { key: string; results: SearchResults["results"] } | { key: string; error: string };

export function SearchPage({ events, onExpired }: { events: Me["events"]; onExpired: () => void }) {
  const [selectedEvent, setSelectedEvent] = useState("");
  const [query, setQuery] = useState("");
  const [role, setRole] = useState<Role | "">("");
  const [outcome, setOutcome] = useState<Outcome | null>(null);
  const [retry, setRetry] = useState(0);
  const event = events.find(({ slug }) => slug === selectedEvent)?.slug ?? events[0]?.slug ?? "";
  const q = query.trim();
  const key = JSON.stringify([event, q, role, retry]);
  const current = outcome?.key === key ? outcome : null;

  useEffect(() => {
    if (!event || !q) return;
    const controller = new AbortController();
    const timer = window.setTimeout(() => {
      api.searchPeople({ event, q, role: role || undefined }, controller.signal)
        .then(({ results }) => {
          if (!controller.signal.aborted) setOutcome({ key, results });
        })
        .catch((error: unknown) => {
          if (controller.signal.aborted) return;
          if (error instanceof ApiClientError && error.status === 401) onExpired();
          else setOutcome({ key, error: error instanceof Error ? error.message : "Search is unavailable. Try again." });
        });
    }, 300);
    return () => { window.clearTimeout(timer); controller.abort(); };
  }, [event, q, role, key, onExpired]);

  return <>
    <Link className="back-link" to="/app"><Arrow back /> Back to account</Link>
    <PageHeading eyebrow="YOUR EVENT" title="Find people.">Search for teammates and mentors by name, handle, or skill.</PageHeading>
    {!events.length ? <Notice>Your account needs an event membership to search. Ask your event organizer to help you join.</Notice> : <>
      <div className="search-controls" role="search" aria-label="Find event participants">
        <div className="field">
          <label htmlFor="search-event">Event</label>
          <select id="search-event" value={event} onChange={(e) => setSelectedEvent(e.target.value)}>
            {events.map(({ slug, name }) => <option key={slug} value={slug}>{name}</option>)}
          </select>
        </div>
        <Field id="people-search" type="search" label="Name, handle, or skill" value={query} maxLength={100} onChange={(e) => setQuery(e.target.value)} />
        <div className="field">
          <label htmlFor="search-role">Role</label>
          <select id="search-role" value={role} onChange={(e) => setRole(e.target.value as Role | "")}>
            <option value="">All roles</option>
            {Object.entries(roles).map(([value, label]) => <option key={value} value={value}>{label}</option>)}
          </select>
        </div>
      </div>
      {!q && <p role="status">Start typing to search your event.</p>}
      {q && !current && <p role="status">Searching…</p>}
      {current && "error" in current && <>
        <Notice error>{current.error}</Notice>
        <button className="button secondary" type="button" onClick={() => setRetry((value) => value + 1)}>Try again</button>
      </>}
      {current && "results" in current && <>
        <p role="status">{current.results.length ? `${current.results.length} ${current.results.length === 1 ? "match" : "matches"}` : "No matches found."}</p>
        {current.results.length > 0 && <ul className="search-results" aria-label="Search results">
          {current.results.map((person) => <li className="account-card search-result" key={person.userId}>
            <h2>{person.name}</h2>
            <p>@{person.handle} · {roles[person.role]}</p>
            {person.skills.length > 0 && <p>{person.skills.join(", ")}</p>}
          </li>)}
        </ul>}
      </>}
    </>}
  </>;
}
