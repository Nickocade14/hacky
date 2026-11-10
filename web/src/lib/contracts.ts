import type { components, operations } from "./schema";

// Generated from docs/openapi.yaml; regenerate schema.d.ts with npm run api:types.
export type RegisterBody = components["schemas"]["RegisterBody"];
export type LoginBody = components["schemas"]["LoginBody"];
export type LoginResult = components["schemas"]["LoginResult"];
export type VerifyCodeBody = components["schemas"]["VerifyCodeBody"];
export type EmailBody = components["schemas"]["EmailBody"];
export type ResetCodeBody = components["schemas"]["ResetCodeBody"];
export type Me = components["schemas"]["Me"];
export type MyEvent = components["schemas"]["MyEvent"];
export type EventInfo = components["schemas"]["EventInfo"];
export type EventMe = components["schemas"]["EventMe"];
export type EventList = operations["listEvents"]["responses"][200]["content"]["application/json"];
export type Ok = components["schemas"]["Ok"];
export type ApiErrorBody = components["schemas"]["ApiError"];
export type SearchQuery = operations["search"]["parameters"]["query"];
export type SearchResults = components["schemas"]["SearchResults"];
