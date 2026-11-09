import type { RequestHandler } from "express";
import { HttpError } from "../errors.js";

const windowMs = 15 * 60_000;
const maxAddresses = 10_000;

export function authRateLimit(limit: number): RequestHandler {
  const hits = new Map<string, { count: number; resetAt: number }>();

  return (req, res, next) => {
    const now = performance.now();
    // Every window has the same length, so entries expire in insertion order.
    for (const [address, entry] of hits) {
      if (entry.resetAt > now) break;
      hits.delete(address);
    }

    const address = req.ip ?? req.socket.remoteAddress ?? "unknown";
    const entry = hits.get(address);
    if ((entry?.count ?? 0) >= limit || (!entry && hits.size >= maxAddresses)) {
      const resetAt = entry?.resetAt ?? hits.values().next().value?.resetAt ?? now + windowMs;
      res.set("Retry-After", String(Math.ceil((resetAt - now) / 1000)));
      throw new HttpError(429, "rate_limited", "Too many requests. Try again later.");
    }

    if (entry) entry.count += 1;
    else hits.set(address, { count: 1, resetAt: now + windowMs });
    next();
  };
}
