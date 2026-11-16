# Hacky

An AI chat that helps hackathon attendees find teammates and mentors. Web and mobile app built on MongoDB, Express, React (TypeScript) and Flutter. COP 4331C Large Project, UCF Fall 2026.

**Live:** [hackymatch.me](https://hackymatch.me)

## What it does

- **Sign up and log in.** Registration sends a code by email that has to be confirmed before the first login. Forgotten passwords are reset by email too. Auth uses JWT (`Authorization: Bearer <token>`) on web and mobile.
- **Join an event.** Each hackathon has its own attendee profile, team and people.
- **Ask Hacky.** Describe who you need ("a backend dev who knows OAuth") and Hacky answers with matching people, mentors or teams, each with a short reason. Matching mixes keyword and semantic search ([docs/matching.md](docs/matching.md)).
- **Search people.** Server-side search with partial matches (`GET /api/search?q=`).
- **Connect and chat.** Send and accept requests, create or join a team, message people, and block someone if needed.

## Team

| Person | Role |
|---|---|
| Nicolas Cadena | PM, Mobile (Flutter), Deploy |
| Ethan | Backend · Auth, Web (React) |
| Mohammed Haq | Backend · Data (MongoDB) |

Folder ownership and project rules are in [AGENTS.md](AGENTS.md).

## Repo layout

| Folder | What | Docs |
|---|---|---|
| `server/` | Express API, MongoDB models, auth, email, matching | below |
| `web/` | React + TypeScript (Vite) | [web/README.md](web/README.md) |
| `mobile/` | Flutter app (Android and iOS) | [mobile/README.md](mobile/README.md) |
| `deploy/` | DigitalOcean droplet, Nginx, HTTPS, auto deploy | [deploy/README.md](deploy/README.md) |
| `docs/` | API contract, diagrams, ERD, Gantt, test results | [Docs](#docs) |

## Run locally

Needs Node 24 and Flutter.

**Server** (from `server/`):

1. `npm ci`
2. Copy `.env.example` to `.env` and fill in MongoDB, JWT, SMTP and Gemini settings. Never commit `.env`.
3. `npm run db:indexes` (again after any model change; indexes are not created at startup).
4. `npm run dev`, then open `http://localhost:8787/api/health`.

Use MongoDB Atlas or a local replica set, since messages use transactions. Without `GOOGLE_GENERATIVE_AI_API_KEY`, search falls back to keyword matching only.

**Web:** `cd web && npm ci && npm run dev` (port 5173, proxies `/api` to the server).

**Mobile:** `cd mobile && flutter pub get && flutter run`. Debug builds call the server on the Android emulator's host (`10.0.2.2:8787`), release builds call `https://hackymatch.me`. Override with `--dart-define=API_BASE_URL=...`.

## Checks

| | Commands |
|---|---|
| Server | `npm run typecheck`, `npm run build`, `npm test` |
| Web | `npm run typecheck`, `npm test`, `npm run build` |
| Mobile | `flutter analyze`, `flutter test` |

CI runs all three on every pull request. Server tests start their own in-memory MongoDB and never touch your `MONGODB_URI`. Latest results: [docs/tests](docs/tests/README.md).

## API

[docs/openapi.yaml](docs/openapi.yaml) is the contract for every endpoint and JSON shape, and the file imported into SwaggerHub for the demo (login and search). Change it first, in its own PR, before the server and clients.

Every error is `{ "error": { "code", "message", "details?" } }`.

## Docs

- [UML diagrams](docs/diagrams/README.md): use case, sequence, activity, Flutter class diagrams
- [ERD](docs/erd/hacky_erd_final_cardinality.png) and [relationships](docs/diagrams/ERD-relationships.md)
- [Matching](docs/matching.md) and [embeddings](docs/embeddings.md)
- [Gantt chart](docs/gantt/README.md)
- [Test results](docs/tests/README.md)

## Deploy

Every push to `main` that passes CI deploys to the DigitalOcean droplet behind [hackymatch.me](https://hackymatch.me) (Nginx, PM2, Let's Encrypt). Details and rollback steps: [deploy/README.md](deploy/README.md).
