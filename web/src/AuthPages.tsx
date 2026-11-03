import { useState, type FormEvent } from "react";
import { Link, useLocation, useNavigate, useSearchParams } from "react-router-dom";
import { useAuth } from "./App";
import { AuthTabs, BackToLogin, Field, Notice, PageHeading, passwordProblem, SubmitButton, useFormAction } from "./components";
import { api } from "./lib/api";

const value = (data: FormData, key: string) => String(data.get(key) ?? "");
const emailValue = (data: FormData) => value(data, "email").trim().toLowerCase();

export function LoginPage() {
  const auth = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const action = useFormAction();
  const [email, setEmail] = useState("");
  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const data = new FormData(event.currentTarget);
    void action.run(async signal => { const result = await api.login({ email: emailValue(data), password: value(data, "password") }, signal); auth.signIn(result); navigate("/app", { replace: true }); });
  }
  const notice = (location.state as { notice?: string } | null)?.notice;
  return <><AuthTabs /><PageHeading eyebrow="GOOD TO SEE YOU" title="Welcome back." />
    {notice && <Notice>{notice}</Notice>}
    <form onSubmit={submit} aria-label="Log in" aria-busy={action.busy}>
      <Field id="login-email" label="Email address" name="email" type="email" autoComplete="email" placeholder="you@example.com" required maxLength={254} value={email} onChange={event => setEmail(event.target.value)} />
      <Field id="login-password" label="Password" name="password" type="password" autoComplete="current-password" placeholder="Your password" required />
      <div className="form-meta"><Link to="/forgot-password">Forgot password?</Link></div>
      {action.error && <Notice error>{action.error}</Notice>}
      {action.code === "email_not_verified" && <Link className="inline-action" to="/verify" state={{ email }}>Resend your verification email</Link>}
      <SubmitButton busy={action.busy}>Log in</SubmitButton>
    </form>
    <p className="form-switch">New around here? <Link to="/register">Create an account</Link></p>
  </>;
}

export function RegisterPage() {
  const navigate = useNavigate();
  const action = useFormAction();
  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const data = new FormData(event.currentTarget);
    const problem = passwordProblem(value(data, "password"));
    if (problem) { action.setError(problem); return; }
    const name = value(data, "name").trim();
    if (!name) { action.setError("Enter your name so your teammates know what to call you."); return; }
    const email = emailValue(data);
    void action.run(async signal => { await api.register({ name, handle: value(data, "handle").trim().toLowerCase(), email, password: value(data, "password") }, signal); navigate("/verify", { state: { email } }); });
  }
  return <><AuthTabs /><PageHeading eyebrow="YOUR PEOPLE ARE HERE" title="Let’s make it happen.">Create your account. Find your crew. Build something great.</PageHeading>
    <form onSubmit={submit} aria-label="Create account" aria-busy={action.busy}>
      <Field id="register-name" label="Your name" name="name" autoComplete="name" placeholder="What should we call you?" maxLength={80} required />
      <Field id="register-handle" label="Handle" name="handle" autoComplete="username" autoCapitalize="none" spellCheck={false} placeholder="your_handle" pattern="[a-z0-9_]{3,30}" minLength={3} maxLength={30} title="3–30 lowercase letters, numbers, or underscores" hint="3–30 lowercase letters, numbers, or underscores." required />
      <Field id="register-email" label="Email address" name="email" type="email" autoComplete="email" placeholder="you@example.com" maxLength={254} required />
      <Field id="register-password" label="Password" name="password" type="password" autoComplete="new-password" placeholder="Make it a good one" minLength={8} maxLength={72} hint="At least 8 characters. Up to 72 UTF-8 bytes." required />
      {action.error && <Notice error>{action.error}</Notice>}
      <SubmitButton busy={action.busy}>Create account</SubmitButton>
    </form>
    <p className="privacy-note">We’ll send a verification link to your inbox before you log in.</p><p className="form-switch">Already part of the crew? <Link to="/login">Log in</Link></p>
  </>;
}

function ResendVerification({ initialEmail = "" }: { initialEmail?: string }) {
  const action = useFormAction();
  const [sent, setSent] = useState(false);
  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); const data = new FormData(event.currentTarget);
    void action.run(async signal => { await api.resendVerification({ email: emailValue(data) }, signal); setSent(true); });
  }
  return <form onSubmit={submit} aria-label="Resend verification email" aria-busy={action.busy}><Field id="resend-email" label="Email address" type="email" name="email" autoComplete="email" defaultValue={initialEmail} placeholder="you@example.com" required maxLength={254} />{sent && <Notice>If this address has an unverified account, a new link is on its way. Check your spam folder too.</Notice>}{action.error && <Notice error>{action.error}</Notice>}<SubmitButton busy={action.busy}>Resend verification link</SubmitButton></form>;
}

export function VerifyPage() {
  const [params] = useSearchParams();
  const token = params.get("token");
  const location = useLocation();
  const email = (location.state as { email?: string } | null)?.email;
  const action = useFormAction();
  const [verified, setVerified] = useState(false);
  const [resending, setResending] = useState(!token);
  const validToken = Boolean(token && token.length <= 200);
  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!validToken) return;
    void action.run(async signal => { await api.verifyEmail({ token: token! }, signal); setVerified(true); window.history.replaceState(window.history.state, "", "/verify"); });
  }
  return <><BackToLogin /><div className="status-icon" aria-hidden="true">{verified ? "✓" : "↗"}</div><PageHeading eyebrow={verified ? "YOU’RE ALL SET" : "ONE QUICK STEP"} title={verified ? "Email verified." : token ? "Make it official." : "Check your inbox."}>{verified ? "Your email is verified. You’re ready to meet your people." : token ? "Verify your email to finish setting up your Hacky account." : email ? <>We sent a verification link to <strong>{email}</strong>. Open it to finish setting up your account.</> : "Open the verification link in your email, or request a new one below."}</PageHeading>
    {verified ? <Link className="button primary" to="/login">Continue to log in</Link> : <>
      {token && <form onSubmit={submit} aria-label="Verify email" aria-busy={action.busy}>{!validToken && <Notice error>This verification link is invalid. Request a new one below.</Notice>}{action.error && <Notice error>{action.error}</Notice>}{validToken && <SubmitButton busy={action.busy}>Verify my email</SubmitButton>}</form>}
      {resending ? <ResendVerification initialEmail={email} /> : <button className="text-button" type="button" onClick={() => setResending(true)}>Need a new link? Resend email</button>}
    </>}
    <p className="privacy-note">Can’t find the email? Take a quick look in your spam folder.</p>
  </>;
}

export function ForgotPasswordPage() {
  const action = useFormAction();
  const [sent, setSent] = useState(false);
  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); const data = new FormData(event.currentTarget);
    void action.run(async signal => { await api.forgotPassword({ email: emailValue(data) }, signal); setSent(true); });
  }
  return <><BackToLogin /><div className="status-icon" aria-hidden="true">↺</div><PageHeading eyebrow="IT HAPPENS TO THE BEST OF US" title={sent ? "Check your inbox." : "Forgot your password?"}>{sent ? "If an account exists for that email, a password reset link is on its way." : "No worries. We’ll send you a link to get back to your people."}</PageHeading>
    <form onSubmit={submit} aria-label="Request password reset" aria-busy={action.busy}><Field id="forgot-email" label="Email address" type="email" name="email" autoComplete="email" placeholder="you@example.com" required maxLength={254} />{sent && <Notice>Check your email and spam folder. You can request another link below if you need one.</Notice>}{action.error && <Notice error>{action.error}</Notice>}<SubmitButton busy={action.busy}>{sent ? "Send another link" : "Send reset link"}</SubmitButton></form>
  </>;
}

export function ResetPasswordPage() {
  const [params] = useSearchParams();
  const token = params.get("token");
  const validToken = Boolean(token && token.length <= 200);
  const action = useFormAction();
  const navigate = useNavigate();
  const auth = useAuth();
  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); const data = new FormData(event.currentTarget);
    const password = value(data, "password");
    const problem = passwordProblem(password);
    if (problem) { action.setError(problem); return; }
    if (password !== value(data, "confirm")) { action.setError("Your passwords don’t match. Please try again."); return; }
    void action.run(async signal => { await api.resetPassword({ token: token!, password }, signal); auth.signOut(); navigate("/login", { replace: true, state: { notice: "Password updated. Log in with your new password." } }); });
  }
  return <><BackToLogin /><div className="status-icon" aria-hidden="true">↺</div><PageHeading eyebrow="A FRESH START" title="New password, same you.">Choose a new password and get back to building.</PageHeading>
    {validToken ? <form onSubmit={submit} aria-label="Reset password" aria-busy={action.busy}><Field id="reset-password" label="New password" type="password" name="password" autoComplete="new-password" minLength={8} maxLength={72} placeholder="Your new password" hint="At least 8 characters. Up to 72 UTF-8 bytes." required /><Field id="reset-confirm" label="Confirm password" type="password" name="confirm" autoComplete="new-password" placeholder="Once more, just to be sure" required />{action.error && <Notice error>{action.error}</Notice>}<SubmitButton busy={action.busy}>Save new password</SubmitButton>{action.code === "invalid_token" && <Link className="inline-action" to="/forgot-password">Request a new reset link</Link>}</form> : <><Notice error>This reset link is missing or invalid. Request a new link to choose a password.</Notice><Link className="button primary" to="/forgot-password">Request a reset link</Link></>}
  </>;
}
