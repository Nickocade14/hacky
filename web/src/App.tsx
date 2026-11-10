import { createContext, useContext, useEffect, useState, type ReactNode } from "react";
import { Link, Navigate, Route, Routes, useLocation } from "react-router-dom";
import { AuthShell, Notice, PageHeading } from "./components";
import { ForgotPasswordPage, LoginPage, RegisterPage, VerifyPage } from "./AuthPages";
import { ResetLinkPage } from "./AuthLinkPages";
import { SearchPage } from "./SearchPage";
import { api, ApiClientError } from "./lib/api";
import { clearSession, readSession, saveSession } from "./lib/session";
import type { LoginResult, Me } from "./lib/contracts";

type AuthState = {
  session: ReturnType<typeof readSession>;
  me: Me | null;
  setMe: (me: Me) => void;
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
  function signOut() { clearSession(); setSession(null); setMe(null); }
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
    document.title = `Hacky · ${pathname === "/register" ? "Create account" : pathname === "/verify" ? "Verify email" : pathname === "/forgot-password" || pathname === "/reset" ? "Reset password" : pathname === "/app" ? "Your account" : pathname === "/search" ? "Find people" : "Log in"}`;
    document.querySelector<HTMLElement>("h1")?.focus();
  }, [pathname]);
  return null;
}

function AccountPage({ search = false }: { search?: boolean }) {
  const { session, me, setMe, signOut } = useAuth();
  const [problem, setProblem] = useState<string | null>(null);
  const [retry, setRetry] = useState(0);
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
  }, [session?.token, me, retry]);
  if (!session) return <Navigate to="/login" replace />;
  if (search && me) return <SearchPage events={me.events} onExpired={signOut} />;
  return <><PageHeading eyebrow="YOUR NEXT CHAPTER" title={me ? `You’re in, ${me.profile.name.split(" ")[0]}.` : "Welcome back."}>A big idea starts with a connection. Welcome to Hacky.</PageHeading>
    {!me && !problem && <p role="status">Loading your account…</p>}
    {problem && <><Notice error>{problem}</Notice><button className="button secondary" onClick={() => setRetry(retry + 1)}>Try again</button></>}
    {me && <div className="account-card"><span className="account-avatar" aria-hidden="true">{me.profile.name.slice(0, 1).toUpperCase()}</span><h2>{me.profile.name}</h2><p>@{me.profile.handle}</p><div className="account-events"><span className="eyebrow">YOUR EVENTS</span>{me.events.length ? me.events.map(event => <div className="account-event" key={event.slug}><strong>{event.name}</strong><span>{event.role}</span></div>) : <p>No events yet. Your organizer can help you join.</p>}</div></div>}
    {me && <Link className="button primary" to="/search">Find people</Link>}
    <button className="button secondary" type="button" onClick={signOut}>Sign out</button></>;
}

function Pages() {
  const auth = useAuth();
  return <AuthShell><RouteFocus /><Routes>
    <Route path="/" element={<Navigate to={auth.session ? "/app" : "/login"} replace />} />
    <Route path="/login" element={auth.session ? <Navigate to="/app" replace /> : <LoginPage />} />
    <Route path="/register" element={auth.session ? <Navigate to="/app" replace /> : <RegisterPage />} />
    <Route path="/verify" element={<VerifyPage />} />
    <Route path="/forgot-password" element={<ForgotPasswordPage />} />
    <Route path="/reset" element={<ResetLinkPage />} />
    <Route path="/app" element={<AccountPage />} />
    <Route path="/search" element={<AccountPage search />} />
    <Route path="*" element={<><PageHeading eyebrow="LET’S GET YOU BACK" title="This page wandered off.">Head back to Hacky to find your people.</PageHeading><Link className="button primary" to="/">Back to Hacky</Link></>} />
  </Routes></AuthShell>;
}

export function App() { return <AuthProvider><Pages /></AuthProvider>; }
