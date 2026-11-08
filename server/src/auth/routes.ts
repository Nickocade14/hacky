import { Router } from "express";
import mongoose, { Types } from "mongoose";
import { z } from "zod";
import { createSmtpMailer, type Mail, type Mailer } from "../email/mailer.js";
import { VERIFY_TTL_MINUTES, verifyEmailMail } from "../email/templates.js";
import { HttpError } from "../errors.js";
import { consumeAuthToken, issueAuthToken } from "../models/AuthToken.js";
import { ProfileModel } from "../models/Profile.js";
import { UserModel } from "../models/User.js";
import { hashPassword, registerBodySchema } from "../validation/auth.js";

const tokenBodySchema = z.object({ token: z.string().min(1).max(200) });
const emailBodySchema = z.object({ email: z.email().max(254).transform((value) => value.toLowerCase()) });

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

  return router;
}
