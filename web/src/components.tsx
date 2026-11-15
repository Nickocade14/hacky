import { useEffect, useRef, useState, type InputHTMLAttributes, type ReactNode } from "react";
import { Link, NavLink, useLocation } from "react-router-dom";
import { ApiClientError } from "./lib/api";

export function Arrow({ back = false }: { back?: boolean }) {
  return <svg aria-hidden="true" viewBox="0 0 24 24" className={back ? "arrow back" : "arrow"}><path d="M4 12h16m-6-6 6 6-6 6" /></svg>;
}

// Same layout as the mobile app: one centered column. Log in and Create
// account open with the waving knit Hacky over the wordmark; the other
// account pages show the wordmark only.
export function AuthShell({ children }: { children: ReactNode }) {
  const { pathname } = useLocation();
  const mascot = pathname === "/login" || pathname === "/register";
  const wordmark = <Link className="brand" to="/login" aria-label="Hacky, log in"><span className="brand-mark" aria-hidden="true">h.</span>hacky<span className="brand-dot">.</span></Link>;
  return <main className="auth-layout">
    <div className="form-content">
      {mascot
        ? <div className="auth-mascot"><img src="/assets/mascots/hacky-knit-large.webp" alt="" width="186" height="192" />{wordmark}</div>
        : <div className="auth-wordmark">{wordmark}</div>}
      {children}
    </div>
  </main>;
}

export function AuthTabs() {
  return <nav className="auth-tabs" aria-label="Account"><NavLink to="/login">Log in</NavLink><NavLink to="/register">Create account</NavLink></nav>;
}

export function PageHeading({ eyebrow, title, children }: { eyebrow: string; title: string; children?: ReactNode }) {
  return <header className="page-heading"><span className="eyebrow">{eyebrow}</span><h1 tabIndex={-1}>{title}</h1>{children && <p>{children}</p>}</header>;
}

type FieldProps = InputHTMLAttributes<HTMLInputElement> & { label: string; hint?: string; prefix?: string };
export function Field({ label, hint, prefix, id, type = "text", ...props }: FieldProps) {
  const [visible, setVisible] = useState(false);
  const isPassword = type === "password";
  return <div className="field">
    <label htmlFor={id}>{label}</label>
    <div className="input-wrap">
      {prefix && <span className="input-prefix" aria-hidden="true">{prefix}</span>}
      <input {...props} id={id} type={isPassword && visible ? "text" : type} aria-describedby={hint ? `${id}-hint` : undefined} />
      {isPassword && <button className="password-toggle" type="button" onClick={() => setVisible(!visible)} aria-label={`${visible ? "Hide" : "Show"} ${label.toLowerCase()}`} aria-pressed={visible}>{visible ? "Hide" : "Show"}</button>}
    </div>
    {hint && <small id={`${id}-hint`}>{hint}</small>}
  </div>;
}

export function Notice({ children, error = false }: { children: ReactNode; error?: boolean }) {
  return <div className={`notice ${error ? "notice-error" : "notice-success"}`} role={error ? "alert" : "status"}>{children}</div>;
}

export function SubmitButton({ busy, children }: { busy: boolean; children: ReactNode }) {
  return <button className="button primary" type="submit" disabled={busy}>{busy ? <><span className="spinner" aria-hidden="true" /> Please wait…</> : <>{children}<Arrow /></>}</button>;
}

export function BackToLogin() {
  return <Link className="back-link" to="/login"><Arrow back /> Back to log in</Link>;
}

export function useFormAction() {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [code, setCode] = useState<string | undefined>();
  const pending = useRef<AbortController | null>(null);
  useEffect(() => () => pending.current?.abort(), []);
  async function run(action: (signal: AbortSignal) => Promise<void>) {
    if (pending.current && !pending.current.signal.aborted && busy) return;
    const controller = new AbortController();
    pending.current = controller;
    setBusy(true); setError(null); setCode(undefined);
    try { await action(controller.signal); }
    catch (caught) {
      if (!controller.signal.aborted) {
        setError(caught instanceof Error ? caught.message : "Something went wrong. Please try again.");
        setCode(caught instanceof ApiClientError ? caught.code : undefined);
      }
    } finally { if (!controller.signal.aborted) setBusy(false); }
  }
  return { busy, error, code, setError, run };
}

export function passwordProblem(value: string): string | null {
  if ([...value].length < 8) return "Use at least 8 characters for your password.";
  if (new TextEncoder().encode(value).length > 72) return "That password is too long. Try a shorter one.";
  return null;
}
