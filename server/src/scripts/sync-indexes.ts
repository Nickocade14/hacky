// Creates/updates every index defined in the models. Run after changing a model:
//   npm run db:indexes
import mongoose from "mongoose";
import { connectDb, disconnectDb } from "../db.js";
import "../models/index.js";

await connectDb();
for (const name of mongoose.modelNames()) {
  const dropped = await mongoose.model(name).syncIndexes();
  console.log(`${name}: indexes in sync${dropped.length ? ` (dropped ${dropped.join(", ")})` : ""}`);
}
await disconnectDb();
