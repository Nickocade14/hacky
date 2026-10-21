import { Schema, model, type InferSchemaType } from "mongoose";

// Login identity only. Public info (name, handle, photo) lives in Profile,
// whose _id is the same as the user's _id.
const userSchema = new Schema(
  {
    email: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
      maxlength: 254,
      match: /^[^\s@]+@[^\s@]+\.[^\s@]+$/,
    },
    // bcrypt hash. select:false so it never leaves the server by accident;
    // the login route asks for it with .select("+passwordHash").
    passwordHash: { type: String, required: true, select: false },
    emailVerified: { type: Boolean, required: true, default: false },
  },
  { timestamps: true },
);

export type User = InferSchemaType<typeof userSchema>;
export const UserModel = model("User", userSchema);
