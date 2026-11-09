import assert from "node:assert/strict";
import { test } from "node:test";
import { NoObjectGeneratedError } from "ai";
import { MockLanguageModelV4 } from "ai/test";
import { Types } from "mongoose";
import { matchedSkills, searchTerms, summaryLine, type CandidateRow } from "../src/chat/candidates.js";
import { buildInstructions, buildPrompt, createGeminiRanker, geminiRanker, type RankInput } from "../src/chat/gemini.js";
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

test("no API key answers 503 before any network call", async () => {
  const saved = process.env.GOOGLE_GENERATIVE_AI_API_KEY;
  delete process.env.GOOGLE_GENERATIVE_AI_API_KEY;
  try {
    await assert.rejects(geminiRanker(input), (error: unknown) =>
      error instanceof HttpError && error.status === 503 && error.code === "ai_unavailable");
  } finally {
    if (saved !== undefined) process.env.GOOGLE_GENERATIVE_AI_API_KEY = saved;
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
  assert.deepEqual(await createGeminiRanker(mockReturning(JSON.stringify(answer)))(input), answer);
  await assert.rejects(createGeminiRanker(mockReturning("not json"))(input), (error) => NoObjectGeneratedError.isInstance(error));
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
