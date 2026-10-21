// Allowed values shared by several models. Keep in sync with the API contract.

export const MEMBER_ROLES = ["hacker", "mentor", "sponsor", "organizer"] as const;
export const AVAILABILITY = ["available", "busy", "offline"] as const;
export const EXPERIENCE = ["beginner", "intermediate", "advanced"] as const;
export const HACK_GOALS = ["win", "learn", "ship"] as const;
export const MOTIVATIONS = ["build", "learn", "meet", "career", "compete", "fun"] as const;
export const REQUEST_STATUS = ["pending", "accepted"] as const;
export const REQUEST_SOURCE = ["agent", "qr", "profile"] as const;
export const CONVERSATION_KINDS = ["dm", "mentor", "team"] as const;
export const MESSAGE_KINDS = ["text", "card", "system"] as const;
export const HELP_STATUS = ["open", "claimed", "resolved"] as const;
export const EMBEDDING_OWNERS = ["member", "team"] as const;
export const AUTH_TOKEN_KINDS = ["verify-email", "reset-password"] as const;
export const AGENT_ROLES = ["user", "assistant", "system"] as const;

// Gemini gemini-embedding-001 at 768 dimensions (same as the old Hacky).
export const EMBEDDING_DIMENSIONS = 768;
