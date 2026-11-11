import { useEffect, useState, type ReactNode } from "react";
import { Link, matchPath, useLocation, useOutletContext } from "react-router-dom";
import type { Me, MyEvent } from "./lib/contracts";
import { eventPath } from "./lib/connections";
import { useMedia, useTheme } from "./lib/theme";
import { KnitAvatar } from "./workspace/KnitAvatar";
import { Sidebar, useInbox, waitingCount } from "./workspace/Sidebar";
import { Icon } from "./workspace/icons";
import "./workspace/workspace-shell.css";

export type SignedInContext = {
  me: Me;
  event: MyEvent | undefined;
  selectEvent: (slug: string) => void;
  onJoined: (event: MyEvent) => void;
  onProfileChanged: (profile: Me["profile"]) => void;
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

/** Pages outside the Hacky chat scroll inside the main pane, at reading width. */
export function PageScroll({ children }: { children: ReactNode }) {
  return <div className="hk-page workspace"><div className="workspace-content">{children}</div></div>;
}

// The mlhacky.com shell (seeko-codes/Hacky react/src/Conversation.jsx): Chats on the
// left, Hacky on the right. On a phone Chats slides over the page.
export function SignedInShell({ me, event, signOut, onExpired, children }: {
  me: Me | null;
  event: MyEvent | undefined;
  signOut: () => void;
  onExpired: () => void;
  children: ReactNode;
}) {
  const { pathname } = useLocation();
  const phone = useMedia("(max-width: 700px)");
  const { theme, toggle } = useTheme();
  const chatsRoute = pathname === "/chats" || pathname.startsWith("/chats/");
  const threadId = matchPath("/chats/:conversationId", pathname)?.params.conversationId;
  const [open, setOpen] = useState(() => !phone || chatsRoute);
  const { inbox, failed, reload } = useInbox(me ? event?.slug : undefined, onExpired);
  const waiting = waitingCount(inbox);

  // A chat link always shows the panel; on a phone any other page hides it.
  useEffect(() => {
    if (chatsRoute) setOpen(true);
    else if (phone) setOpen(false);
  }, [chatsRoute, phone, pathname]);

  const tab = pathname.startsWith("/people/") ? "/search" : pathname;
  const current = (path: string) => tab === path ? "page" as const : undefined;
  const slug = event?.slug;

  return <div className={`hk-app${open ? " open" : ""}${threadId ? " in-thread" : ""}`}>
    <aside id="hk-sidebar" className="hk-sidebar" aria-label="Chats" inert={!open}>
      {me && <Sidebar me={me} event={event} threadId={threadId} inbox={inbox} failed={failed} reload={reload}
        onClose={() => setOpen(false)} onExpired={onExpired} signOut={signOut} />}
    </aside>
    <button type="button" className="hk-backdrop" tabIndex={-1} aria-label="Back to the page" onClick={() => setOpen(false)} />
    <div className="hk-main">
      <header className="hk-header">
        <div className="hk-header-side">
          <button type="button" className={`hk-icon hk-chats-toggle${waiting ? " attention" : ""}`} aria-expanded={open} aria-controls="hk-sidebar"
            aria-label={waiting ? `Chats, ${waiting} waiting` : "Chats"} title="Chats" onClick={() => setOpen(value => !value)}>
            <Icon name="chat" />
          </button>
          <button type="button" className="hk-icon" aria-label={`Switch to ${theme === "dark" ? "light" : "dark"} mode`} onClick={toggle}>
            <Icon name={theme === "dark" ? "sun" : "moon"} />
          </button>
        </div>
        <Link className="hk-title" to={eventPath("/hacky", slug)} aria-current={current("/hacky")}>
          <span className="hk-title-name">Hacky</span>
          <span className="hk-title-event">{event?.name ?? "Find your people"}</span>
        </Link>
        <nav className="hk-header-side end" aria-label="Main navigation">
          <Link className="hk-icon" to={eventPath("/search", slug)} aria-label="People" title="People" aria-current={current("/search")}><Icon name="people" /></Link>
          <Link className="hk-icon" to="/app" aria-label="Home" title="Events and team" aria-current={current("/app")}><Icon name="events" /></Link>
          <Link className="hk-icon hk-me" to="/profile" aria-label="My profile" title="My profile" aria-current={current("/profile")}>
            {me ? <KnitAvatar person={me.profile} size={36} /> : <span className="hk-avatar" />}
          </Link>
        </nav>
      </header>
      {children}
    </div>
  </div>;
}
