# GitLore on Cloudflare Workers

This is the selected hosted-server implementation. Flutter stays in Dart; Workers
runs TypeScript. The Dart server above remains an optional local prototype.
Both implement [analysis schema v1](../contracts/analysis-v1.schema.json).
This change has not deployed Cloudflare resources or configured live secrets.

## Architecture and reasons

```text
Flutter -> Worker: CORS / team code / bounded JSON validation
        -> SQLite Durable Object: admission / current GitHub commit / cache
        -> bounded public GitHub samples -> static analysis
        -> optional Gemini chapters -> checked citations -> schema v1 -> Flutter
```

A lightweight Worker delegates analysis to one SQLite-backed `AnalysisCoordinator`
named `gitlore-team-v1`. Durable storage preserves quotas/cache across restarts.
SQLite Durable Objects are [available on Workers Free](https://developers.cloudflare.com/durable-objects/platform/pricing/).
They have a [separate CPU allowance](https://developers.cloudflare.com/durable-objects/platform/limits/),
so source parsing stays outside the Free Worker's tight CPU limit. Hosted resource
usage, account eligibility and actual latency still require verification.

This is a small private-team service with one shared code, not user accounts.
Anyone with the code can spend the team's budget. CORS supplements authentication.
Keep the account on Free and do not enable billing to resolve limits. Cloudflare,
Google and GitHub apply their own quotas independently of these safeguards.

| Bound | Behavior |
| --- | --- |
| Access | Bearer team token required, at least 32 characters, including locally |
| Origins | Exact comma-separated browser allowlist, no wildcard |
| Request | Schema 1; public GitHub root URL; 4,096 bytes; ten-second body deadline |
| Team API budget | 100/day and 10/minute; cache hits count |
| Concurrent work | Two distinct jobs; overlapping identical calls share work |
| Gemini budget | 20 actual attempts/day including retries; 15-second new-job cooldown |
| Retry | Once on HTTP 500/502/503/504, Retry-After up to two seconds; no 429/auth retry |
| Deadlines | GitHub 20 seconds/request, 90 total; Gemini 20 seconds/attempt within 45 total |
| Source | Eight files; 40,000 bytes/file; 180,000 combined; 8 MB tree / 70 KB blob JSON |
| AI input | 100 lines and 5,000 characters/file; 24,000 characters combined |
| Output | 1.5 MB; AI evidence must cite supplied lines belonging to an existing node |
| Cache | Ten entries; ten-minute TTL; durable LRU keyed by commit, analyzer, model and prompt |

Budgets reset at midnight UTC; minute counters use clock buckets. Every lookup
rechecks GitHub metadata/current commit, so refresh observes new commits. Provider
failures return a labeled static fallback and are not cached as successful AI.
Repository code is never executed. AI retains the static import graph.

## Local setup

Use Node.js 24 (minimum 22) and npm. From this directory:

```sh
npm ci
```

Copy `.dev.vars.example` to `.dev.vars` without overwriting an existing file.
Set a random local `TEAM_ACCESS_TOKEN` of at least 32 characters. Leave
`GEMINI_API_KEY` empty for static-only testing, or enter it locally. Never log,
share or commit this file. Workers does not read `backend/.env`.

```sh
npm run dev
```

The local endpoint is port 8087. `/health` reports configuration presence only:
200 when token/model/binding are configured, otherwise 503. `aiConfigured` means
a key is present; it does not prove Google accepted the key or has quota.

Run Flutter web on port 8086, enable **AI explanation**, and open **Server
settings**. Enter the Worker URL and team code. App defaults already use
localhost:8087 (Android emulator uses 10.0.2.2). The team code stays in app-session
memory; the Gemini key never enters Flutter. Turning AI off retains direct,
keyless GitHub analysis. Run only one of the two local backends on port 8087.

`POST /v1/analyze` requires `Content-Type: application/json` and
`Authorization: Bearer <team code>`:

```json
{"schemaVersion": 1, "url": "https://github.com/owner/repo", "ai": true}
```

`ai` defaults to false. Errors contain schemaVersion 1 and an error object with
safe code/message. 401 means invalid team code, 403 a denied origin, 429 the team
budget/concurrency limit, and 503 incomplete configuration. Gemini failures
generally return HTTP 200 with a visibly labeled static result.

## Verification

No tests need real credentials or live provider calls:

```sh
npm ci
npm run format:check
npm run check
npm test
npm run test:runtime
npm run build
```

`build` is a Wrangler dry run. Node fixtures cover HTTP validation, crawler,
lexical imports, citations, retries, transactional quotas and LRU. Runtime tests
exercise actual SQLite Durable Objects and restart one before checking its cache.
All outbound calls are mocked. One Dart-generated example compares both static
analyzers; it is not proof that all language syntax behaves identically.

When intentionally changing shared analysis, run from the repository root:

```sh
dart --packages=.dart_tool/package_config.json tool/generate_worker_fixture.dart
```

Then run `npm run format` here, inspect the fixture and run both suites. CI checks
fixture freshness using `--check`. Keep both implementations synchronized.

## Deployment runbook (owner authorization required)

1. Run checks. Use a **Workers Free** account supporting SQLite Durable Objects.
   Keep `new_sqlite_classes` and migration history. Renaming the singleton or
   changing its namespace without migration loses budgets/cache.
2. Change `ALLOWED_ORIGINS` in `wrangler.jsonc` to the actual web origin, including
   scheme/port. Retain localhost only if needed. `GEMINI_MODEL` is public config;
   confirm it is available on the team's Google free tier.
3. Authenticate with `npx wrangler login`. Enter secrets through prompts using
   `npx wrangler secret put TEAM_ACCESS_TOKEN` and
   `npx wrangler secret put GEMINI_API_KEY`. Never put secret values in command
   arguments, configuration, Flutter defines or GitHub build variables.
4. Run `npm run deploy` only once authorized. The migration creates SQLite
   storage. Check health, denied access, a small real repository and hosted CPU
   usage before requesting AI. Confirm usage stays within the selected Free plan.
5. Set the URL in app Server settings, or build with the public URL only:
   `--dart-define=GITLORE_API_URL=https://<your-worker-host>`. Enter the team code
   at runtime. Confirm CORS from the web origin and HTTPS from Android.
6. Verify real AI citations, static fallback, refresh after a new commit, app
   restart, quotas and secret rotation. Do not print provider bodies or keys.

Rotate keys using `wrangler secret put` again; update app sessions when rotating
the team code. Observability is disabled to reduce accidental source/key logging.
Review future logging before enabling it. CI builds artifacts; it never deploys.

## Remaining limitations

- Hosted provisioning, live secrets/Gemini, CPU/memory fit and public uptime are
  unverified. Local fixtures do not establish these properties.
- Public launch needs individual identity and stronger abuse controls. Invalid
  requests do not reach the coordinator but can still consume Worker requests.
- GitHub is unauthenticated and shares server-side public API quotas; even the
  app's daily request budget does not guarantee GitHub capacity.
- Saved projects stay on-device. Explore, shared history, progress streaming,
  background jobs and automatic graph layout remain separate work.
