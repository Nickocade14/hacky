import bcrypt from "bcrypt";
import { Router } from "express";
import mongoose, { Types } from "mongoose";
import { z } from "zod";
import { createSmtpMailer, type Mail, type Mailer } from "../email/mailer.js";
import { resetCodeMail, signUpCodeMail } from "../email/templates.js";
import { HttpError } from "../errors.js";
import { AuthCodeModel } from "../models/AuthCode.js";
import { PendingSignupModel } from "../models/PendingSignup.js";
import { ProfileModel } from "../models/Profile.js";
import { UserModel } from "../models/User.js";
import { buildMe } from "../me.js";
import { hashPassword, registerBodySchema, resetCodeBodySchema, verifyCodeBodySchema } from "../validation/auth.js";
import { codeExpiry, hashCode, invalidCode, newCode, saveCode, spendCodeTry } from "./codes.js";
import { signToken } from "./jwt.js";
import { authRateLimit } from "./rateLimit.js";

const emailBodySchema = z.object({ email: z.email().max(254).transform((value) => value.toLowerCase()) });

// `login` is the email or the username; `email` is the old field name.
const loginBodySchema = z.object({
  login: z.string().trim().min(1).max(254).optional(),
  email: z.string().trim().min(1).max(254).optional(),
  password: z.string().min(1).max(200),
}).transform(({ login, email, password }, ctx) => {
  const value = login ?? email;
  if (!value) {
    ctx.addIssue({ code: "custom", path: ["login"], message: "Enter your email or username" });
    return z.NEVER;
  }
  return { login: value.toLowerCase(), password };
});

// Usernames can't contain "@", so an "@" after the first character means an
// email. A leading "@" is just how usernames are shown.
async function findLoginUser(login: string) {
  const fields = "+passwordHash emailVerified";
  if (login.indexOf("@") > 0) return UserModel.findOne({ email: login }).select(fields).lean();
  const handle = login.replace(/^@/, "");
  if (!/^[a-z0-9_]{3,30}$/.test(handle)) return null;
  // Demo people have a Profile but no User, so they can't log in.
  const profile = await ProfileModel.findOne({ handle }).select("_id").lean();
  return profile ? UserModel.findById(profile._id).select(fields).lean() : null;
}

// bcrypt hash of a random string nobody knows (cost 12, like real hashes).
const DUMMY_HASH = "$2b$12$gBuKWijY0GDua/9hgQY.LueT42I0MOv4MNHhaO2838pT4ARoWqj/6";

const ok = { ok: true } as const;

// A mail failure is logged, not returned: the user can ask for another code.
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

// Same body as POST /login, so the client goes straight in.
async function loginResult(userId: Types.ObjectId) {
  const { token, expiresAt } = signToken(userId);
  return { token, expiresAt, me: await buildMe(userId) };
}

type PendingDoc = { _id: Types.ObjectId; codeHash: string; tries: number; handle: string; name: string; passwordHash: string };

// Mounted at /api/auth. No JWT needed for any of these.
export function createAuthRouter({ mailer = createSmtpMailer() }: { mailer?: Mailer } = {}): Router {
  const router = Router();
  // Per client address, 15-minute windows (rateLimit.ts). Code checks share
  // the login limit; anything that sends an email has the tighter one.
  const limitLogin = authRateLimit(20);
  const limitEmailRequests = authRateLimit(5);

  // Saves nothing but a pending sign-up that expires in 10 minutes. The account
  // (User + Profile) is only created by /verify-email.
  router.post("/register", limitEmailRequests, async (req, res) => {
    const body = registerBodySchema.parse(req.body);
    if (await UserModel.exists({ email: body.email })) {
      throw new HttpError(409, "email_taken", "That email already has an account. Log in instead.");
    }
    if (await ProfileModel.exists({ handle: body.handle })) {
      throw new HttpError(409, "handle_taken", "That username is taken. Try another one.");
    }
    const code = newCode();
    await saveCode(PendingSignupModel, { email: body.email }, {
      handle: body.handle,
      name: body.name,
      passwordHash: await hashPassword(body.password),
      codeHash: hashCode("sign-up", body.email, code),
    });
    await sendQuietly(mailer, signUpCodeMail(body.email, body.name, code));
    res.json(ok);
  });

  router.post("/verify-email", limitLogin, async (req, res) => {
    const { email, code } = verifyCodeBodySchema.parse(req.body);
    const pending = await spendCodeTry<PendingDoc>(
      PendingSignupModel, { email }, hashCode("sign-up", email, code), "+passwordHash",
    );
    if (!pending) throw invalidCode();
    // User and Profile share the id; both are written or neither is, and the
    // pending sign-up is used up in the same transaction.
    const _id = new Types.ObjectId();
    try {
      await mongoose.connection.transaction(async (session) => {
        const used = await PendingSignupModel.deleteOne({ _id: pending._id, codeHash: pending.codeHash }, { session });
        if (used.deletedCount !== 1) throw invalidCode();
        await UserModel.create([{ _id, email, passwordHash: pending.passwordHash, emailVerified: true }], { session });
        await ProfileModel.create([{ _id, handle: pending.handle, name: pending.name }], { session });
      });
    } catch (error) {
      // Someone verified this email or username first (11000 → 409). This
      // sign-up can't finish, so it goes too and the user registers again.
      if ((error as { code?: number }).code === 11000) await PendingSignupModel.deleteOne({ _id: pending._id });
      throw error;
    }
    res.json(await loginResult(_id));
  });

  // Eligible requests return 200 whether or not a sign-up is waiting.
  router.post("/resend-verification", limitEmailRequests, async (req, res) => {
    const { email } = emailBodySchema.parse(req.body);
    const pending = await PendingSignupModel.findOne({ email, expiresAt: { $gt: new Date() } }).select("name").lean();
    if (pending) {
      const code = newCode();
      // No upsert: if the sign-up expired meanwhile, there's nothing to resend.
      const updated = await PendingSignupModel.updateOne(
        { _id: pending._id },
        { $set: { codeHash: hashCode("sign-up", email, code), tries: 0, expiresAt: codeExpiry() } },
      );
      if (updated.matchedCount === 1) await sendQuietly(mailer, signUpCodeMail(email, pending.name, code));
    }
    res.json(ok);
  });

  router.post("/login", limitLogin, async (req, res) => {
    const { login, password } = loginBodySchema.parse(req.body);
    const user = await findLoginUser(login);
    // Compare against a dummy hash when the account is unknown, so both cases take as long.
    const matches = await bcrypt.compare(password, user?.passwordHash ?? DUMMY_HASH);
    if (!user || !matches) throw new HttpError(401, "invalid_credentials", "Wrong email, username or password.");
    // Only accounts made before sign-up codes can be unverified.
    if (!user.emailVerified) {
      throw new HttpError(403, "email_not_verified", "Verify your email before logging in.");
    }
    res.json(await loginResult(user._id));
  });

  // Eligible requests return 200 whether or not the account exists.
  router.post("/forgot-password", limitEmailRequests, async (req, res) => {
    const { email } = emailBodySchema.parse(req.body);
    const user = await UserModel.findOne({ email }).select("_id").lean();
    if (user) {
      const code = newCode();
      await saveCode(AuthCodeModel, { user: user._id, kind: "reset-password" }, {
        codeHash: hashCode("reset-password", email, code),
      });
      await sendQuietly(mailer, resetCodeMail(email, await profileName(user._id), code));
    }
    res.json(ok);
  });

  router.post("/reset-password", limitLogin, async (req, res) => {
    const { email, code, password } = resetCodeBodySchema.parse(req.body);
    const user = await UserModel.findOne({ email }).select("_id").lean();
    if (!user) throw invalidCode();
    const found = await spendCodeTry(
      AuthCodeModel, { user: user._id, kind: "reset-password" }, hashCode("reset-password", email, code),
    );
    if (!found) throw invalidCode();
    const passwordHash = await hashPassword(password);
    await mongoose.connection.transaction(async (session) => {
      const used = await AuthCodeModel.deleteOne({ _id: found._id, codeHash: found.codeHash }, { session });
      if (used.deletedCount !== 1) throw invalidCode();
      // The code came by email, so this also proves the user owns the address.
      await UserModel.updateOne({ _id: user._id }, { $set: { passwordHash, emailVerified: true } }, { session });
    });
    res.json(await loginResult(user._id));
  });

  return router;
}
