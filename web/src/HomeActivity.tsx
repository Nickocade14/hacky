import { useEffect, useState, type FormEvent } from "react";
import { Link } from "react-router-dom";
import { Field, Notice, SubmitButton, useFormAction } from "./components";
import { PersonAvatar, useSignedIn } from "./SignedInShell";
import { api, ApiClientError } from "./lib/api";
import { eventPath, listConnectionRequests, personPath } from "./lib/connections";
import type { SearchResults } from "./lib/contracts";
import type { components, operations } from "./lib/schema";

type MyTeam = components["schemas"]["MyTeam"];
type TeamResult = operations["getMyTeam"]["responses"][200]["content"]["application/json"];
type CreatedTeam = operations["createTeam"]["responses"][201]["content"]["application/json"];

export function HomeActivity({ slug, wantedSkills }: { slug: string; wantedSkills: string[] }) {
  const { onExpired } = useSignedIn();
  const [activity, setActivity] = useState<{ team: MyTeam | null; waiting: number } | null>(null);
  const [error, setError] = useState<string>();
  const [retry, setRetry] = useState(0);
  const [showCreate, setShowCreate] = useState(false);
  const [suggestions, setSuggestions] = useState<SearchResults["results"]>([]);
  const createAction = useFormAction();
  const eventApiPath = `/events/${encodeURIComponent(slug)}`;
  const skill = wantedSkills.map(value => value.trim()).find(value => value.length > 0 && value.length <= 100);

  useEffect(() => {
    const controller = new AbortController();
    const { signal } = controller;
    Promise.all([api.authenticated<TeamResult>(`${eventApiPath}/me/team`, { signal }), listConnectionRequests(slug, signal)])
      .then(([{ team }, requests]) => {
        if (signal.aborted) return;
        const waiting = requests.filter(request => request.direction === "incoming" && request.status === "pending" && !request.hiddenAt).length;
        setActivity({ team, waiting });
      })
      .catch((failure: unknown) => {
        if (signal.aborted) return;
        if (failure instanceof ApiClientError && failure.status === 401) onExpired();
        else setError(failure instanceof Error ? failure.message : "Couldn’t load your event activity.");
      });
    return () => controller.abort();
  }, [eventApiPath, slug, retry, onExpired]);

  useEffect(() => {
    if (!skill) return;
    const controller = new AbortController();
    const { signal } = controller;
    api.searchPeople({ event: slug, q: skill, limit: 3 }, signal)
      .then(result => { if (!signal.aborted) setSuggestions(result.results); })
      .catch((failure: unknown) => {
        if (!signal.aborted && failure instanceof ApiClientError && failure.status === 401) onExpired();
      });
    return () => controller.abort();
  }, [slug, skill, onExpired]);

  function createTeam(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const name = String(new FormData(event.currentTarget).get("name") ?? "").trim();
    if (!name) { createAction.setError("Give your team a name."); return; }
    void createAction.run(async signal => {
      try {
        const { id, size, maxSize, name: teamName } = await api.authenticated<CreatedTeam>(`${eventApiPath}/teams`, { method: "POST", body: { name }, signal });
        if (signal.aborted) return;
        setActivity(current => current && { ...current, team: { id, name: teamName, size, maxSize, isOwner: true } });
        setShowCreate(false);
      } catch (failure) {
        if (signal.aborted) return;
        if (failure instanceof ApiClientError && failure.status === 401) onExpired();
        else throw failure;
      }
    });
  }

  return <>
    <Link className="workspace-card workspace-shortcut workspace-hacky-shortcut" to={eventPath("/hacky", slug)}>
      <img src="/assets/mascots/hacky-knit.webp" alt="" />
      <div><h2>Ask Hacky</h2><p>Find teammates and mentors for your project.</p></div>
    </Link>
    <Link className="workspace-card workspace-shortcut" to={eventPath("/requests", slug)}>
      <h2>Requests</h2>{!!activity?.waiting && <span className="workspace-chip">{activity.waiting} new</span>}
    </Link>
    <section className="workspace-card" aria-labelledby="home-team">
      <h2 id="home-team">My team</h2>
      {!activity && !error && <p role="status">Loading your team…</p>}
      {error && <>
        <Notice error>{error}</Notice>
        <button className="button secondary" type="button" onClick={() => { setError(undefined); setRetry(value => value + 1); }}>Try again</button>
      </>}
      {activity && (activity.team ? <>
        <h3>{activity.team.name}</h3>
        <p>{activity.team.size} of {activity.team.maxSize} members{activity.team.isOwner && " · You lead this team"}</p>
      </> : showCreate ? <form onSubmit={createTeam} aria-label="Create a team">
        <Field id="home-team-name" label="Team name" name="name" maxLength={80} required />
        {createAction.error && <Notice error>{createAction.error}</Notice>}
        <div className="workspace-actions">
          <SubmitButton busy={createAction.busy}>Create team</SubmitButton>
          <button className="button secondary" type="button" disabled={createAction.busy} onClick={() => { createAction.setError(null); setShowCreate(false); }}>Cancel</button>
        </div>
      </form> : <>
        <p>You haven’t joined a team yet.</p>
        <button className="button secondary" type="button" onClick={() => setShowCreate(true)}>Create team</button>
      </>)}
    </section>
    <section className="workspace-card" aria-labelledby="home-suggestions">
      <h2 id="home-suggestions">People you might like</h2>
      {!skill && <p><Link to="/profile">Add skills you want to learn</Link> to see suggestions.</p>}
      {!!suggestions.length && <ul className="workspace-list">
        {suggestions.map(person => <li key={person.userId}>
          <Link className="workspace-match workspace-person-link" to={personPath(person.handle, slug)} state={{ from: "/app" }}>
            <PersonAvatar name={person.name} photoUrl={person.photoUrl} />
            <div><strong>{person.name}</strong><p>@{person.handle}</p></div>
            <span className="workspace-chip">{person.role}</span>
          </Link>
        </li>)}
      </ul>}
      {skill && !suggestions.length && <p>Use <Link to="/search">People</Link> to search your event.</p>}
    </section>
  </>;
}
