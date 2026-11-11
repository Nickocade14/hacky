import { useState, type ReactNode } from "react";
import { Link, NavLink, useOutletContext } from "react-router-dom";
import type { Me, MyEvent } from "./lib/contracts";

export type SignedInContext = {
  me: Me;
  event: MyEvent | undefined;
  selectEvent: (slug: string) => void;
  onJoined: (event: MyEvent) => void;
  onExpired: () => void;
};

export function useSignedIn() {
  return useOutletContext<SignedInContext>();
}

export function PersonAvatar({ name, photoUrl }: { name: string; photoUrl?: string | null }) {
  const [failedUrl, setFailedUrl] = useState<string>();
  const initials = name.trim().split(/\s+/).slice(0, 2).map(part => Array.from(part)[0]).join("").toUpperCase();
  return <span className="workspace-avatar" aria-hidden="true">
    {photoUrl && photoUrl !== failedUrl
      ? <img src={photoUrl} alt="" onError={() => setFailedUrl(photoUrl)} />
      : initials}
  </span>;
}

const navigation = [
  { path: "/app", label: "Home", icon: "M3 10 12 3l9 7v10h-6v-6H9v6H3z" },
  { path: "/search", label: "People", icon: "M15 8a3 3 0 1 1-6 0 3 3 0 0 1 6 0ZM5 20v-2a4 4 0 0 1 4-4h6a4 4 0 0 1 4 4v2M3 12a3 3 0 0 0 2-5m16 5a3 3 0 0 1-2-5" },
  { path: "/profile", label: "Me", icon: "M16 8a4 4 0 1 1-8 0 4 4 0 0 1 8 0ZM4 20v-1a5 5 0 0 1 5-5h6a5 5 0 0 1 5 5v1" },
];

export function SignedInShell({ profile, event, signOut, children }: {
  profile?: Me["profile"];
  event?: MyEvent;
  signOut: () => void;
  children: ReactNode;
}) {
  return <div className="workspace">
    <header className="workspace-header">
      <div className="workspace-header-inner">
        <Link to="/app" className="workspace-brand" aria-label="Hacky home">hacky<span>.</span></Link>
        {event && <span className="workspace-header-event" title={event.name}>{event.name}</span>}
        <div className="workspace-account">
          {profile && <Link to="/profile" className="workspace-avatar-link" aria-label="My profile"><PersonAvatar name={profile.name} photoUrl={profile.photoUrl} /></Link>}
          <button type="button" className="workspace-sign-out" onClick={signOut}>Sign out</button>
        </div>
      </div>
    </header>
    <nav className="workspace-nav" aria-label="Main navigation">
      {navigation.map(({ path, label, icon }) => <NavLink key={path} to={path} end>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d={icon} /></svg>
        {label}
      </NavLink>)}
    </nav>
    <main className="workspace-content">{children}</main>
  </div>;
}

export function ProfileOverview() {
  const { me } = useSignedIn();
  const { profile, events } = me;
  return <>
    <section className="workspace-card workspace-identity">
      <PersonAvatar name={profile.name} photoUrl={profile.photoUrl} />
      <h1 tabIndex={-1}>{profile.name}</h1>
      <p>@{profile.handle}</p>
      {profile.bio && <p>{profile.bio}</p>}
    </section>
    <section className="workspace-card" aria-labelledby="profile-events">
      <h2 id="profile-events">Your events</h2>
      {events.length ? <ul className="workspace-list">
        {events.map(event => <li className="workspace-row" key={event.slug}>
          <strong>{event.name}</strong><span className="workspace-chip">{event.role}</span>
        </li>)}
      </ul> : <p>You haven’t joined an event yet. <Link to="/app">Find an event</Link>.</p>}
    </section>
  </>;
}
