import express from "express";
import cors from "cors";
import { errorHandler } from "./errors.js";

export function createApp() {
  const app = express();
  const origins = (process.env.CORS_ORIGIN ?? "http://localhost:5173").split(",").map((origin) => origin.trim());
  app.use(cors({ origin: origins }));
  app.use(express.json({ limit: "100kb" }));

  app.get("/api/health", (_req, res) => {
    res.json({ ok: true });
  });

  // Routers go here, e.g. app.use("/api/auth", authRouter).

  app.use("/api", (_req, res) => {
    res.status(404).json({ error: { code: "not_found", message: "Route not found" } });
  });
  app.use(errorHandler);
  return app;
}
