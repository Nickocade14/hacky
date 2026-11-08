import express from "express";
import cors from "cors";
import { requireAuth } from "./auth/jwt.js";
import { createAuthRouter } from "./auth/routes.js";
import { createChatRouter } from "./chat/routes.js";
import type { Ranker } from "./chat/gemini.js";
import type { Mailer } from "./email/mailer.js";
import { errorHandler } from "./errors.js";
import { createEventsRouter } from "./events/routes.js";
import { createTeamsRouter } from "./events/teams.js";
import { createMeRouter } from "./me.js";
import { searchHandler } from "./search.js";
import { createConversationsRouter } from "./social/conversations.js";
import { createRequestsRouter } from "./social/requests.js";

export interface AppOptions {
  mailer?: Mailer; // tests pass a fake that records mail
  rank?: Ranker; // tests pass a fake Hacky ranker
}

export function createApp({ mailer, rank }: AppOptions = {}) {
  const app = express();
  const origins = (process.env.CORS_ORIGIN ?? "http://localhost:5173").split(",").map((origin) => origin.trim());
  app.use(cors({ origin: origins }));
  app.use(express.json({ limit: "100kb" }));

  app.get("/api/health", (_req, res) => {
    res.json({ ok: true });
  });

  app.use("/api/auth", createAuthRouter({ mailer }));
  // Everything below needs a JWT (Authorization: Bearer <token>). Unknown
  // paths outside these prefixes still get the JSON 404 below, not a 401.
  app.use(["/api/me", "/api/search", "/api/events", "/api/requests", "/api/blocks", "/api/conversations"], requireAuth);
  app.use("/api/me", createMeRouter());
  app.get("/api/search", searchHandler);
  app.use("/api/events", createEventsRouter(), createTeamsRouter(), createChatRouter({ rank }));
  app.use("/api", createRequestsRouter(), createConversationsRouter());

  app.use("/api", (_req, res) => {
    res.status(404).json({ error: { code: "not_found", message: "Route not found" } });
  });
  app.use(errorHandler);
  return app;
}
