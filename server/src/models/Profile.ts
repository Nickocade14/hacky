import { Schema, model, type InferSchemaType } from "mongoose";

// Public profile. _id is the User's _id (set it when registering), so every
// other collection can ref "Profile" with the user id.
const profileSchema = new Schema(
  {
    _id: { type: Schema.Types.ObjectId, required: true },
    handle: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
      match: /^[a-z0-9_]{3,30}$/,
    },
    name: { type: String, required: true, trim: true, minlength: 1, maxlength: 80 },
    // Hacky avatar options (still being designed). Validate the shape with Zod in the route.
    hackyStyle: { type: Schema.Types.Mixed, default: () => ({}) },
    // A site path (/assets/...) or an https URL. No uploads yet.
    photoUrl: { type: String, match: /^(\/assets\/|https:\/\/)/ },
    bio: { type: String, maxlength: 500 },
    // e.g. { github: "https://github.com/...", linkedin: "..." }
    links: { type: Map, of: String, default: () => new Map() },
    isDemo: { type: Boolean, required: true, default: false },
  },
  { timestamps: true },
);

// Search (GET /api/search?q=): handle is stored lowercase with a unique index,
// so a lowercase anchored prefix (/^juan/) uses it. A contains match on name
// (/juan/i) scans the collection, which is fine at hackathon size.
// Always escape q before building a RegExp.

export type Profile = InferSchemaType<typeof profileSchema>;
export const ProfileModel = model("Profile", profileSchema);
