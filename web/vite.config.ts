import react from "@vitejs/plugin-react";
import { defineConfig } from "vitest/config";

export default defineConfig({
  plugins: [react()],
  server: { proxy: { "/api": "http://127.0.0.1:8787" } },
  // Threads avoid fork-worker transform copies in Windows' restricted temp directory.
  test: { environment: "happy-dom", restoreMocks: true, pool: "threads" },
});
