import assert from "node:assert/strict";
import { test } from "node:test";
import { MockLanguageModelV4 } from "ai/test";
import { buildProfilePrompt, createProfileEditor } from "../src/chat/gemini.js";
import { type CurrentProfile, type ProfileEdit, buildProposal, linksFrom, wantsProfileEdit } from "../src/chat/profile.js";

const current: CurrentProfile = {
  skills: ["Flutter", "React"],
  skillsWanted: [],
  interests: ["health"],
  experience: "beginner",
  bio: null,
  links: { github: "https://github.com/nico" },
};

const edit = (fields: Partial<ProfileEdit>): ProfileEdit => ({
  reply: "", addSkills: [], removeSkills: [], addSkillsWanted: [], addInterests: [], experience: null, bio: null, ...fields,
});

test("profile edits are told apart from requests for people", () => {
  for (const text of [
    "add frontend to my skills",
    "Add that I have experience in frontend to my profile.",
    "agrega que tengo experiencia en frontend",
    "agrega Python a mi perfil",
    "remove React from my skills",
    "update my bio: I build mobile apps",
    "I have experience with Docker",
    "https://www.linkedin.com/in/nicolas-cadena",
    "here's my github: github.com/Nickocade14",
  ]) assert.equal(wantsProfileEdit(text), true, text);

  for (const text of [
    "Find a teammate who knows React",
    "find someone with React experience",
    "Find a mentor",
    "Who's looking for a team?",
    "anyone good at c++?",
    "Help me pick a track",
    "busca alguien con experiencia en frontend",
  ]) assert.equal(wantsProfileEdit(text), false, text);
});

test("links come only from the typed text, upgraded to https", () => {
  assert.deepEqual(linksFrom("my linkedin is linkedin.com/in/nico-c and github http://github.com/Nickocade14."), {
    linkedin: "https://linkedin.com/in/nico-c",
    github: "https://github.com/Nickocade14",
  });
  assert.deepEqual(linksFrom("portfolio: https://nico.dev/work, thanks"), { website: "https://nico.dev/work" });
  assert.deepEqual(linksFrom("add frontend to my skills"), {});
});

test("the proposal merges lists, keeps other links and skips what wouldn't change", () => {
  const proposal = buildProposal(current, edit({ addSkills: ["frontend", "react", " "], removeSkills: ["Flutter"] }), {
    linkedin: "https://linkedin.com/in/nico-c",
  });
  assert.ok(proposal);
  assert.deepEqual(proposal.intake, { skills: ["React", "frontend"] });
  assert.deepEqual(proposal.profile, {
    links: { github: "https://github.com/nico", linkedin: "https://linkedin.com/in/nico-c" },
  });
  assert.deepEqual(proposal.changes, [
    { field: "skills", label: "Skills", added: ["frontend"], removed: ["Flutter"] },
    { field: "linkedin", label: "LinkedIn", value: "https://linkedin.com/in/nico-c" },
  ]);

  // Same experience, a skill they already have and their current GitHub: nothing to do.
  assert.equal(buildProposal(current, edit({ addSkills: ["REACT"], experience: "beginner" }), { github: "https://github.com/nico" }), null);
  assert.equal(buildProposal(current, null, {}), null);
});

test("bio and experience are proposed as single values", () => {
  const proposal = buildProposal(current, edit({ bio: "  I build\nFlutter apps. ", experience: "intermediate" }), {});
  assert.deepEqual(proposal?.profile, { bio: "I build Flutter apps." });
  assert.deepEqual(proposal?.intake, { experience: "intermediate" });
});

test("the editor sends the current profile and parses the model's JSON", async () => {
  const prompt = buildProfilePrompt({ current, text: "add frontend to my skills" });
  assert.match(prompt, /skills: Flutter, React/);
  assert.match(prompt, /MESSAGE:\nadd frontend to my skills/);

  const out = edit({ reply: "Check it and tap Save.", addSkills: ["frontend"] });
  const model = new MockLanguageModelV4({
    doGenerate: async () => ({
      content: [{ type: "text", text: JSON.stringify(out) }],
      finishReason: { unified: "stop", raw: "stop" },
      usage: { inputTokens: { total: 1, noCache: 1, cacheRead: 0, cacheWrite: 0 }, outputTokens: { total: 1, text: 1, reasoning: 0 } },
      warnings: [],
    }) as any,
  });
  assert.deepEqual(await createProfileEditor(model)({ current, text: "add frontend to my skills" }), out);
});
