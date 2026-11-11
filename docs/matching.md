# Hacky Week 4: hybrid matching data-layer starter

Adds new files only (no tracked files overwritten):

- `server/src/matching/hybrid.ts` — event-scoped Atlas `embedding_vector` retrieval + MongoDB `$text`, reciprocal rank fusion, hard eligibility filters, and public result data.
- `server/test/matching.test.ts` — `node:test` cases using a **temporary MongoDB replica set** and injected vector results. Never touches the shared Atlas database or Gemini.
- `server/src/scripts/check-matching.ts` — optional **read-only** live-Atlas smoke test. Queries Gemini for the query embedding if a key is available, which can incur API usage.

## Branch (PowerShell from Hacky repo root)

```powershell
git status
git switch main
git pull --ff-only origin main
git switch -c mohammed/hybrid-matching
```

Extract the ZIP at the repository root (it contains `server/...`).

## Checks (PowerShell from `server/`)

```powershell
npm.cmd ci
npm.cmd run typecheck
npm.cmd test
```

Tests validate the pure rank-fusion logic and the MongoDB keyword/data filters. Local MongoDB memory server **does not implement Atlas `$vectorSearch`**, so tests inject the semantic ranked IDs. The generated `$vectorSearch` stage itself is inspected in a unit test.

## Optional read-only live smoke test

Your previously created `embedding_vector` Atlas index must be `READY`; `GOOGLE_GENERATIVE_AI_API_KEY` must be configured to exercise semantic retrieval. From `server/`:

```powershell
node --env-file=.env --import tsx src/scripts/check-matching.ts --kind=hacker --query="backend health tech"
node --env-file=.env --import tsx src/scripts/check-matching.ts --kind=mentor --query="OAuth"
node --env-file=.env --import tsx src/scripts/check-matching.ts --kind=team --query="health React"
```

Only reads the MongoDB database. It does not modify the already seeded vectors. The query embedding uses `RETRIEVAL_QUERY` and 768 dimensions. Never share your `.env` or API key.

## Scope and follow-up integration

This small PR introduces matching retrieval only. It **does not change the HTTP contract** or Nicolas's chat route, which currently uses `server/src/chat/candidates.ts` to load candidate rows and Gemini to rank them. Coordinate a second small PR with Nicolas to use the hybrid matcher for chat candidate retrieval, preserving its current `CandidateRow` format and fake-ranker tests.

A separate follow-up must hook `PATCH /api/events/:slug/me` to refresh an attendee's embedding when matching fields change. Those route files are owned by the backend API teammate; do not silently edit them. New teams and edited team descriptions likewise need vector creation/refresh.

Potential future ranking improvements: use viewer preferences (`skillsWanted`, goals, tracks) in compatibility scoring, tune vector pool size and weights from `seed/match-cases.json`, and consider separating `skillsWanted` from the member `$text` index because wanted skills are *not* necessarily skills offered.

Do not use this starter to delete or regenerate shared Atlas vectors; coordinate shared-database changes with the team.
