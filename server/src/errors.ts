import type { ErrorRequestHandler } from "express";
import mongoose from "mongoose";
import { ZodError } from "zod";

// Throw these from routes: throw new HttpError(404, "not_found", "Profile not found").
export class HttpError extends Error {
  constructor(
    public status: number,
    public code: string,
    message: string,
  ) {
    super(message);
  }
}

export const errorHandler: ErrorRequestHandler = (error, _req, res, next) => {
  if (res.headersSent) {
    next(error);
    return;
  }
  if (error instanceof HttpError) {
    res.status(error.status).json({ error: { code: error.code, message: error.message } });
    return;
  }
  if (error instanceof ZodError) {
    res.status(400).json({ error: { code: "invalid_input", message: "Invalid input", details: error.issues } });
    return;
  }
  if (error instanceof mongoose.Error.ValidationError) {
    const details = Object.values(error.errors).map((entry) => ({ path: entry.path, message: entry.message }));
    res.status(400).json({ error: { code: "invalid_input", message: "Invalid input", details } });
    return;
  }
  if (error instanceof mongoose.Error.CastError) {
    res.status(400).json({ error: { code: "invalid_id", message: `Invalid ${error.path}` } });
    return;
  }
  if (error?.code === 11000) {
    const keys = Object.keys(error.keyPattern ?? {});
    const code = keys.length === 1 && keys[0] === "email" ? "email_taken"
      : keys.length === 1 && keys[0] === "handle" ? "handle_taken" : "conflict";
    const message = code === "email_taken" ? "Email already taken"
      : code === "handle_taken" ? "Handle already taken" : "Already exists";
    res.status(409).json({ error: { code, message } });
    return;
  }
  if (error?.type === "entity.too.large") {
    res.status(413).json({ error: { code: "payload_too_large", message: "Request body exceeds 100 KB" } });
    return;
  }
  if (error?.type === "entity.parse.failed") {
    res.status(400).json({ error: { code: "invalid_json", message: "Malformed JSON" } });
    return;
  }
  console.error(error);
  res.status(500).json({ error: { code: "internal", message: "Something went wrong" } });
};
