import nodemailer from "nodemailer";

export interface Mail {
  to: string;
  subject: string;
  text: string;
  html: string;
}

// Routes depend on this interface, so tests can pass a fake that records mail.
export interface Mailer {
  send(mail: Mail): Promise<void>;
}

// SMTP from server/.env (Brevo in production). Without SMTP_HOST the mail is
// printed to the console, so local dev works without an email account.
export function createSmtpMailer(env: NodeJS.ProcessEnv = process.env): Mailer {
  if (!env.SMTP_HOST) {
    return {
      async send(mail) {
        console.log(`[mail] SMTP_HOST is not set. Mail to ${mail.to}: ${mail.subject}\n${mail.text}`);
      },
    };
  }
  const port = Number(env.SMTP_PORT ?? 587);
  const transport = nodemailer.createTransport({
    host: env.SMTP_HOST,
    port,
    secure: port === 465,
    auth: env.SMTP_USER ? { user: env.SMTP_USER, pass: env.SMTP_PASS } : undefined,
  });
  const from = env.MAIL_FROM ?? "Hacky <no-reply@hackymatch.me>";
  return {
    async send(mail) {
      await transport.sendMail({ from, ...mail });
    },
  };
}
