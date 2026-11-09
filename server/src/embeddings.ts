/**
 * Shared text/embedding helpers for Hacky's hybrid matcher.
 * Keep document and query vectors on the SAME model and dimension.
 * Only the server calls Gemini; never expose the API key or vectors to clients.
 */
import { EMBEDDING_DIMENSIONS } from "./models/enums.js";

type Tags = readonly string[] | null | undefined;
type OptionalText = string | null | undefined;

export type MemberEmbeddingSource = {
  skills?: Tags;
  interests?: Tags;
  track?: OptionalText;
  idea?: OptionalText;
  summary?: OptionalText;
  motivations?: Tags;
};

export type TeamEmbeddingSource = {
  name: string;
  idea?: OptionalText;
  track?: OptionalText;
  wantedSkills?: Tags;
};

function formattedLines(fields: Array<[string, string]>): string {
  return fields
    .map(([label, value]) => [label, value.trim()] as const)
    .filter(([, value]) => value.length > 0)
    .map(([label, value]) => `${label}: ${value}`)
    .join("\n");
}

function tags(values: Tags): string {
  return (values ?? []).map((value) => value.trim()).filter(Boolean).join(", ");
}

/** Describe what a member HAS, not what skills they want teammates to have. */
export function memberProfileText(source: MemberEmbeddingSource): string {
  return formattedLines([
    ["Skills", tags(source.skills)],
    ["Interests", tags(source.interests)],
    ["Track", source.track ?? ""],
    ["Idea", source.idea ?? ""],
    ["Summary", source.summary ?? ""],
    ["Motivations", tags(source.motivations)],
  ]);
}

/** Team wantedSkills DO belong in the vector: they describe openings. */
export function teamProfileText(source: TeamEmbeddingSource): string {
  return formattedLines([
    ["Team", source.name],
    ["Track", source.track ?? ""],
    ["Idea", source.idea ?? ""],
    ["Looking for", tags(source.wantedSkills)],
  ]);
}

/** Only attendees seeking teams or mentoring are searchable through vectors. */
export function isEmbeddableMemberRole(role: string): boolean {
  return role === "hacker" || role === "mentor";
}

export type EmbeddingTaskType = "RETRIEVAL_DOCUMENT" | "RETRIEVAL_QUERY";

const MODEL = "gemini-embedding-001";
const ENDPOINT = `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:embedContent`;
const wait = (ms: number) => new Promise<void>((resolve) => setTimeout(resolve, ms));

/**
 * Gemini's reduced (768-dimensional) vectors should be L2-normalized for
 * consistent cosine comparison. The same normalization is used for queries.
 */
export function normalizeEmbedding(values: readonly number[]): number[] {
  if (values.length !== EMBEDDING_DIMENSIONS || values.some((value) => !Number.isFinite(value))) {
    throw new Error(`Expected exactly ${EMBEDDING_DIMENSIONS} finite embedding values.`);
  }
  const magnitude = Math.hypot(...values);
  if (!(magnitude > 0)) throw new Error("Embedding has zero magnitude.");
  return values.map((value) => value / magnitude);
}

/** A single Gemini API request. Reuse for document seeding and live query vectors. */
export async function embedText(text: string, taskType: EmbeddingTaskType): Promise<number[]> {
  const key = process.env.GOOGLE_GENERATIVE_AI_API_KEY;
  if (!key) throw new Error("GOOGLE_GENERATIVE_AI_API_KEY is missing from server/.env.");
  if (!text.trim()) throw new Error("Cannot embed empty text.");

  // Short retry policy for transient rate limits/server errors. Never retry bad keys (401/403).
  for (let attempt = 0; attempt < 4; attempt++) {
    let response: Response;
    try {
      response = await fetch(ENDPOINT, {
        method: "POST",
        headers: { "Content-Type": "application/json", "x-goog-api-key": key },
        body: JSON.stringify({
          model: `models/${MODEL}`,
          content: { parts: [{ text }] },
          taskType,
          outputDimensionality: EMBEDDING_DIMENSIONS,
        }),
        signal: AbortSignal.timeout(30_000),
      });
    } catch (error) {
      if (attempt === 3) throw error;
      await wait(2_000 * 2 ** attempt);
      continue;
    }

    if (response.ok) {
      const data: unknown = await response.json();
      const values = (data as { embedding?: { values?: unknown } }).embedding?.values;
      if (!Array.isArray(values) || !values.every((value) => typeof value === "number")) {
        throw new Error("Gemini returned an invalid embedding response.");
      }
      return normalizeEmbedding(values as number[]);
    }

    if ((response.status === 429 || response.status >= 500) && attempt < 3) {
      const after = Number(response.headers.get("retry-after"));
      const delay = Number.isFinite(after) && after > 0 ? after * 1000 : 2_000 * 2 ** attempt;
      await wait(Math.min(delay, 60_000));
      continue;
    }
    // Don't print the request URL, headers, or API key to the terminal.
    throw new Error(`Gemini embedding request failed (HTTP ${response.status}). Check API access and quota.`);
  }
  throw new Error("Gemini embedding request failed after retries.");
}

export const embedDocument = (text: string) => embedText(text, "RETRIEVAL_DOCUMENT");
export const embedQuery = (text: string) => embedText(text, "RETRIEVAL_QUERY");
