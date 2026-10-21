import { Schema, model, type InferSchemaType } from "mongoose";

const eventSchema = new Schema(
  {
    slug: { type: String, required: true, unique: true, match: /^[a-z0-9-]{2,40}$/ },
    name: { type: String, required: true, trim: true },
    // Colors/fonts the apps turn into theme variables.
    theme: { type: Schema.Types.Mixed, default: () => ({}) },
    tracks: { type: [String], default: [] },
    startsAt: Date,
    endsAt: Date,
  },
  { timestamps: { createdAt: true, updatedAt: false } },
);

export type Event = InferSchemaType<typeof eventSchema>;
export const EventModel = model("Event", eventSchema);
