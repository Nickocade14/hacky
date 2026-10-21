import { Schema, model, type InferSchemaType } from "mongoose";

// Applies everywhere and in both directions. Doesn't need a request to exist.
const blockSchema = new Schema(
  {
    blocker: { type: Schema.Types.ObjectId, ref: "Profile", required: true },
    blocked: { type: Schema.Types.ObjectId, ref: "Profile", required: true },
  },
  { timestamps: { createdAt: true, updatedAt: false } },
);

// Only runs on save()/create(). If the route uses upsert, check blocker !== blocked with Zod.
blockSchema.pre("validate", function () {
  if (this.blocker && this.blocked && this.blocker.equals(this.blocked)) {
    this.invalidate("blocked", "You can't block yourself");
  }
});

blockSchema.index({ blocker: 1, blocked: 1 }, { unique: true });
blockSchema.index({ blocked: 1 });

export type Block = InferSchemaType<typeof blockSchema>;
export const BlockModel = model("Block", blockSchema);
