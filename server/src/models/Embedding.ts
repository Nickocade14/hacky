import { Schema, model, type InferSchemaType } from "mongoose";
import { EMBEDDING_DIMENSIONS, EMBEDDING_OWNERS } from "./enums.js";

// Server-only. Never send these to the browser, the app or the model.
// ownerId is a Profile _id when ownerKind = "member", a Team _id when "team".
//
// Vector search needs an Atlas Vector Search index (create it in Atlas UI,
// collection "embeddings", index name "embedding_vector"):
// {
//   "fields": [
//     { "type": "vector", "path": "embedding", "numDimensions": 768, "similarity": "cosine" },
//     { "type": "filter", "path": "event" },
//     { "type": "filter", "path": "ownerKind" }
//   ]
// }
const embeddingSchema = new Schema(
  {
    event: { type: Schema.Types.ObjectId, ref: "Event", required: true },
    ownerKind: { type: String, enum: EMBEDDING_OWNERS, required: true },
    ownerId: { type: Schema.Types.ObjectId, required: true },
    // Normalize before saving.
    embedding: {
      type: [Number],
      required: true,
      validate: {
        validator: (v: number[]) => v.length === EMBEDDING_DIMENSIONS,
        message: `embedding must have ${EMBEDDING_DIMENSIONS} numbers`,
      },
    },
  },
  { timestamps: { createdAt: false, updatedAt: true } },
);

embeddingSchema.index({ event: 1, ownerKind: 1, ownerId: 1 }, { unique: true });

export type Embedding = InferSchemaType<typeof embeddingSchema>;
export const EmbeddingModel = model("Embedding", embeddingSchema);
