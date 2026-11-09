import { createHmac, randomInt, timingSafeEqual } from "node:crypto";
import type { Model } from "mongoose";
import { HttpError } from "../errors.js";
import { secret } from "./jwt.js";

// Emailed 6-digit codes for sign-up and password reset.
// A code lasts CODE_TTL_MINUTES and allows MAX_CODE_TRIES guesses, so guessing
// one of the million codes has a 1 in 200,000 chance before it is deleted.
export const CODE_TTL_MINUTES = 10;
export const MAX_CODE_TRIES = 5;

export type CodePurpose = "sign-up" | "reset-password";

export const newCode = () => randomInt(0, 1_000_000).toString().padStart(6, "0");

export const codeExpiry = () => new Date(Date.now() + CODE_TTL_MINUTES * 60_000);

// Keyed with JWT_SECRET, so a leaked database alone can't be brute-forced
// back to codes. The purpose and email are part of the input, so a code only
// works for the flow and address it was sent for.
export function hashCode(purpose: CodePurpose, email: string, code: string): string {
  return createHmac("sha256", secret()).update(`${purpose}:${email}:${code}`).digest("hex");
}

export const invalidCode = () =>
  new HttpError(400, "invalid_code", "That code is wrong or expired. Check the email or ask for a new code.");

type CodeDoc = { _id: unknown; codeHash: string; tries: number };

// Counts the try before comparing, in one atomic update, so parallel requests
// still get at most MAX_CODE_TRIES guesses. Returns the document (with
// codeHash and the extra fields asked for) when the code matches, otherwise
// null. A wrong last try deletes the document. The caller deletes it with
// { _id, codeHash } when it uses the code, so a code works once.
export async function spendCodeTry<T extends CodeDoc>(model: Model<any>, filter: Record<string, unknown>, codeHash: string, select = ""): Promise<T | null> {
  const doc = await model.findOneAndUpdate(
    { ...filter, expiresAt: { $gt: new Date() }, tries: { $lt: MAX_CODE_TRIES } },
    { $inc: { tries: 1 } },
    { new: true },
  ).select(`+codeHash ${select}`.trim()).lean<T>();
  if (!doc) return null;
  const expected = Buffer.from(codeHash, "hex");
  const stored = Buffer.from(doc.codeHash, "hex");
  if (expected.length === stored.length && timingSafeEqual(expected, stored)) return doc;
  if (doc.tries >= MAX_CODE_TRIES) await model.deleteOne({ _id: doc._id, codeHash: doc.codeHash });
  return null;
}

// Upserts the one code document for `filter`. Two first-time upserts can race
// to insert; the loser retries against the winner's row.
export async function saveCode(model: Model<any>, filter: Record<string, unknown>, set: Record<string, unknown>): Promise<void> {
  const write = () => model.updateOne(filter, { $set: { ...set, tries: 0, expiresAt: codeExpiry() } }, { upsert: true });
  try {
    await write();
  } catch (error) {
    if ((error as { code?: number }).code !== 11000) throw error;
    await write();
  }
}
