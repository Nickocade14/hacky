import { createContext, useCallback, useContext, useEffect, useState, type Dispatch, type ReactNode, type SetStateAction } from "react";
import { Link, Navigate, Outlet, Route, Routes, useLocation, useOutletContext, useSearchParams } from "react-router-dom";
import { AuthShell, Notice, PageHeading } from "./components";
import { ForgotPasswordPage, LoginPage, RegisterPage, VerifyPage } from "./AuthPages";
import { ResetLinkPage } from "./AuthLinkPages";
import { SearchPage } from "./SearchPage";
import { HackyPage } from "./HackyPage";
import { HomePage } from "./HomePage";
import { MyProfilePage } from "./MyProfilePage";
import { PersonProfilePage } from "./PersonProfilePage";
import { RequestsPage } from "./RequestsPage";
import { PageScroll, SignedInShell, type SignedInContext } from "./SignedInShell";
import { api, ApiClientError } from "./lib/api";
import { clearSession, readSession, saveSession } from "./lib/session";
import type { LoginResult, Me } from "./lib/contracts";

type AuthState = {
  session: ReturnType<typeof readSession>;
  me: Me | null;
  setMe: Dispatch<SetStateAction<Me | null>>;
  signIn: (result: LoginResult) => void;
  signOut: () => void;
};
const AuthContext = createContext<AuthState | null>(null);
export function useAuth() {
  const auth = useContext(AuthContext);
  if (!auth) throw new Error("Auth provider is missing");
  return auth;
}

function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState(readSession);
  const [me, setMe] = useState<Me | null>(null);
  const signOut = useCallback(() => { clearSession(); setSession(null); setMe(null); }, []);
  useEffect(() => {
    if (!session) return;
    const remaining = Date.parse(session.expiresAt) - Date.now();
    const timer = window.setTimeout(signOut, Math.min(Math.max(remaining, 0), 2_147_483_647));
    return () => window.clearTimeout(timer);
  }, [session]);
  useEffect(() => {
    function syncSession(event: StorageEvent) {
      const next = readSession();
      if (next?.token === session?.token) return;
      setMe(null);
      setSession(next);
    }
    window.addEventListener("storage", syncSession);
    return () => window.removeEventListener("storage", syncSession);
  }, [session?.token]);
  return <AuthContext.Provider value={{ session, me, setMe, signOut, signIn(result) { saveSession(result); setSession(readSession()); setMe(result.me); } }}>{children}</AuthContext.Provider>;
}

function RouteFocus() {
  const { pathname } = useLocation();
  useEffect(() => {
    const titles: Record<string, string> = {
      "/register": "Create account", "/verify": "Verify email", "/forgot-password": "Reset password", "/reset": "Reset password",
      "/app": "Home", "/search": "Find people", "/hacky": "Hacky", "/profile": "My profile",
      "/requests": "Requests", "/chats": "Chats",
    };
    const title = titles[pathname] ?? (pathname.startsWith("/people/") ? "Person profile" : pathname.startsWith("/chats/") ? "Chat" : "Log in");
    document.title = `Hacky · ${title}`;
    document.querySelector<HTMLElement>("h1")?.focus();
  }, [pathname]);
  return null;
}

function SignedInLayout() {
  const { session, me, setMe, signOut } = useAuth();
  const [problem, setProblem] = useState<string | null>(null);
  const [retry, setRetry] = useState(0);
  const [selectedEvent, setSelectedEvent] = useState<string>();
  const [params, setParams] = useSearchParams();
  const requestedEvent = me?.events.find(item => item.slug === params.get("event"));
  useEffect(() => {
    if (requestedEvent) setSelectedEvent(requestedEvent.slug);
  }, [requestedEvent]);
  useEffect(() => {
    if (!session || me) return;
    const controller = new AbortController();
    setProblem(null);
    api.getMe(controller.signal).then(result => {
      if (!controller.signal.aborted) setMe(result);
    }).catch((error: unknown) => {
      if (controller.signal.aborted) return;
      if (error instanceof ApiClientError && error.status === 401) signOut();
      else setProblem(error instanceof Error ? error.message : "Couldn’t load your account. Try again.");
    });
    return () => controller.abort();
  }, [session, me, retry, setMe, signOut]);
  if (!session) return <Navigate to="/login" replace />;
  const event = requestedEvent ?? me?.events.find(item => item.slug === selectedEvent) ?? me?.events[0];
  function selectEvent(slug: string) {
    setSelectedEvent(slug);
    if (params.has("event")) {
      const next = new URLSearchParams(params);
      next.set("event", slug);
      setParams(next, { replace: true });
    }
  }
  const context: SignedInContext | null = me && {
    me, event, selectEvent, onExpired: signOut,
    onJoined(joined) {
      setMe(current => current?.profile.userId === me.profile.userId
        ? { ...current, events: [...current.events.filter(item => item.slug !== joined.slug), joined] }
        : current);
      selectEvent(joined.slug);
    },
    onProfileChanged(profile) {
      setMe(current => current?.profile.userId === profile.userId ? { ...current, profile } : current);
    },
  };
  return <SignedInShell me={me} event={event} signOut={signOut} onExpired={signOut}>
    {context ? <Outlet context={context} /> : <PageScroll>{problem ? <>
      <Notice error>{problem}</Notice>
      <button className="button secondary" type="button" onClick={() => setRetry(value => value + 1)}>Try again</button>
    </> : <p role="status">Loading your account…</p>}</PageScroll>}
  </SignedInShell>;
}

/** Passes the signed-in context on to the page inside the scrolling pane. */
function ScrolledPages() {
  return <PageScroll><Outlet context={useOutletContext()} /></PageScroll>;
}

function Pages() {
  const auth = useAuth();
  return <><RouteFocus /><Routes>
    <Route path="/" element={<Navigate to={auth.session ? "/hacky" : "/login"} replace />} />
    <Route element={<AuthShell><Outlet /></AuthShell>}>
      <Route path="/login" element={auth.session ? <Navigate to="/hacky" replace /> : <LoginPage />} />
      <Route path="/register" element={auth.session ? <Navigate to="/hacky" replace /> : <RegisterPage />} />
      <Route path="/verify" element={<VerifyPage />} />
      <Route path="/forgot-password" element={<ForgotPasswordPage />} />
      <Route path="/reset" element={<ResetLinkPage />} />
      <Route path="*" element={<><PageHeading eyebrow="LET’S GET YOU BACK" title="This page wandered off.">Head back to Hacky to find your people.</PageHeading><Link className="button primary" to="/">Back to Hacky</Link></>} />
    </Route>
    <Route element={<SignedInLayout />}>
      {/* Hacky stays on screen while Chats (the side panel) lists or opens a conversation. */}
      <Route element={<HackyPage />}>
        <Route path="/hacky" element={null} />
        <Route path="/chats" element={null} />
        <Route path="/chats/:conversationId" element={null} />
      </Route>
      <Route element={<ScrolledPages />}>
        <Route path="/app" element={<HomePage />} />
        <Route path="/search" element={<SearchPage />} />
        <Route path="/people/:handle" element={<PersonProfilePage />} />
        <Route path="/requests" element={<RequestsPage />} />
        <Route path="/profile" element={<MyProfilePage />} />
      </Route>
    </Route>
  </Routes></>;
}

export function App() { return <AuthProvider><Pages /></AuthProvider>; }
