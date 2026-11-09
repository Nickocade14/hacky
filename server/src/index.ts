import { createApp } from "./app.js";
import { connectDb } from "./db.js";

if ((process.env.JWT_SECRET ?? "").length < 32) {
  throw new Error("JWT_SECRET must be set to at least 32 characters (see server/.env.example)");
}

const app = createApp();
const port = Number(process.env.PORT ?? 8787);
await connectDb();
app.listen(port, () => {
  console.log(`API on http://localhost:${port}/api`);
});
