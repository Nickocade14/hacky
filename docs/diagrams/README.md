# Final Hacky ERD — corrected crow's-foot cardinalities

Based on current `main` at `Nickocade14/hacky` (models inspected 14 November 2026), **14 MongoDB/Mongoose collections**.

**Main deliverables:**

- `docs/erd/hacky_erd_final_cardinality.png` — complete ERD, every association labeled at **both ends** with `1`, `0..1`, `0..N`, or `1..N`, as well as actual graphical crow's-foot/circle/bar markers.
- `docs/diagrams/erd.puml` — editable PlantUML with the same relationships and correct crow's-foot cardinalities.
- `docs/diagrams/erd-slide-1-core.png`, `erd-slide-2-social.png`, `erd-slide-3-messaging.png` — three 16:9 presentation diagrams, each focusing on a related subset, while retaining numeric cardinalities.
- `docs/diagrams/ERD-relationships.md` — field-level relationship reference table with 28 explicitly enumerated relationships.

The **solid** lines are explicit Mongoose `ref` relationships (including embedded reference arrays); **dashed** lines represent the shared `User`/`Profile` key or polymorphic `Embedding.ownerId`.

Crow's-foot markers: `||` one, `o|` zero or one, `o{` zero or many, `|{` one or many. Numeric `0..N` etc appear alongside every line, so the diagram remains legible when markers are small.

**Caveat:** MongoDB doesn't enforce the same referential integrity as a SQL database; Mongoose `ref`s are schema-level relationships. `PendingSignup` is intentionally standalone until account verification. `Team.members[]` is many-to-many *across events*; a person can join at most one team per event.

All output images are generated from the same source model inventory and cardinality relationship list. SVG versions are included for lossless scaling, and DOT source is included for graphical customization.

No application source or shared database records were changed.
