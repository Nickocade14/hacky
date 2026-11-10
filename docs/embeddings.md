# Gemini embeddings for Hacky

This is the Knight Hacks IX embedding backfill for hybrid keyword + vector matching.
The backend uses direct Gemini REST calls (`fetch`) to create 768-dimensional,
L2-normalized `gemini-embedding-001` vectors. No User/login accounts are created.

## Included files

- `server/src/embeddings.ts` — reusable text formatting, document/query embeddings, normalization and role eligibility
- `server/src/scripts/seed-embeddings.ts` — resumable, insert-only embedding backfill
- `server/test/embeddings.test.ts` — unit tests
- `server/src/models/Embedding.ts` — vector storage schema

## Configuration

Run commands from `server/`. Copy `.env.example` to `.env` and configure
`MONGODB_URI` explicitly selecting the `/hacky` database and
`GOOGLE_GENERATIVE_AI_API_KEY`. **Never commit or disclose `.env` or the API key.**

The `embeddings` collection must have an Atlas Vector Search index named
`embedding_vector`, with a 768-dimensional cosine vector at `embedding` and
filter fields for `event` and `ownerKind` (see the index definition in
`server/src/models/Embedding.ts`). This is NOT a regular Mongoose index.

## Preview and test

```sh
cd server
npm run typecheck
npm test
npm run db:embeddings
```

`db:embeddings` defaults to a read-only preview. It never calls Gemini or
writes to MongoDB unless explicitly invoked with `--apply --confirm=hacky`.

Eligible **member** embeddings include only `hacker` and `mentor` roles.
`organizer` and `sponsor` are excluded. **Team** embeddings remain eligible.
The script prints a warning about any old excluded-role vectors, but does not
remove them.

## Writing to shared Atlas: team approval required

Before running any command that writes to the shared Atlas DB, agree the
scope and timing with the team, review the script/PR and inspect the dry run.
Gemini requests may consume quota or incur charges.

After approval, to generate a small number of *missing* vectors:

```sh
npm run db:embeddings -- --apply --confirm=hacky --limit=3
```

To generate all remaining missing vectors after approval:

```sh
npm run db:embeddings -- --apply --confirm=hacky
```

The script inserts only missing vectors and is resumable. It **does not**
replace existing vectors or purge stale organizer/sponsor embeddings.

## Existing vectors and profile edits

The first backfill ran before role eligibility was enforced and produced
167 vectors (156 members plus 11 teams). The Knight Hacks IX seed has
154 eligible members (136 hackers, 18 mentors) plus 11 teams, for **165
eligible vectors**. Do not assume shared Atlas still has exactly that count.

Do **not** delete/regenerate existing vectors until the team has reviewed and
approved a scoped cleanup plan and a backup. The revised script reports old
excluded-role vectors so they can be identified and removed safely in an
approved maintenance step. Running a dry run alone will not remove them.

Profile, membership and team updates do **not yet** refresh vectors. Implement
refresh/invalidation in the matching PR, and update vectors only after the
corresponding source document is saved. Match queries must still enforce role,
event membership, availability and block filters: vectors alone are not an
authorization or eligibility check.
