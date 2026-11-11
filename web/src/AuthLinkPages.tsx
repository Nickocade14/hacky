import type { FormEvent } from "react";
import { Link, useNavigate, useSearchParams } from "react-router-dom";
import { useAuth } from "./App";
import { BackToLogin, Field, Notice, PageHeading, passwordProblem, SubmitButton, useFormAction } from "./components";
import { api } from "./lib/api";

export function VerifyLinkPage({ token }: { token: string }) {
  const navigate = useNavigate();
  const action = useFormAction();
  const valid = token.length > 0 && token.length <= 200;
  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!valid) return;
    void action.run(async signal => {
      await api.verifyEmailLink(token, signal);
      navigate("/login", { replace: true, state: { notice: "Email verified. Log in to continue." } });
    });
  }
  return <>
    <BackToLogin />
    <div className="status-icon" aria-hidden="true">↗</div>
    <PageHeading eyebrow="ONE QUICK STEP" title="Make it official.">Verify your email to finish setting up your Hacky account.</PageHeading>
    {valid ? <form onSubmit={submit} aria-label="Verify email link" aria-busy={action.busy}>
      {action.error && <Notice error>{action.error}</Notice>}
      <SubmitButton busy={action.busy}>Verify my email</SubmitButton>
    </form> : <Notice error>This verification link is invalid.</Notice>}
    {(!valid || action.error) && <p className="code-actions">
      <Link className="inline-action" to="/verify" replace>Request a new email</Link>
      <Link className="inline-action" to="/forgot-password" replace>Reset your password</Link>
    </p>}
  </>;
}

export function ResetLinkPage() {
  const [params] = useSearchParams();
  const token = params.get("token") ?? "";
  const navigate = useNavigate();
  const auth = useAuth();
  const action = useFormAction();
  const valid = token.length > 0 && token.length <= 200;
  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!valid) return;
    const data = new FormData(event.currentTarget);
    const password = String(data.get("password") ?? "");
    const problem = passwordProblem(password);
    if (problem) { action.setError(problem); return; }
    if (password !== data.get("confirm")) { action.setError("Your passwords don’t match. Please try again."); return; }
    void action.run(async signal => {
      await api.resetPasswordLink(token, password, signal);
      auth.signOut();
      navigate("/login", { replace: true, state: { notice: "Password updated. Log in with your new password." } });
    });
  }
  return <>
    <BackToLogin />
    <div className="status-icon" aria-hidden="true">↺</div>
    <PageHeading eyebrow="A FRESH START" title="Choose a new password." />
    {valid ? <form onSubmit={submit} aria-label="Reset password with a link" aria-busy={action.busy}>
      <Field id="link-password" label="New password" type="password" name="password" autoComplete="new-password"
        minLength={8} maxLength={72} placeholder="Make it a good one" hint="At least 8 characters." required />
      <Field id="link-password-confirm" label="Confirm password" type="password" name="confirm" autoComplete="new-password" required />
      {action.error && <Notice error>{action.error}</Notice>}
      <SubmitButton busy={action.busy}>Save new password</SubmitButton>
    </form> : <Notice error>This reset link is missing or invalid.</Notice>}
    {(!valid || action.error) && <Link className="inline-action" to="/forgot-password" replace>Request a new email</Link>}
  </>;
}
