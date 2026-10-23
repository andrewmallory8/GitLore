# GitLore contributor instructions

Read [docs/HANDOVER.md](docs/HANDOVER.md) before changing code. It records the
product goal, implemented architecture, decisions, priorities, and verification.
Check the working tree and recent commits first; preserve other contributors' work.

## Working rules

- Continue the existing Flutter/Dart application. A React/Next.js rewrite is not
  part of the current plan. Keep the product usable without API keys or paid services.
- Put data types in `lib/models/`, fetching/analysis/storage in `lib/services/`,
  and reusable UI in `lib/widgets/`. Keep network and business logic out of widgets.
  Extract new screens from `lib/main.dart` as the UI grows.
- Shared non-Flutter models and services live in `packages/gitlore_core/lib/`
  under the same `models/` and `services/` folders. The matching `lib/` files are
  compatibility exports; edit the shared implementation, not the export files.
  Workers code lives in `backend/worker/`; keep its schema and parity fixtures
  synchronized with the shared Dart contract.
- Keep `ArchitectureService` injectable. New services need deterministic fixture
  tests; tests must not depend on live GitHub, LLM credentials, or paid accounts.
- Preserve source evidence and uncertainty. Import edges are not runtime data
  flow. Demo results and future AI-generated results must be clearly identified.
- Never execute crawled repository code. Treat repository content and future LLM
  output as untrusted data. Keep crawler size, request, and timeout limits intact.
- Never put GitHub tokens, LLM keys, or Supabase service-role keys in Flutter,
  `--dart-define`, Git commits, screenshots, or logs. Privileged keys belong on a server.
- Use focused feature branches and pull requests. Keep generated SDK/platform
  files and unrelated dependency upgrades out of feature changes. Commit the lockfile
  when dependencies intentionally change. Do not merge or deploy without authorization.

## Finish each change

Run the CI-equivalent checks from the handover: locked dependency restore,
format check, static analysis, tests, and release web build. Add meaningful tests
for changed logic and user behavior. Record failures and unavailable checks honestly.

Update `docs/HANDOVER.md` before finishing: completed work, decisions, validation,
known issues, and the next concrete task. Update README when setup or visible behavior
changes. Summarize the outcome, checks, and remaining limitations in the final response.
