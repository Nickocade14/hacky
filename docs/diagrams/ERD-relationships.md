# Hacky MongoDB final ERD: relationships

Source: `server/src/models/*.ts` on GitHub `Nickocade14/hacky` `main`, reviewed November 14, 2026.

The number next to a collection describes how many of that collection can be associated with one record on the opposite end.

| Collection A | A per B | Collection B | B per A | Field / role | Relationship |
|---|---:|---|---:|---|---|
| `User` | 1 | `Profile` | 1 | `same _id` | logical |
| `User` | 1 | `AuthCode` | 0..N | `user` | ref |
| `Event` | 1 | `Membership` | 0..N | `event` | ref |
| `Profile` | 1 | `Membership` | 0..N | `user` | ref |
| `Event` | 1 | `Team` | 0..N | `event` | ref |
| `Profile` | 1 | `Team` | 0..N | `owner` | ref |
| `Team` | 0..N | `Profile` | 1..N | `members[]` | array |
| `Event` | 1 | `Embedding` | 0..N | `event` | ref |
| `Profile` | 0..1 | `Embedding` | 0..N | `ownerId [member]` | polymorphic |
| `Team` | 0..1 | `Embedding` | 0..N | `ownerId [team]` | polymorphic |
| `Profile` | 1 | `Block` | 0..N | `blocker` | ref |
| `Profile` | 1 | `Block` | 0..N | `blocked` | ref |
| `Event` | 1 | `ConnectionRequest` | 0..N | `event` | ref |
| `Profile` | 1 | `ConnectionRequest` | 0..N | `from` | ref |
| `Profile` | 1 | `ConnectionRequest` | 0..N | `to` | ref |
| `Team` | 0..1 | `ConnectionRequest` | 0..N | `team [optional]` | ref |
| `Event` | 1 | `HelpRequest` | 0..N | `event` | ref |
| `Profile` | 1 | `HelpRequest` | 0..N | `hacker` | ref |
| `Profile` | 0..1 | `HelpRequest` | 0..N | `mentor [optional]` | ref |
| `Event` | 1 | `Conversation` | 0..N | `event` | ref |
| `Profile` | 1..N | `Conversation` | 0..N | `members[].user` | array |
| `Profile` | 0..1 | `Conversation` | 0..N | `dmUserLow / High` | ref |
| `Team` | 0..1 | `Conversation` | 0..1 | `team [optional]` | ref |
| `HelpRequest` | 0..1 | `Conversation` | 0..1 | `helpRequest [optional]` | ref |
| `Conversation` | 1 | `Message` | 0..N | `conversation` | ref |
| `Profile` | 0..1 | `Message` | 0..N | `sender [optional]` | ref |
| `Profile` | 1 | `AgentMessage` | 0..N | `user` | ref |
| `Event` | 1 | `AgentMessage` | 0..N | `event` | ref |

## Legend

- **1** exactly one, **0..1** optional, **0..N** zero or more, **1..N** at least one.
- **Solid** lines are explicit `ref` declarations, including references inside embedded arrays.
- **Dashed** lines are logical/shared-ID or conditional polymorphic relations: not standard Mongoose `ref` declarations.
- An ERD documents *schema intent*; MongoDB does not enforce SQL foreign keys.
- `PendingSignup` has no outgoing reference. It represents unverified data; verification creates a `User` and `Profile`.
- `Profile._id` is shared with `User._id` (logical 1:1).
- `Embedding.ownerKind=member` -> Profile, `ownerKind=team` -> Team. Only one of the two possible owners is active.
- `Team.members[]` allows many profiles per team and teams across events; a profile can belong to at most one team *per event* by unique index.
- `Conversation.members[]` is an embedded subdocument array (not an independent MongoDB collection).
- `AuthCode` has `(user, kind)` unique index. Currently only `reset-password` is defined, so a user can hold at most one code in the current enum; generic schema relationship is 0..N across kinds.
- `HelpRequest.mentor` is optional while open, required by validation after claim.
- `Message.sender` is optional only for system messages.
- `Conversation.team`, `Conversation.helpRequest`, and DM IDs are conditional on the conversation `kind`; each of the first two has a unique partial index.
