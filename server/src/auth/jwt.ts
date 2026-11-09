import type { RequestHandler } from "express";
import jwt from "jsonwebtoken";
import type { Types } from "mongoose";
import { HttpError } from "../errors.js";

const TOKEN_TTL_SECONDS = 7 * 24 * 60 * 60;

export function secret(): string {
  const value = process.env.JWT_SECRET;
  if (!value || value.length < 32) {
    throw new Error("JWT_SECRET must be set to at least 32 characters (see server/.env.example)");
  }
  return value;
}

// sub is the user id, which is also the Profile._id.
export function signToken(userId: Types.ObjectId): { token: string; expiresAt: string } {
  const token = jwt.sign({}, secret(), {
    algorithm: "HS256",
    subject: userId.toString(),
    expiresIn: TOKEN_TTL_SECONDS,
  });
  const { exp } = jwt.decode(token) as { exp: number };
  return { token, expiresAt: new Date(exp * 1000).toISOString() };
}

// Returns the user id from a valid token, or null.
export function verifyToken(token: string): string | null {
  try {
    const payload = jwt.verify(token, secret(), { algorithms: ["HS256"] });
    const sub = typeof payload === "object" ? payload.sub : undefined;
    return typeof sub === "string" && /^[a-f\d]{24}$/i.test(sub) ? sub : null;
  } catch (error) {
    if (error instanceof jwt.JsonWebTokenError) return null; // includes TokenExpiredError
    throw error;
  }
}

// Every route with user data goes after this. Sets res.locals.profileId,
// which search.ts and the other handlers read.
export const requireAuth: RequestHandler = (req, res, next) => {
  const match = /^Bearer ([^\s]+)$/.exec(req.get("authorization") ?? "");
  const userId = match ? verifyToken(match[1]) : null;
  if (!userId) throw new HttpError(401, "unauthorized", "Please log in again.");
  res.locals.profileId = userId;
  next();
};
