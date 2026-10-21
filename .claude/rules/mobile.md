---
paths:
  - "mobile/**"
---
# Mobile (Flutter)

- Colors and fonts come from `lib/theme.dart` (Lato, the web palette). Screens match the web design.
- The JWT lives in `flutter_secure_storage`, never `SharedPreferences`.
- One API client class; base URL is the production https domain. For local testing on the Android emulator the host is `10.0.2.2`, not `localhost`.
- Endpoints and JSON shapes come from `docs/openapi.yaml`. Model classes mirror its schemas.
- Login / register is the first screen.
- Keep classes small and named after what they are: the class diagram for the slides is generated from this code.
- Run `flutter analyze` and `flutter test` before opening a PR.
