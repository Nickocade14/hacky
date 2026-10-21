import assert from "node:assert/strict";
import { test } from "node:test";
import { fileURLToPath } from "node:url";
import SwaggerParser from "@apidevtools/swagger-parser";
import { Ajv } from "ajv";

test("OpenAPI validates, nullable references accept null, and chat shares an event URL", async () => {
  const api = await SwaggerParser.validate(fileURLToPath(new URL("../../docs/openapi.yaml", import.meta.url)));
  // The parser dereferences the specification; test schemas against actual response values.
  const schemas = (api as any).components.schemas;
  const ajv = new Ajv({ strict: false, validateFormats: false });
  let nullableReferences = 0;
  function walk(value: any) {
    if (!value || typeof value !== "object") return;
    if (value.oneOf?.some((branch: any) => branch.enum?.length === 1 && branch.enum[0] === null)) {
      assert.equal(ajv.compile(value)(null), true);
      nullableReferences++;
    }
    for (const entry of Object.values(value)) walk(entry);
  }
  walk(api);
  assert.ok(nullableReferences >= 15);
  const id = "000000000000000000000001";
  assert.equal(ajv.compile(schemas.Message.properties.senderId)(id), true);
  assert.equal(ajv.compile(schemas.Message.properties.senderId)("bad-id"), false);
  assert.equal(ajv.compile(schemas.IntakeFields.properties.experience)("expert"), false);
  assert.equal(ajv.compile(schemas.IntakeFields.properties.experience)("beginner"), true);
  const emptyRelation = { state: "none", requestId: null, conversationId: null };
  assert.equal(ajv.compile(schemas.Relation)(emptyRelation), true);
  assert.equal(ajv.compile(schemas.ConversationSummary.properties.lastMessage)(null), true);
  assert.equal(ajv.compile(schemas.ConversationSummary.properties.lastMessage)({}), false);
  assert.ok(api.paths?.["/api/events/{slug}/chat"]?.get);
  assert.ok(api.paths?.["/api/events/{slug}/chat"]?.post);
  assert.equal(api.paths?.["/api/chat"], undefined);
  assert.deepEqual(schemas.ChatBody.required, ["message"]);
  assert.ok(api.paths?.["/api/events/{slug}/teams"]?.post);
});
