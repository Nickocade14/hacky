import { createHash, randomBytes } from "node:crypto";
import { Schema, Types, model, type InferSchemaType } from "mongoose";
import { AUTH_TOKEN_KINDS } from "./enums.js";

// One-time tokens for email verification and password reset.
// Only a SHA-256 hash is stored; the raw token goes in the email link.
// MongoDB's TTL index deletes expired tokens, but only every ~60 s, so
// consumeAuthToken also checks expiresAt itself.
const authTokenSchema = new Schema(
  {
    user: { type: Schema.Types.ObjectId, ref: "User", required: true, index: true },
    kind: { type: String, enum: AUTH_TOKEN_KINDS, required: true },
    tokenHash: { type: String, required: true, unique: true },
    expiresAt: { type: Date, required: true, expires: 0 },
  },
  { timestamps: { createdAt: true, updatedAt: false } },
);

// Reissuing replaces the single token for this user and purpose.
authTokenSchema.index({ user: 1, kind: 1 }, { unique: true });

export type AuthToken = InferSchemaType<typeof authTokenSchema>;
export const AuthTokenModel = model("AuthToken", authTokenSchema);

type AuthTokenKind = (typeof AUTH_TOKEN_KINDS)[number];

const hashToken = (raw: string) => createHash("sha256").update(raw).digest("hex");

// Creates a token and returns the raw value to put in the email link.
// Any older token of the same kind for this user stops working.
export async function issueAuthToken(user: Types.ObjectId, kind: AuthTokenKind, ttlMinutes: number) {
  const expiresAt = new Date(Date.now() + ttlMinutes * 60_000);
  if (!Number.isFinite(ttlMinutes) || ttlMinutes <= 0 || !Number.isFinite(expiresAt.getTime())) {
    throw new RangeError("Token lifetime must be a positive, finite number of minutes");
  }
  const raw = randomBytes(32).toString("base64url");
  const replace = () => AuthTokenModel.findOneAndUpdate(
    { user, kind },
    { $set: { tokenHash: hashToken(raw), expiresAt } },
    { upsert: true, runValidators: true },
  );
  try {
    await replace();
  } catch (error) {
    // Two first-time upserts may race to insert. Retry against the winning row.
    const duplicate = error as { code?: number; keyPattern?: Record<string, number> };
    if (duplicate.code !== 11000 || !duplicate.keyPattern?.user || !duplicate.keyPattern?.kind) throw error;
    await replace();
  }
  return raw;
}

// Uses up a token: returns its user id, or null if it's wrong, used or expired.
export async function consumeAuthToken(raw: string, kind: AuthTokenKind) {
  const doc = await AuthTokenModel.findOneAndDelete({
    tokenHash: hashToken(raw),
    kind,
    expiresAt: { $gt: new Date() },
  });
  return doc ? doc.user : null;
}
