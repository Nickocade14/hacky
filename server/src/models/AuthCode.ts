import { Schema, model, type InferSchemaType } from "mongoose";
import { AUTH_CODE_KINDS } from "./enums.js";

// Emailed 6-digit codes for an existing account (today: password reset).
// Only a keyed hash is stored (src/auth/codes.ts). One code per user and kind:
// asking again replaces it. tries counts guesses; the route deletes the code
// after the last allowed one. MongoDB's TTL index deletes expired codes, but
// only every ~60 s, so the routes also check expiresAt themselves.
const authCodeSchema = new Schema(
  {
    user: { type: Schema.Types.ObjectId, ref: "User", required: true },
    kind: { type: String, enum: AUTH_CODE_KINDS, required: true },
    codeHash: { type: String, required: true, select: false },
    tries: { type: Number, required: true, default: 0, min: 0 },
    expiresAt: { type: Date, required: true, expires: 0 },
  },
  { timestamps: true },
);

authCodeSchema.index({ user: 1, kind: 1 }, { unique: true });

export type AuthCode = InferSchemaType<typeof authCodeSchema>;
export const AuthCodeModel = model("AuthCode", authCodeSchema);
