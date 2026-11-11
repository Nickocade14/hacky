import assert from "node:assert/strict";
import { test } from "node:test";
import { NoObjectGeneratedError } from "ai";
import { MockLanguageModelV4 } from "ai/test";
import { Types } from "mongoose";
import { matchedSkills, searchTerms, summaryLine, type CandidateRow } from "../src/chat/candidates.js";
import { buildInstructions, buildPrompt, chatProvider, createRanker, defaultRanker, type RankInput } from "../src/chat/gemini.js";
import { HttpError } from "../src/errors.js";

const row = (over: Partial<CandidateRow> = {}): CandidateRow => ({
  role: "hacker",
  skills: ["Node.js", "PostgreSQL"],
  profile: { _id: new Types.ObjectId(), handle: "maya_backend", name: "Maya Chen" },
  ...over,
});

const input: RankInput = {
  eventName: "Knight Hacks IX",
  tracks: ["Fintech"],
  viewerLine: summaryLine(row({ profile: { _id: new Types.ObjectId(), handle: "nico", name: "Nico" }, skills: ["Flutter"] })),
  history: ["user: hi", "hacky: hello"],
  intent: "teammate",
  candidates: [
    { ref: "p1", line: summaryLine(row(), "p1") },
    { ref: "p2", line: summaryLine(row({ summary: "Line one\nline | two" }), "p2") },
  ],
  text: "Find a teammate who knows React",
};

const usage = {
  inputTokens: { total: 1, noCache: 1, cacheRead: 0, cacheWrite: 0 },
  outputTokens: { total: 1, text: 1, reasoning: 0 },
};
const mockReturning = (text: string) => new MockLanguageModelV4({
  doGenerate: async () => ({
    content: [{ type: "text", text }],
    finishReason: { unified: "stop", raw: "stop" },
    usage,
    warnings: [],
  }) as any,
});

// Runs `body` with these env vars set (undefined deletes), then restores them.
async function withEnv(vars: Record<string, string | undefined>, body: () => Promise<void> | void) {
  const saved = Object.fromEntries(Object.keys(vars).map((name) => [name, process.env[name]]));
  const apply = (values: Record<string, string | undefined>) => {
    for (const [name, value] of Object.entries(values)) {
      if (value === undefined) delete process.env[name];
      else process.env[name] = value;
    }
  };
  apply(vars);
  try { await body(); } finally { apply(saved); }
}

const offline = (error: unknown) => error instanceof HttpError && error.status === 503 && error.code === "ai_unavailable";

test("no API key for the chosen provider answers 503 before any network call", async () => {
  await withEnv({ AI_PROVIDER: undefined, GOOGLE_GENERATIVE_AI_API_KEY: undefined }, async () => {
    await assert.rejects(defaultRanker(input), offline);
  });
  // A Gemini key doesn't help when Claude is chosen, and the other way around.
  await withEnv({ AI_PROVIDER: "anthropic", ANTHROPIC_API_KEY: undefined, GOOGLE_GENERATIVE_AI_API_KEY: "dummy" }, async () => {
    await assert.rejects(defaultRanker(input), offline);
  });
  await withEnv({ AI_PROVIDER: "google", GOOGLE_GENERATIVE_AI_API_KEY: undefined, ANTHROPIC_API_KEY: "dummy" }, async () => {
    await assert.rejects(defaultRanker(input), offline);
  });
});

test("AI_PROVIDER picks Claude or Gemini, and defaults to Gemini", async () => {
  for (const [value, provider] of [[undefined, "google"], ["google", "google"], ["anthropic", "anthropic"], [" Anthropic ", "anthropic"], ["openai", "google"]] as const) {
    await withEnv({ AI_PROVIDER: value }, () => assert.equal(chatProvider(), provider, String(value)));
  }
});

test("the prompt has every ref, the viewer and the message, one line per person", () => {
  const prompt = buildPrompt(input);
  for (const c of input.candidates) assert.ok(prompt.includes(c.line));
  assert.ok(prompt.includes(input.viewerLine));
  assert.ok(prompt.includes("MESSAGE:\nFind a teammate who knows React"));
  assert.ok(prompt.includes("CANDIDATES (2):"));
  const p2 = input.candidates[1].line;
  assert.equal(p2.includes("\n"), false);
  assert.ok(p2.includes("about: Line one line / two"));
  assert.ok(p2.startsWith("p2 | Maya Chen (@maya_backend) | hacker"));
  assert.ok(buildInstructions(input).includes('"Knight Hacks IX"'));
  assert.ok(buildInstructions({ ...input, intent: "mentor" }).includes("find mentors"));
});

test("parses the model's JSON and rejects bad output", async () => {
  const answer = { reply: "Here you go.", matches: [{ ref: "p1", reason: "Builds Node APIs." }] };
  assert.deepEqual(await createRanker(mockReturning(JSON.stringify(answer)))(input), answer);
  await assert.rejects(createRanker(mockReturning("not json"))(input), (error) => NoObjectGeneratedError.isInstance(error));
});

test("matchedSkills matches whole words, including C++", () => {
  assert.deepEqual(matchedSkills(["C++", "Django", "React"], "anyone good at c++?"), ["C++"]);
  assert.deepEqual(matchedSkills(["Django"], "go"), []);
  assert.deepEqual(matchedSkills(["Go"], "need a go dev"), ["Go"]);
});

test("search terms drop filler words", () => {
  assert.equal(searchTerms("Find a teammate who knows React"), "react");
  assert.equal(searchTerms("Find a mentor"), "");
  assert.equal(searchTerms("Who's looking for a team?"), "");
});
