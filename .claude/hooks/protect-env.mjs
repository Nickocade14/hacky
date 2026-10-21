// PreToolUse hook: keeps Claude from reading or editing real .env files
// (secrets). .env.example is allowed. Exit code 2 blocks the tool call.
import { basename } from "node:path";

let raw = "";
for await (const chunk of process.stdin) raw += chunk;

const file = JSON.parse(raw)?.tool_input?.file_path ?? "";
const name = basename(String(file).replaceAll("\\", "/"));

if (/^\.env(\..+)?$/.test(name) && name !== ".env.example") {
  console.error(`Blocked: ${name} holds secrets. Use .env.example, or ask the user for the value you need.`);
  process.exit(2);
}
process.exit(0);
