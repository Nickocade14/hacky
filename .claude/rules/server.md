---
paths:
  - "server/**"
---
# Server (Express + TypeScript + Mongoose)

- ESM with NodeNext: relative imports end in `.js` (`import { connectDb } from "./db.js"`).
- Validate every request body and query with Zod. Throw `HttpError` (`src/errors.ts`) for expected failures; `errorHandler` in that file turns everything into JSON. Mount routes in `src/app.ts`.
- Every route that touches user data goes through the JWT middleware and checks the user belongs to the event.
- Responses never include `passwordHash`, embeddings, auth tokens or other users' emails.
- `pre("validate")` hooks only run on `save()`/`create()`. Rules that compare fields go in the update filter. Use the helpers next to the models: `claimHelpRequest`, `resolveHelpRequest`, `addTeamMember`, `openDm`.
- Requests: for personal requests only, before creating A→B look for a pending B→A and accept it with `openDm` instead. Team requests always need the owner's acceptance; acceptance, adding the member and opening the DM must be one transaction.
- Search: escape `q` before building a RegExp. `handle` is stored lowercase, so a lowercase `^prefix` regex uses its index.
- Auth tokens (verify/reset): use `issueAuthToken` and `consumeAuthToken`; never bypass their uniqueness or expiration checks.
- Passwords: use the Zod schemas and `hashPassword` in `src/validation/auth.ts`; bcrypt's limit is 72 UTF-8 bytes.
- Teams: `createTeam` includes the owner; use `addTeamMember` after approval. The unique event/members index enforces one team per person per event. Do not remove an owner without transferring ownership and validating the resulting team.
- Messages: use `createMessage` for all sends, including system messages. It saves the message and advances conversation activity in one transaction. Use `listMessages` for ObjectId cursors and `listConversations` for activity ordering.
- Run `npm run typecheck` before opening a PR.
