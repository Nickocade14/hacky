---
name: uml
description: Generate the PlantUML diagrams the Large Project slides need (ERD, use case, sequence, activity, Flutter class diagram) from the real code. Use when asked for a diagram, ERD or UML.
---

Write PlantUML source to `docs/diagrams/<name>.puml`. Build each diagram from the code as it is now, never from memory. If `$ARGUMENTS` names one diagram, make only that one; otherwise make all five.

| Name | Source | Content |
|---|---|---|
| `erd` | `server/src/models/*.ts` | One entity per model (collection name, fields with types, required/unique). Relationships from `ref:` fields with cardinality. Embedded arrays (e.g. `Conversation.members`) shown inside the entity. |
| `use-case` | `docs/openapi.yaml` and the screens in `web/` and `mobile/` | Actors: Hacker, Mentor, Visitor (not signed in). One use case per user-visible action. |
| `sequence` | auth routes + chat route | Login (client → API → MongoDB → JWT back) and one Hacky chat turn. |
| `activity` | auth routes | Sign up → verification email → click link → verified → login, including expired/invalid token branches. |
| `class-mobile` | `mobile/lib/**/*.dart` | Classes with public fields and methods, grouped by package (screens, models, services). Skip generated files. |

Rules:
- Only include what exists in the code. If a source folder doesn't exist yet, say so and skip that diagram.
- Keep each diagram readable on one slide: hide private members and trivial getters.
- After writing, tell the user they can render the files in VS Code (PlantUML extension) or paste them at https://www.plantuml.com/plantuml.
