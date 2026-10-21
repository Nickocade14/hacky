---
name: contract-check
description: Check the server routes, the web API client and the Flutter API client against docs/openapi.yaml and list every mismatch. Use before merging API changes or when something "doesn't match the API".
---

Compare each side against `docs/openapi.yaml` (the source of truth). Read only what you need: the spec, the Express routers in `server/src/`, the web API client in `web/src/`, and the Flutter API client and models in `mobile/lib/`.

For every endpoint in the spec, check:
- Method and path exist on the server, and the web and mobile clients call the same method and path.
- Request body fields and types match what the server validates (Zod).
- Response fields and types match what the server returns and what the clients read.
- Auth: endpoints marked with bearer security use the JWT middleware, and both clients send the header.
- Error shape is `{ error: { code, message } }`.

Also list server routes that are missing from the spec.

Output one table: `Endpoint | Side (server/web/mobile) | Problem | Owner`. Owners come from the table in AGENTS.md. Don't fix anything in this skill; report only, so each owner makes their own PR.
