import { useState, type FormEvent } from "react";
import { Link, useLocation, useNavigate, useSearchParams } from "react-router-dom";
import { useAuth } from "./App";
import { VerifyLinkPage } from "./AuthLinkPages";
import { AuthTabs, BackToLogin, Field, Notice, PageHeading, passwordProblem, SubmitButton, useFormAction } from "./components";
import { api } from "./lib/api";

const value = (data: FormData, key: string) => String(data.get(key) ?? "");
const emailValue = (data: FormData) => value(data, "email").trim().toLowerCase();
const isCode = (code: string) => /^[0-9]{6}$/.test(code);
const codeError = "Enter the 6-digit code from the email.";

function CodeField({ id, code, onChange }: { id: string; code: string; onChange: (code: string) => void }) {
  return <Field id={id} label="Code" name="code" value={code} onChange={event => onChange(event.target.value)}
    inputMode="numeric" autoComplete="one-time-code" placeholder="123456" maxLength={6}
    hint="The code expires in 10 minutes." required />;
}

export function LoginPage() {
  const auth = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const action = useFormAction();
  const [attemptedEmail, setAttemptedEmail] = useState("");
  const notice = (location.state as { notice?: string } | null)?.notice;
  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const data = new FormData(event.currentTarget);
    const email = emailValue(data);
    setAttemptedEmail(email);
    void action.run(async signal => { const result = await api.login({ email, password: value(data, "password") }, signal); auth.signIn(result); navigate("/app", { replace: true }); });
  }
  return <><AuthTabs /><PageHeading eyebrow="GOOD TO SEE YOU" title="Welcome back." />
    {notice && <Notice>{notice}</Notice>}
    <form onSubmit={submit} aria-label="Log in" aria-busy={action.busy}>
      <Field id="login-email" label="Email address" name="email" type="email" autoComplete="email" placeholder="you@example.com" required maxLength={254} />
      <Field id="login-password" label="Password" name="password" type="password" autoComplete="current-password" placeholder="Your password" required />
      <div className="form-meta"><Link to="/forgot-password">Forgot password?</Link></div>
      {action.error && <Notice error>{action.error}</Notice>}
      {action.code === "email_not_verified" && <Link className="inline-action" to="/verify" state={{ email: attemptedEmail, delivery: "link" }}>Resend verification email</Link>}
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
    void action.run(async signal => {
      const delivery = await api.register({ name, handle: value(data, "handle").trim().toLowerCase(), email, password: value(data, "password") }, signal);
      navigate("/verify", { state: { email, delivery } });
    });
  }
  return <><AuthTabs /><PageHeading eyebrow="YOUR PEOPLE ARE HERE" title="Let’s make it happen.">Create your account. Find your crew. Build something great.</PageHeading>
    <form onSubmit={submit} aria-label="Create account" aria-busy={action.busy}>
      <Field id="register-name" label="Your name" name="name" autoComplete="name" placeholder="What should we call you?" maxLength={80} required />
      <Field id="register-handle" label="Username" prefix="@" name="handle" autoComplete="username" autoCapitalize="none" spellCheck={false} placeholder="your_handle" pattern="[a-z0-9_]{3,30}" minLength={3} maxLength={30} title="3–30 lowercase letters, numbers, or underscores" hint="3–30 lowercase letters, numbers, or underscores." required />
      <Field id="register-email" label="Email address" name="email" type="email" autoComplete="email" placeholder="you@example.com" maxLength={254} required />
      <Field id="register-password" label="Password" name="password" type="password" autoComplete="new-password" placeholder="Make it a good one" minLength={8} maxLength={72} hint="At least 8 characters. Up to 72 UTF-8 bytes." required />
      {action.error && <Notice error>{action.error}</Notice>}
      <SubmitButton busy={action.busy}>Create account</SubmitButton>
    </form>
    <p className="privacy-note">We’ll email you instructions to finish creating your account.</p><p className="form-switch">Already part of the crew? <Link to="/login">Log in</Link></p>
  </>;
}

export function VerifyPage() {
  const [params] = useSearchParams();
  const token = params.get("token");
  return token === null ? <VerifyInbox /> : <VerifyLinkPage key={token} token={token} />;
}

function VerifyInbox() {
  const location = useLocation();
  const navigate = useNavigate();
  const auth = useAuth();
  const action = useFormAction();
  const pending = location.state as { email?: string; delivery?: "link" | "code" } | null;
  const pendingEmail = pending?.email;
  const expectsLink = pending?.delivery === "link";
  const [code, setCode] = useState("");
  const [resent, setResent] = useState(false);
  const startOver = resent || action.code === "invalid_code" || action.code === "email_taken" || action.code === "handle_taken";

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = event.currentTarget;
    const email = pendingEmail ?? emailValue(new FormData(form));
    const submitter = (event.nativeEvent as SubmitEvent).submitter;

    if (expectsLink || (submitter instanceof HTMLButtonElement && submitter.value === "resend")) {
      const emailField = form.elements.namedItem("email");
      if (emailField instanceof HTMLInputElement && !emailField.reportValidity()) return;
      void action.run(async signal => {
        await api.resendVerification({ email }, signal);
        setCode("");
        setResent(true);
      });
      return;
    }

    const normalizedCode = code.trim();
    if (!isCode(normalizedCode)) { action.setError(codeError); return; }
    void action.run(async signal => {
      auth.signIn(await api.verifyEmail({ email, code: normalizedCode }, signal));
      navigate("/app", { replace: true });
    });
  }

  return <>
    <BackToLogin />
    <div className="status-icon" aria-hidden="true">↗</div>
    <PageHeading eyebrow="ONE QUICK STEP" title="Check your inbox.">
      {expectsLink
        ? <>Open the verification link emailed to <strong>{pendingEmail}</strong> to finish creating your account.</>
        : pending?.delivery === "code"
          ? <>We sent a 6-digit code to <strong>{pendingEmail}</strong>. Enter it to finish creating your account.</>
          : "Open the verification link in your email, or enter the 6-digit code you received."}
    </PageHeading>
    <form onSubmit={submit} aria-label="Verify email" aria-busy={action.busy}>
      {!pendingEmail && <Field id="verify-email" label="Email address" type="email" name="email" autoComplete="email" placeholder="you@example.com" required maxLength={254} />}
      {!expectsLink && <CodeField id="verify-code" code={code} onChange={setCode} />}
      {resent && !action.error && <Notice>If your sign-up is still active, check your inbox for a new email. Check your spam folder too.</Notice>}
      {action.error && <Notice error>{action.error}</Notice>}
      {startOver && <Link className="inline-action" to="/register">Back to create account</Link>}
      <SubmitButton busy={action.busy}>{expectsLink ? "Send a new email" : "Verify and continue"}</SubmitButton>
      {!expectsLink && <div className="code-actions">
        <button className="text-button" type="submit" value="resend" formNoValidate disabled={action.busy}>Send a new code</button>
      </div>}
    </form>
    {(expectsLink || resent) && <p><Link className="inline-action" to="/forgot-password">Reset your password</Link></p>}
    <p className="privacy-note">Can’t find the email? Take a quick look in your spam folder.</p>
  </>;
}

export function ForgotPasswordPage() {
  const navigate = useNavigate();
  const auth = useAuth();
  const action = useFormAction();
  const [email, setEmail] = useState<string | null>(null);
  const [code, setCode] = useState("");
  const [resent, setResent] = useState(false);

  function sendEmail(address: string, resend = false) {
    void action.run(async signal => {
      await api.forgotPassword({ email: address }, signal);
      setEmail(address);
      setCode("");
      setResent(resend);
    });
  }

  function reset(event: FormEvent<HTMLFormElement>, address: string) {
    event.preventDefault();
    const normalizedCode = code.trim();
    if (!isCode(normalizedCode)) { action.setError(codeError); return; }
    const password = value(new FormData(event.currentTarget), "password");
    const problem = passwordProblem(password);
    if (problem) { action.setError(problem); return; }
    void action.run(async signal => {
      auth.signIn(await api.resetPassword({ email: address, code: normalizedCode, password }, signal));
      navigate("/app", { replace: true });
    });
  }

  function changeEmail() {
    setEmail(null);
    setCode("");
    setResent(false);
    action.setError(null);
  }

  return <>
    <BackToLogin />
    <div className="status-icon" aria-hidden="true">↺</div>
    <PageHeading eyebrow="IT HAPPENS TO THE BEST OF US" title={email ? "Check your inbox." : "Forgot your password?"}>
      {email
        ? <>If an account exists for <strong>{email}</strong>, you’ll get an email. Open its reset link or enter its 6-digit code with your new password.</>
        : "No worries. We’ll email you instructions to get back to your people."}
    </PageHeading>
    {email ? <form onSubmit={event => reset(event, email)} aria-label="Reset password" aria-busy={action.busy}>
      <CodeField id="reset-code" code={code} onChange={setCode} />
      <Field id="reset-password" label="New password" type="password" name="password" autoComplete="new-password"
        minLength={8} maxLength={72} placeholder="Make it a good one" hint="At least 8 characters. Up to 72 UTF-8 bytes." required />
      {resent && !action.error && <Notice>If an account exists for this email, check your inbox for new instructions.</Notice>}
      {action.error && <Notice error>{action.error}</Notice>}
      <SubmitButton busy={action.busy}>Reset password</SubmitButton>
      <div className="code-actions">
        <button className="text-button" type="button" onClick={() => sendEmail(email, true)} disabled={action.busy}>Send a new code</button>
        <button className="text-button" type="button" onClick={changeEmail} disabled={action.busy}>Use a different email</button>
      </div>
    </form> : <form onSubmit={event => { event.preventDefault(); sendEmail(emailValue(new FormData(event.currentTarget))); }}
      aria-label="Request password reset" aria-busy={action.busy}>
      <Field id="forgot-email" label="Email address" type="email" name="email" autoComplete="email" placeholder="you@example.com" required maxLength={254} />
      {action.error && <Notice error>{action.error}</Notice>}
      <SubmitButton busy={action.busy}>Send email</SubmitButton>
    </form>}
  </>;
}
