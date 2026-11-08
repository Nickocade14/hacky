import bcrypt from "bcrypt";
import { Router } from "express";
import mongoose, { Types } from "mongoose";
import { z } from "zod";
import { createSmtpMailer, type Mail, type Mailer } from "../email/mailer.js";
import { RESET_TTL_MINUTES, VERIFY_TTL_MINUTES, resetPasswordMail, verifyEmailMail } from "../email/templates.js";
import { HttpError } from "../errors.js";
import { consumeAuthToken, issueAuthToken } from "../models/AuthToken.js";
import { ProfileModel } from "../models/Profile.js";
import { UserModel } from "../models/User.js";
import { buildMe } from "../me.js";
import { hashPassword, registerBodySchema, resetPasswordBodySchema } from "../validation/auth.js";
import { signToken } from "./jwt.js";

const tokenBodySchema = z.object({ token: z.string().min(1).max(200) });
const emailBodySchema = z.object({ email: z.email().max(254).transform((value) => value.toLowerCase()) });

const loginBodySchema = z.object({
  email: z.email().max(254).transform((value) => value.toLowerCase()),
  password: z.string().min(1).max(200),
});

// bcrypt hash of a random string nobody knows (cost 12, like real hashes).
const DUMMY_HASH = "$2b$12$gBuKWijY0GDua/9hgQY.LueT42I0MOv4MNHhaO2838pT4ARoWqj/6";

const ok = { ok: true } as const;

// The account already exists when we send, so a mail failure is logged, not
// returned: the user can ask for another link (resend / forgot password).
async function sendQuietly(mailer: Mailer, mail: Mail) {
  try {
    await mailer.send(mail);
  } catch (error) {
    console.error(`[mail] Could not send "${mail.subject}":`, error);
  }
}

async function profileName(userId: Types.ObjectId) {
  return (await ProfileModel.findById(userId).select("name").lean())?.name ?? "there";
}

// Mounted at /api/auth. No JWT needed for any of these.
export function createAuthRouter({ mailer = createSmtpMailer() }: { mailer?: Mailer } = {}): Router {
  const router = Router();

  router.post("/register", async (req, res) => {
    const body = registerBodySchema.parse(req.body);
    const passwordHash = await hashPassword(body.password);
    const _id = new Types.ObjectId();
    // User and Profile share the id; both are written or neither is.
    // A taken email or handle throws 11000, which errorHandler turns into 409.
    await mongoose.connection.transaction(async (session) => {
      await UserModel.create([{ _id, email: body.email, passwordHash }], { session });
      await ProfileModel.create([{ _id, handle: body.handle, name: body.name }], { session });
    });
    const token = await issueAuthToken(_id, "verify-email", VERIFY_TTL_MINUTES);
    await sendQuietly(mailer, verifyEmailMail(body.email, body.name, token));
    res.status(201).json(ok);
  });

  router.post("/verify-email", async (req, res) => {
    const { token } = tokenBodySchema.parse(req.body);
    const userId = await consumeAuthToken(token, "verify-email");
    if (!userId) throw new HttpError(400, "invalid_token", "This link is invalid or has expired. Request a new one.");
    await UserModel.updateOne({ _id: userId }, { $set: { emailVerified: true } });
    res.json(ok);
  });

  // Always 200, so it doesn't reveal which emails have accounts.
  router.post("/resend-verification", async (req, res) => {
    const { email } = emailBodySchema.parse(req.body);
    const user = await UserModel.findOne({ email }).select("_id emailVerified").lean();
    if (user && !user.emailVerified) {
      const token = await issueAuthToken(user._id, "verify-email", VERIFY_TTL_MINUTES);
      await sendQuietly(mailer, verifyEmailMail(email, await profileName(user._id), token));
    }
    res.json(ok);
  });

  router.post("/login", async (req, res) => {
    const { email, password } = loginBodySchema.parse(req.body);
    const user = await UserModel.findOne({ email }).select("+passwordHash emailVerified").lean();
    // Compare against a dummy hash when the email is unknown, so both cases take as long.
    const matches = await bcrypt.compare(password, user?.passwordHash ?? DUMMY_HASH);
    if (!user || !matches) throw new HttpError(401, "invalid_credentials", "Wrong email or password.");
    if (!user.emailVerified) {
      throw new HttpError(403, "email_not_verified", "Verify your email before logging in. Check your inbox for the link.");
    }
    const { token, expiresAt } = signToken(user._id);
    res.json({ token, expiresAt, me: await buildMe(user._id) });
  });

  // Always 200, so it doesn't reveal which emails have accounts.
  router.post("/forgot-password", async (req, res) => {
    const { email } = emailBodySchema.parse(req.body);
    const user = await UserModel.findOne({ email }).select("_id").lean();
    if (user) {
      const token = await issueAuthToken(user._id, "reset-password", RESET_TTL_MINUTES);
      await sendQuietly(mailer, resetPasswordMail(email, await profileName(user._id), token));
    }
    res.json(ok);
  });

  router.post("/reset-password", async (req, res) => {
    const { token, password } = resetPasswordBodySchema.parse(req.body);
    const userId = await consumeAuthToken(token, "reset-password");
    if (!userId) throw new HttpError(400, "invalid_token", "This link is invalid or has expired. Request a new one.");
    // Opening the emailed link also proves the user owns the address.
    await UserModel.updateOne(
      { _id: userId },
      { $set: { passwordHash: await hashPassword(password), emailVerified: true } },
    );
    res.json(ok);
  });

  return router;
}
