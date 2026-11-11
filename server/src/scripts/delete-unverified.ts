// One-off cleanup after the switch to sign-up codes. Before it, register
// created the User and Profile right away, so sign-ups that never verified
// still hold their email and username. This deletes them (User + Profile,
// which share the _id) and the old `authtokens` collection.
//   npm run db:delete-unverified            shows what would go
//   npm run db:delete-unverified -- --yes   deletes it
import mongoose from "mongoose";
import { connectDb, disconnectDb } from "../db.js";
import { MembershipModel } from "../models/Membership.js";
import { ProfileModel } from "../models/Profile.js";
import { UserModel } from "../models/User.js";

const apply = process.argv.includes("--yes");

await connectDb();
const users = await UserModel.find({ emailVerified: false }).select("_id createdAt").lean();
const ids = users.map((user) => user._id);
const profiles = await ProfileModel.find({ _id: { $in: ids } }).select("handle").lean();
// An unverified account can't log in, so it can't have joined an event. Check anyway.
const joined = await MembershipModel.countDocuments({ user: { $in: ids } });
const hasTokens = (await mongoose.connection.db!.listCollections({ name: "authtokens" }).toArray()).length > 0;

console.log(`Unverified accounts: ${users.length}`);
for (const profile of profiles) console.log(`  @${profile.handle}`);
console.log(`Old authtokens collection: ${hasTokens ? "yes" : "no"}`);

if (joined > 0) {
  console.log(`Stopped: ${joined} event memberships belong to these accounts. Nothing was deleted.`);
} else if (!apply) {
  console.log("Dry run. Run again with -- --yes to delete.");
} else {
  await mongoose.connection.transaction(async (session) => {
    await ProfileModel.deleteMany({ _id: { $in: ids } }, { session });
    await UserModel.deleteMany({ _id: { $in: ids }, emailVerified: false }, { session });
  });
  if (hasTokens) await mongoose.connection.db!.dropCollection("authtokens");
  console.log(`Deleted ${users.length} accounts${hasTokens ? " and the authtokens collection" : ""}.`);
}
await disconnectDb();
