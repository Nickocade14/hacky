# Hacky Week 3 — embedding backfill starter

Copy the `server` directory into the ROOT of your local Hacky checkout, preserving paths. This adds:

- `server/src/embeddings.ts`: shared text formatting and Gemini document/query embedding helpers
- `server/src/scripts/seed-embeddings.ts`: safe, resumable Knight Hacks IX embedding backfill
- `server/test/embeddings.test.ts`: tests for formatting and 768-dimensional normalization

No third-party packages required beyond the repo's existing dependencies. Uses built-in Node fetch.

## Before running

1. Update local `server/.env`: `GOOGLE_GENERATIVE_AI_API_KEY=your_actual_key` (never commit `.env`).
2. Confirm `MONGODB_URI` ends in `/hacky` (query parameters are okay).
3. Confirm the Atlas Vector Search index `embedding_vector` is READY.
4. Review the files with teammates before making production changes.

## Verify and preview

```powershell
cd C:\Users\areef\hacky\server
npm.cmd run typecheck
npm.cmd test
node --env-file=.env --import tsx src/scripts/seed-embeddings.ts
```

The preview reads the seeded event but does NOT call Gemini or modify MongoDB.

## Write the first three embeddings

```powershell
node --env-file=.env --import tsx src/scripts/seed-embeddings.ts --apply --confirm=hacky --limit=3
```

Verify counts; if okay, run without `--limit=3` to finish the missing documents:

```powershell
node --env-file=.env --import tsx src/scripts/seed-embeddings.ts --apply --confirm=hacky
```

The script never overwrites existing embeddings and does not create Users. A rerun resumes remaining vectors. Gemini API calls consume quota and may incur charges; limits and availability depend on your project/account.

## Notes

- Uses `gemini-embedding-001`, `RETRIEVAL_DOCUMENT` for indexed data and `RETRIEVAL_QUERY` for queries. Both output 768 dimensions and undergo L2 normalization.
- The `src/embeddings.ts` functions will be used by the upcoming hybrid matching module.
- The Atlas Vector Search index is *not* an ordinary Mongoose index; do not run `npm run db:indexes` to manage it.
- The backfill captures current seed data only. A future profile/team update handler must re-embed edited information using `embedDocument`.
- No keys, URI values, or other secrets are included in this starter.
