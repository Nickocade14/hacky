---
name: mobile-screen
description: Build one Flutter screen in mobile/ from its web equivalent. Takes a screen name (e.g. "login", "search"). Use when asked to add or port a mobile screen.
---

Follow `.claude/rules/mobile.md` throughout.

1. **Find the sources.** Locate the matching page in `web/src/` and the endpoints it calls (via `web/src/lib/api.ts`). Look those endpoints up in `docs/openapi.yaml`. If there is no web page for the screen, stop and ask.
2. **Build the screen** in `mobile/lib/`. Colors and fonts come from `lib/theme.dart`; mascot art from `assets/mascots/`. All calls go through `lib/api/`; if an endpoint is missing there, add it (real and fake client) matching the contract.
3. **Add widget tests** in `mobile/test/` using the fake client: renders, validation, success and error states.
4. **Check:** `flutter analyze` and `flutter test` pass.
5. **Run it** in Chrome with the fake client (`flutter run -d chrome --dart-define=<fake client flag>`, flag name from `lib/api/`). Show the user a screenshot next to the web page.
6. **Wait for approval.** Commit one logical step at a time, but don't push until the user approves the look.
