import { useEffect, useState } from "react";
import { Link, useLocation } from "react-router-dom";
import { Field, Notice } from "./components";
import { PersonAvatar, useSignedIn } from "./SignedInShell";
import { api, ApiClientError } from "./lib/api";
import { personPath } from "./lib/connections";
import type { SearchQuery, SearchResults } from "./lib/contracts";
import "./connections.css";

type Role = NonNullable<SearchQuery["role"]>;
const roles: Record<Role, string> = {
  hacker: "Hacker",
  mentor: "Mentor",
  sponsor: "Sponsor",
  organizer: "Organizer",
};

type Outcome = { key: string; results: SearchResults["results"] } | { key: string; error: string };

function Highlight({ text, query }: { text: string; query: string }) {
  const literal = query.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const parts = text.split(new RegExp("(" + literal + ")", "giu"));
  return <>{parts.map((part, index) => index % 2 === 1 ? <mark key={index}>{part}</mark> : part)}</>;
}

export function SearchPage() {
  const { me: { events }, event: selectedEvent, selectEvent, onExpired } = useSignedIn();
  const { state } = useLocation();
  const search = (state as { search?: { query?: unknown; role?: unknown } } | null)?.search;
  const [query, setQuery] = useState(typeof search?.query === "string" ? search.query : "");
  const [role, setRole] = useState<Role | "">(
    typeof search?.role === "string" && Object.hasOwn(roles, search.role) ? search.role as Role : "",
  );
  const [outcome, setOutcome] = useState<Outcome | null>(null);
  const [retry, setRetry] = useState(0);
  const event = selectedEvent?.slug ?? "";
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
    <header className="workspace-heading">
      <h1 tabIndex={-1}>Find people.</h1>
      <p>Search for teammates and mentors by name, handle, or skill.</p>
    </header>
    {!events.length ? <section className="workspace-card workspace-empty">
      <h2>Join an event first</h2>
      <p>People, chats and Hacky live inside a hackathon. Pick yours on Home.</p>
      <Link className="button primary" to="/app">Go to Home</Link>
    </section> : <>
      <div className="search-controls" role="search" aria-label="Find event participants">
        <div className="field">
          <label htmlFor="search-event">Event</label>
          <select id="search-event" value={event} onChange={(e) => selectEvent(e.target.value)}>
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
        {current.results.length > 0 && <ul className="workspace-list workspace-card workspace-matches" aria-label="Search results">
          {current.results.map(person => {
            const matchedSkills = new Set(person.matchedSkills.map(skill => skill.toLowerCase()));
            return <li className="connection-search-row" key={person.userId}>
              <Link className="workspace-match connection-search-result" to={personPath(person.handle, event)}
                state={{ search: { query, role } }} aria-label={person.name + " (@" + person.handle + ")"}>
                <PersonAvatar name={person.name} photoUrl={person.photoUrl} />
                <div>
                  <h2 aria-label={person.name}><Highlight text={person.name} query={q} /></h2>
                  <p>@<Highlight text={person.handle} query={q} /></p>
                  {person.skills.length > 0 && <p>
                    {person.skills.map((skill, index) => <span key={index}>
                      {index > 0 && ", "}{matchedSkills.has(skill.toLowerCase()) ? <mark>{skill}</mark> : skill}
                    </span>)}
                  </p>}
                </div>
                <span className="workspace-chip">{roles[person.role]}</span>
              </Link>
            </li>;
          })}
        </ul>}
      </>}
    </>}
  </>;
}
