# hacky
Hacky: an AI chat that helps hackathon attendees find teammates and mentors. MongoDB, Express, React and Flutter. COP 4331C Large Project, UCF Fall 2026.

The API contract is [docs/openapi.yaml](docs/openapi.yaml). The current server contains the data layer and `/api/health`; auth, feature routes, React and Flutter clients are still to be implemented. Project rules and ownership are in [AGENTS.md](AGENTS.md).

## Local setup

From `server/`:

1. Run `npm ci`.
2. Copy `.env.example` to `.env` and fill in MongoDB, JWT and email settings. Keep `DEMO_MODE=false` outside isolated demos.
3. Use MongoDB Atlas or a local replica set: message creation and activity updates use transactions.
4. Run `npm run db:indexes` before accepting writes, including after schema/index changes. Index creation is disabled at startup.
5. Run `npm run dev` and check `http://localhost:8787/api/health`.

`npm run typecheck`, `npm run build` and `npm test` verify the server. The tests create and stop an isolated MongoDB replica set; they never use your `MONGODB_URI`. On the first run, the test dependency downloads a MongoDB binary.

## Data-layer entry points

- `issueAuthToken` atomically replaces a user's token for one purpose; `consumeAuthToken` checks expiry and deletes it once.
- `createTeam` includes the owner. A unique index permits one team per person per event. Joining requires the owner's approval of a team connection request, followed by `addTeamMember`. These are data helpers, not authorization middleware.
- `createMessage` saves the message and updates `lastMessageAt` in the same transaction. Client retries reuse the existing message without changing activity. `listMessages` uses exclusive ObjectId cursors; `listConversations` orders by activity.
- Auth routes must use the schemas and `hashPassword` in `server/src/validation/auth.ts`; passwords are limited to 72 UTF-8 bytes before bcrypt.
- The planned chat endpoint is `GET` / `POST /api/events/{slug}/chat`. Team creation and approval flows are defined in the contract; their HTTP handlers are not implemented yet.

## Existing databases

New unique indexes require existing data to satisfy the rules first: at most one auth token per user/kind, no member in two teams in the same event, and each owner included in members. Resolve legacy conflicts before running `db:indexes`; the app does not delete conflicting data automatically.

For existing conversations, backfill `lastMessageAt` to the latest message's `createdAt`, or the conversation's `createdAt` when empty, before using activity ordering. `syncIndexes` changes indexes only; it does not backfill documents. Publish the contract changes in their own PR before the implementation PR, per `AGENTS.md`.
