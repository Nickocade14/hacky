import { Schema, model, type InferSchemaType } from "mongoose";

// A sign-up waiting for its emailed code. No User or Profile exists until
// POST /api/auth/verify-email moves it over, so an unverified sign-up never
// keeps the email or the username. One per email: registering again replaces
// it. The TTL index deletes it when the code expires (within ~60 s), and the
// routes also check expiresAt themselves.
const pendingSignupSchema = new Schema(
  {
    email: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
      maxlength: 254,
      match: /^[^\s@]+@[^\s@]+\.[^\s@]+$/,
    },
    // Not unique here: the username is only claimed when the account is created.
    handle: { type: String, required: true, lowercase: true, trim: true, match: /^[a-z0-9_]{3,30}$/ },
    name: { type: String, required: true, trim: true, minlength: 1, maxlength: 80 },
    passwordHash: { type: String, required: true, select: false },
    codeHash: { type: String, required: true, select: false },
    tries: { type: Number, required: true, default: 0, min: 0 },
    expiresAt: { type: Date, required: true, expires: 0 },
  },
  { timestamps: true },
);

export type PendingSignup = InferSchemaType<typeof pendingSignupSchema>;
export const PendingSignupModel = model("PendingSignup", pendingSignupSchema);
