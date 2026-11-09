import { CODE_TTL_MINUTES } from "../auth/codes.js";
import type { Mail } from "./mailer.js";

// The code goes in the email; the user types it in the app or the web, which
// then logs them in. Colors and font follow the Hacky palette (web/src/theme.css).

const escapeHtml = (text: string) => text.replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);

function codeMail(to: string, subject: string, intro: string, code: string, footer: string): Mail {
  return {
    to,
    subject,
    text: `${intro}\n\n${code}\n\n${footer}`,
    html: `<div style="font-family:Lato,Arial,sans-serif;font-size:16px;line-height:1.5;color:#243247">
<p>${escapeHtml(intro)}</p>
<p style="font-size:32px;font-weight:700;letter-spacing:8px;margin:24px 0">${escapeHtml(code)}</p>
<p style="color:#606975;font-size:14px">${escapeHtml(footer)}</p>
</div>`,
  };
}

export function signUpCodeMail(to: string, name: string, code: string): Mail {
  return codeMail(
    to,
    `${code} is your Hacky code`,
    `Hi ${name}, welcome to Hacky! Enter this code to finish creating your account:`,
    code,
    `The code expires in ${CODE_TTL_MINUTES} minutes. If you didn't sign up for Hacky, you can ignore this email and nothing will be saved.`,
  );
}

export function resetCodeMail(to: string, name: string, code: string): Mail {
  return codeMail(
    to,
    `${code} is your Hacky reset code`,
    `Hi ${name}, enter this code to choose a new password for your Hacky account:`,
    code,
    `The code expires in ${CODE_TTL_MINUTES} minutes. If you didn't ask for it, you can ignore this email.`,
  );
}
