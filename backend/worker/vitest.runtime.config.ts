import { defineConfig } from "vitest/config";
import { cloudflareTest } from "@cloudflare/vitest-plugin";
export default defineConfig({
  plugins: [
    cloudflareTest({
      wrangler: { configPath: "./wrangler.jsonc" },
      miniflare: {
        bindings: {
          TEAM_ACCESS_TOKEN: "fixture-only-token-with-at-least-32-characters",
          GEMINI_API_KEY: "",
        },
      },
    }),
  ],
  test: { include: ["test/runtime/**/*.test.ts"] },
});
