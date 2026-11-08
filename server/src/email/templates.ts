import type { Mail } from "./mailer.js";

// Links open the web pages /verify and /reset (web/src/AuthPages.tsx).
const appUrl = () => (process.env.APP_URL ?? "http://localhost:5173").replace(/\/+$/, "");

const escapeHtml = (text: string) => text.replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);

function linkMail(to: string, subject: string, intro: string, button: string, url: string, footer: string): Mail {
  return {
    to,
    subject,
    text: `${intro}\n\n${url}\n\n${footer}`,
    html: `<div style="font-family:Lato,Arial,sans-serif;font-size:16px;line-height:1.5;color:#1f1f1f">
<p>${escapeHtml(intro)}</p>
<p><a href="${escapeHtml(url)}" style="display:inline-block;padding:12px 20px;border-radius:999px;background:#1f1f1f;color:#ffffff;text-decoration:none;font-weight:700">${escapeHtml(button)}</a></p>
<p style="color:#666;font-size:14px">${escapeHtml(footer)}</p>
</div>`,
  };
}

export const VERIFY_TTL_MINUTES = 24 * 60;
export const RESET_TTL_MINUTES = 60;

export function verifyEmailMail(to: string, name: string, token: string): Mail {
  return linkMail(
    to,
    "Verify your Hacky email",
    `Hi ${name}, welcome to Hacky! Verify your email to finish setting up your account.`,
    "Verify my email",
    `${appUrl()}/verify?token=${encodeURIComponent(token)}`,
    "This link works once and expires in 24 hours. If you didn't sign up for Hacky, you can ignore this email.",
  );
}

export function resetPasswordMail(to: string, name: string, token: string): Mail {
  return linkMail(
    to,
    "Reset your Hacky password",
    `Hi ${name}, someone asked to reset the password for your Hacky account.`,
    "Choose a new password",
    `${appUrl()}/reset?token=${encodeURIComponent(token)}`,
    "This link works once and expires in 1 hour. If you didn't ask for it, you can ignore this email.",
  );
}
