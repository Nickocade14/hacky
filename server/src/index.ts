import { createApp } from "./app.js";
import { connectDb } from "./db.js";

const app = createApp();
const port = Number(process.env.PORT ?? 8787);
await connectDb();
app.listen(port, () => {
  console.log(`API on http://localhost:${port}/api`);
});
