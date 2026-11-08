import express from "express";
import cors from "cors";
import { requireAuth } from "./auth/jwt.js";
import { createAuthRouter } from "./auth/routes.js";
import type { Mailer } from "./email/mailer.js";
import { errorHandler } from "./errors.js";
import { createEventsRouter } from "./events/routes.js";
import { createTeamsRouter } from "./events/teams.js";
import { createMeRouter } from "./me.js";
import { searchHandler } from "./search.js";

export interface AppOptions {
  mailer?: Mailer; // tests pass a fake that records mail
}

export function createApp({ mailer }: AppOptions = {}) {
  const app = express();
  const origins = (process.env.CORS_ORIGIN ?? "http://localhost:5173").split(",").map((origin) => origin.trim());
  app.use(cors({ origin: origins }));
  app.use(express.json({ limit: "100kb" }));

  app.get("/api/health", (_req, res) => {
    res.json({ ok: true });
  });

  app.use("/api/auth", createAuthRouter({ mailer }));
  // Everything below needs a JWT (Authorization: Bearer <token>).
  app.use("/api/me", requireAuth, createMeRouter());
  app.get("/api/search", requireAuth, searchHandler);
  app.use("/api/events", requireAuth, createEventsRouter(), createTeamsRouter());

  app.use("/api", (_req, res) => {
    res.status(404).json({ error: { code: "not_found", message: "Route not found" } });
  });
  app.use(errorHandler);
  return app;
}
