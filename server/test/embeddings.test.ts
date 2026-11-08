import assert from "node:assert/strict";
import { test } from "node:test";
import { EMBEDDING_DIMENSIONS } from "../src/models/enums.js";
import { memberProfileText, teamProfileText, normalizeEmbedding } from "../src/embeddings.js";

test("member document describes skills offered, not skills wanted", () => {
  const source = {
    skills: ["React", "TypeScript"],
    skillsWanted: ["backend"], // Extra intake field must NOT be in document representation.
    interests: ["health tech"],
    track: "Health",
  };
  const text = memberProfileText(source);
  assert.match(text, /Skills: React, TypeScript/);
  assert.match(text, /Interests: health tech/);
  assert.doesNotMatch(text, /backend/);
});

test("team document includes open roles", () => {
  assert.match(teamProfileText({ name: "Pulse", wantedSkills: ["React"] }), /Looking for: React/);
});

test("shortened Gemini vectors are finite, 768-dimensional, and normalized", () => {
  const data = Array.from({ length: EMBEDDING_DIMENSIONS }, (_, index) => index === 0 ? 3 : index === 1 ? 4 : 0);
  const normalized = normalizeEmbedding(data);
  assert.equal(normalized.length, EMBEDDING_DIMENSIONS);
  assert.ok(Math.abs(Math.hypot(...normalized) - 1) < 1e-10);
  assert.throws(() => normalizeEmbedding([1, 2, 3]), /768/);
  assert.throws(() => normalizeEmbedding(Array(EMBEDDING_DIMENSIONS).fill(0)), /zero magnitude/);
});
