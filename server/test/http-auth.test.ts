import assert from "node:assert/strict";
import { once } from "node:events";
import { test } from "node:test";
import express from "express";
import { createApp } from "../src/app.js";
import { errorHandler } from "../src/errors.js";
import { passwordSchema, registerBodySchema, resetPasswordBodySchema, hashPassword } from "../src/validation/auth.js";

async function withServer(app: ReturnType<typeof express>, run: (base: string) => Promise<void>) {
  const server = app.listen(0, "127.0.0.1");
  try {
    await once(server, "listening");
    const address = server.address();
    assert.ok(address && typeof address !== "string");
    await run(`http://127.0.0.1:${address.port}`);
  } finally {
    await new Promise<void>((resolve) => { server.close(() => resolve()); server.closeAllConnections(); });
  }
}

test("HTTP health, JSON 404, malformed JSON and 413", async () => {
  await withServer(createApp(), async (base) => {
    assert.deepEqual(await (await fetch(`${base}/api/health`)).json(), { ok: true });
    for (const [body, status, code] of [
      ['{}', 404, "not_found"],
      ['{', 400, "invalid_json"],
      [JSON.stringify({ text: "a".repeat(110_000) }), 413, "payload_too_large"],
    ] as const) {
      const response = await fetch(`${base}/api/unknown`, { method: "POST", headers: { "Content-Type": "application/json" }, body });
      assert.equal(response.status, status);
      assert.equal((await response.json()).error.code, code);
    }
  });
});

test("duplicate keys return the contract's registration codes without leaking key values", async () => {
  const app = express();
  app.get("/:field", (req, _res, next) => {
    const keyPattern = req.params.field === "other" ? { event: 1, members: 1 } : { [req.params.field]: 1 };
    next({ code: 11000, keyPattern, keyValue: { email: "private@example.com" } });
  });
  app.use(errorHandler);
  await withServer(app, async (base) => {
    for (const [field, code] of [["email", "email_taken"], ["handle", "handle_taken"], ["other", "conflict"]]) {
      const response = await fetch(`${base}/${field}`);
      assert.equal(response.status, 409);
      const body = await response.json();
      assert.equal(body.error.code, code);
      assert.ok(!JSON.stringify(body).includes("private@example.com"));
    }
  });
});

test("password rules count Unicode characters and enforce bcrypt's UTF-8 byte limit", () => {
  for (const password of ["a".repeat(72), "é".repeat(36), "😀".repeat(18)]) {
    assert.equal(passwordSchema.safeParse(password).success, true);
    assert.equal(registerBodySchema.safeParse({ name: "Test", handle: "tester", email: "test@example.com", password }).success, true);
    assert.equal(resetPasswordBodySchema.safeParse({ token: "token", password }).success, true);
  }
  for (const password of ["a".repeat(73), "é".repeat(37), "😀".repeat(19), "😀".repeat(7)]) {
    assert.equal(passwordSchema.safeParse(password).success, false);
    assert.throws(() => hashPassword(password));
  }
});
