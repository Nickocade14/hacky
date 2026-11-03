# Hacky web

React + TypeScript (Vite). Project rules live in [AGENTS.md](../AGENTS.md), and endpoint shapes come from [the API contract](../docs/openapi.yaml).

## Run locally

Use Node 24. From `web/`:

```sh
npm ci
npm run dev
```

Vite serves development at `http://localhost:5173`. The default `/api` base is proxied to the Express server on port 8787. Start that server separately using [the repository setup](../README.md). For another API origin, copy `.env.example` to `.env` and set `VITE_API_URL` to its full API root, including `/api`. Values prefixed with `VITE_` are public browser configuration; never put secrets there.

The production demo must use the team's domain. Deploy and Nginx configuration belong to the Deploy owner. They will need to serve `dist/`, forward `/api` to Express, and route other browser paths to `index.html` so email links open directly.

## What is ready

- Login/register entry screens, verification and resend, forgotten password, and reset pages.
- A single typed API client and expiring JWT session storage. The client sends protected requests with the Bearer header. Passwords and profiles are not stored in localStorage.
- Real API calls with pending, error, and success states. There is no mock sign-in. Auth routes are not yet implemented in the current Express foundation, so end-to-end sign-in/email delivery awaits the server auth task.
- A small protected account screen uses the login result or `GET /api/me` after refresh. Onboarding, search, chat, and the rest of the old app are later tasks.
- A vector globe illustration, self-hosted Lato fonts, and palette tokens in `src/theme.css` for sharing with Mobile.

The source assets came from [the original Hacky app](https://github.com/seeko-codes/Hacky/tree/main/react/public). The API/storage behavior carries over its central fetch and guarded localStorage patterns, replacing its cookie authentication with the current contract's JWT flow.

## Check your work

```sh
npm run api:types
npm run typecheck
npm test
npm run build
```

`api:types` generates `src/lib/schema.d.ts` from the contract. Regenerate it after approved contract changes rather than editing generated definitions. `build` regenerates types, checks TypeScript, and creates `dist/`.

Tests simulate API responses to verify the browser's behavior without a database or email provider. Those tests do not prove the server auth flows work.

## Finish the Oct 19–25 deliverables

1. Review the starter and run its checks under your account. Commit it on your feature branch, open a small PR into `main`, and get a teammate's review.
2. Import [the auth wireframe SVG](design/auth-wireframes.svg) into Figma. Follow [the design instructions](design/README.md) to make and share the clickable prototype. The SVG alone does not complete the Figma task.
3. Confirm the palette with the Mobile owner so both clients share one design.

Next, implement the existing contract's auth endpoints, email delivery, and Bearer middleware in your server area. Coordinate the middleware's user-id handoff with Backend · Data. Model/schema changes remain with the Data owner.
