import mongoose from "mongoose";

// Call once at startup, before app.listen().
export async function connectDb(uri = process.env.MONGODB_URI): Promise<void> {
  if (!uri) throw new Error("MONGODB_URI is not set (see server/.env.example)");
  mongoose.set("strictQuery", true);
  // Field validators (enum, maxlength, match...) also run on updateOne/findOneAndUpdate.
  // pre("validate") hooks still only run on save()/create(): rules that compare
  // fields go in the update filter (see the helpers in models/).
  mongoose.set("runValidators", true);
  // Indexes are created by `npm run db:indexes`, not on every boot.
  await mongoose.connect(uri, { autoIndex: false });
}

export async function disconnectDb(): Promise<void> {
  await mongoose.disconnect();
}
