# Hybrid matching

`server/src/matching/hybrid.ts` finds hackers, mentors or teams in one event for a free-text query.

## How it ranks

1. **Keyword:** MongoDB `$text` on the `membership_text` and `team_text` indexes. Filler words ("find", "teammate", "who knows"…) are dropped first.
2. **Semantic:** Atlas `$vectorSearch` on the `embedding_vector` index (768-dimension Gemini embeddings, see [embeddings.md](embeddings.md)). The query is embedded with `RETRIEVAL_QUERY`. Without `GOOGLE_GENERATIVE_AI_API_KEY` this step is skipped and keyword results are used alone.
3. **Fusion:** the two ranked lists are combined with Reciprocal Rank Fusion (k = 60), then skills named in the query add a small bonus (and verified mentors a smaller one). Scores are 0–100 and only comparable within one search.

## Who is left out

- The viewer, and anyone they blocked or who blocked them (any event).
- Anyone they already sent a request to or received one from in this event.
- Anyone marked offline, and hackers who aren't looking for a team.
- Full teams, teams the viewer is already on, and teams whose owner is left out above.

Results contain public profile fields only: never private user data or raw vectors.

## Status

The module is not called by any route yet. Hacky's chat still loads candidates with `server/src/chat/candidates.ts`. Using `hybridMatch` there, and refreshing a member's embedding when they edit their event profile, are the next steps.

## Smoke test (read-only)

Needs `server/.env` with `MONGODB_URI` (database `/hacky`) and, for the semantic step, `GOOGLE_GENERATIVE_AI_API_KEY`. From `server/`:

```sh
node --env-file=.env --import tsx src/scripts/check-matching.ts --kind=hacker --query="backend health tech"
node --env-file=.env --import tsx src/scripts/check-matching.ts --kind=mentor --query="OAuth"
node --env-file=.env --import tsx src/scripts/check-matching.ts --kind=team --query="health React"
```

Optional flags: `--event=<slug>` (default `knighthacks-ix`) and `--viewer=<handle>` (default `demo_you`). The script only reads; each run with a key makes one Gemini embedding request.

## Tests

`npm test` in `server/` runs `test/matching.test.ts` against an in-memory MongoDB replica set. That server has no `$vectorSearch`, so the tests inject the semantic ranking and check the generated pipeline separately.
