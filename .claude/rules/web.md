---
paths:
  - "web/**"
---
# Web (React + TypeScript, Vite)

- TypeScript only: `.ts`/`.tsx`. No `.js` files.
- All API calls go through one client module, which adds `Authorization: Bearer <token>` and reads the base URL from `VITE_API_URL`. Calls are async (fetch/axios), never full page reloads.
- Endpoints and JSON shapes come from `docs/openapi.yaml`. Don't invent fields.
- Login / register is the first screen. Also: verify-email, forgot-password and reset-password pages (the email links open these).
- Search calls `/api/search?q=` as the user types (debounce ~250 ms).
- API errors arrive as `{ error: { code, message } }`; show `message`.
- Use the shared theme (same palette and Lato as the mobile app). No hard-coded colors in components.
