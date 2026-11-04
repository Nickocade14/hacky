---
paths:
  - "mobile/**"
---
# Mobile (Flutter)

- Colors and fonts come from `lib/theme.dart` (Lato, the web palette). Screens match the web design.
- The JWT lives in `flutter_secure_storage`, never `SharedPreferences`.
- One API layer in `lib/api/` (a real client and a fake one, same interface); base URL is the production https domain. For local testing on the Android emulator the host is `10.0.2.2`, not `localhost`.
- Endpoints and JSON shapes come from `docs/openapi.yaml`. Model classes mirror its schemas.
- Login / register is the first screen.
- All HTTP goes through the API layer in `lib/api/`. Screens never call `http` directly or bypass it.
- Until a server route exists, use the fake client in `lib/api/`, switched on with a `--dart-define` flag.
- Verify-email and reset-password happen on the web (the email links open it), so mobile has no screens for them.
- Every screen mirrors its web page in `web/src/` and keeps the original Hacky look: the knit mascot, with assets in `assets/mascots/`.
- Keep classes small and named after what they are: the class diagram for the slides is generated from this code.
- Run `flutter analyze` and `flutter test` before opening a PR.
