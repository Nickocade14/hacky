# Hacky

An AI chat that helps hackathon attendees find teammates and mentors. COP 4331C Large Project (UCF, Fall 2026). Team of 4 + PM. Graded on a 100-point rubric; the rules below come from the assignment, so breaking one costs points.

## Assignment rules (never break these)

- MERN only: MongoDB, Express, React, Node. No Python anywhere.
- Web front end in TypeScript (`.ts`/`.tsx`, no `.js`). Mobile app in Flutter.
- The first screen on web and mobile is login / register.
- Email verification before the first login, and password reset (Nodemailer).
- Auth with JWT sent as `Authorization: Bearer <token>` (same for web and mobile).
- Search queries the server (`GET /api/search?q=`) and supports partial matches.
- REST API. 1 or 2 endpoints are demoed in SwaggerHub (login + search).
- Hosted on a domain name. Never demo on localhost or an IP.
- Web and mobile share one design (same colors, fonts, screens).

## Repo layout and owners

| Folder | What | Owner |
|---|---|---|
| `server/src/models/`, search, matching, seed | MongoDB data layer | Backend · Data |
| `server/src/` auth, middleware, email, `index.ts` | Express app, JWT, verification/reset | Backend · Auth |
| `.github/workflows/`, deploy config | DigitalOcean droplet, Nginx, PM2, domain | Deploy |
| `web/` | React + TypeScript (Vite) | Web |
| `mobile/` | Flutter app | Mobile |
| `docs/` | API contract, diagrams, Gantt | Whole team |

GitHub activity is graded per person (20 points). Only edit folders your person owns. If something in another folder needs to change, say what and who owns it instead of editing it.

## Contracts

- **API:** `docs/openapi.yaml` is the source of truth for every endpoint and JSON shape. It's also what goes to SwaggerHub. Change it first, in its own PR, then the server, web and mobile follow.
- **Database:** `server/src/models/` is the only place the schema changes.
- **Errors:** every API error is JSON `{ "error": { "code", "message", "details?" } }`.

## Commands

- `cd server && npm install`, then `npm run dev` (API at `http://localhost:8787/api`, check `/api/health`)
- `npm run typecheck` (server), `npm run db:indexes` (after changing a model)
- Copy `server/.env.example` to `server/.env`. Never commit `.env`.

## Working rules

- Small PRs into `main`, each reviewed by another team member. Never push to `main` directly.
- Code depends on contracts (OpenAPI, models), not on another module's internals.
- Each fact lives in one place (this file, the models, or the contract). Link instead of copying.
- Secrets only in `.env` (local) or the droplet's environment.
