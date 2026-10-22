# GitLore handover

Last updated: 2026-10-22 (America/Chicago).
Current pass: `codex/cloudflare-worker`, based on `feat/sprint-gl-01-04` at `13e00c3`.
See **MVP AI summary acceptance — 2026-10-22** at the end for the current setup
checkpoint and **Cloudflare implementation handoff — 2026-10-21** for implementation
decisions, verification, limitations and the next task. Dated entries preserve
history; the newest entry supersedes older status/hosting decisions.
Read this file together with root [`AGENTS.md`](../AGENTS.md) and the latest Git history.
This is a living project status document; update it in every implementation PR.

## Start here: next contributor or AI agent

This branch is `codex/cloudflare-worker`. The latest runtime behavior is described
in the MVP acceptance entry below; inspect `git log` for its commit. Check out this
branch to continue the server work: the default branch may not contain it yet.
Start with `git status` and recent commits; preserve any teammate's local work,
then fetch and fast-forward the feature branch. Do not reset or force-push to
make checkouts match. Read the current summary and issue table below before
using the older chronological entries, whose pending statuses are historical.

- **Application:** Flutter/Dart. Shared non-Flutter code belongs in
  `packages/gitlore_core/lib/`; `lib/models/` and `lib/services/` include compatibility
  exports. Worker server code belongs in `backend/worker/src/`, with services in
  its `services/` subfolder. Keep fetching and analysis out of widgets.
- **Hosted service:** <https://gitlore-api.jack-j-dugan.workers.dev>.
  Cloudflare Worker `gitlore-api`; durable class `AnalysisCoordinator`, binding
  `ANALYSES`, migration `v1`. Preserve the singleton name, namespace and secrets
  when updating it. Never recreate storage to clear budgets or cache.
- **Secrets:** Gemini and team credentials are already encrypted in Production.
  They are intentionally absent from Git. Another laptop needs its own private
  local configuration and developer authorization; do not copy this machine's
  OAuth credentials. The owner supplies the existing team code privately for app
  Server settings. Never generate a replacement production code unintentionally.
- **Runtime settings:** default `gemini-3.5-flash-lite`, prompt `worker-story-v5`;
  browser origins localhost/127.0.0.1 on port **8086**. Local optional server uses
  **8087**. AI is off by default; static mode needs no keys. Flutter keeps the team
  code only for the current app session. The Gemini key never enters the client.
- **Checks:** follow the exact commands below and
  [`backend/worker/README.md`](../backend/worker/README.md). Fixtures must remain
  deterministic and credential-free. See the latest dated entry for current tests, analysis,
  formatting, fixture parity and release web/Worker builds. GitHub Actions builds
  on push/PR; it does not deploy. A push is not evidence that CI passed.

### Current issues, fixes and next actions

| Priority / issue | Confirmed evidence and fix | Next action / completion criterion |
| --- | --- | --- |
| Done: real hosted AI result | Real Hello-World, is-number and Express results passed through the Cloudflare/Dart adapter path. The first cited overview now supplies the actual AI summary. | Repeat the manual app demo before submission; preserve safe static fallback and distinguish it from AI success. Exact commit/timestamp evidence is recorded below. |
| Mitigated: shared GitHub quota | The server can still return `github_limit`. The updated app fetches bounded public source and uploads it to the server for AI when that happens. Express passed this path and reused its AI cache. | Use the updated app/service; a plain `/v1/analyze` caller still needs to handle limits. Keep client provenance explicit and respect client/provider quotas. Do not remove immutable-commit checks or increase limits to hide failure. |
| P1: validate app integration | Server URL is the Flutter default; adapter/schema and widget fixtures pass. Fresh authenticated browser/native acceptance has not been performed. | On port 8086, enter the existing team code in Server settings, enable AI, analyze a small repository, follow chapter/node evidence links and test retry/fallback. Repeat on Android; verify HTTPS and restart/session behavior. |
| P1: test-tool advisories | Locked Vitest 4.1.11 / `@vitest/mocker` has two moderate findings; no test code is bundled in the Worker. | Make a focused tooling patch to a version addressing GHSA-qxg6-89mg-rqv8 and GHSA-xp26-3454-mjgp (audit indicated 4.1.12), commit the lockfile, rerun Node/workerd checks and audit. |
| P1: hosted capacity and observability | Team budgets and SQLite fixtures pass; normal small static calls worked. Maximum-size hosted CPU/memory, sustained availability and sanitized logs/traces are unverified. | Benchmark within existing source/request limits on Free; design redacted diagnostics before enabling observability. Do not turn on billing to resolve a failure. |
| P2: product backlog | Static import map, chapters, source links, zoom controls and local saved projects exist. | Prioritize automatic graph layout, monorepo sampling, Explore/shared history and eventual user accounts/abuse controls. Preserve evidence and uncertainty; import edges remain distinct from runtime data flow. |

### Safe troubleshooting sequence

1. Check `/health`. `aiConfigured:true` means a key is present, not that generation
   succeeded. A 401 means the team code is wrong; a 403 can mean the browser origin
   is denied. See the Worker runbook for exact request/response details.
2. With the existing team code supplied privately, use the protected
   `POST /v1/diagnostics/gemini` with `{"schemaVersion":1,"mode":"ping"}` to test
   provider access without GitHub. Inspect `outcome`, not just HTTP 200. Use
   `mode:"story"` to test the real prompt/schema/citation checks on synthetic files.
   Wait at least 15 seconds between new AI jobs; every provider attempt counts
   against the same **20/day** team budget, including diagnostic retries.
3. Run one real repository analysis, then repeat it to confirm cached AI reuse
   without a new provider call. The server still checks the current commit.
   Do not remove those checks or serve expired results to hide a quota failure.
4. If fallback occurs, distinguish provider timeout/HTTP status, invalid evidence,
   team budget/cooldown and GitHub quota before changing code. Never print keys,
   provider diagnostic bodies or arbitrary source content for troubleshooting.
5. Update this current summary, known issues and the dated evidence after each
   change. Record local checks separately from hosted acceptance and GitHub CI;
   leave explicit next steps whenever a check is blocked or unavailable.

## Goal and scope

Paste a public GitHub repository URL and receive an interactive architecture map
plus an approachable, chapter-by-chapter explanation of how its code fits together.
The eventual storybook/comic experience should explain request-to-database flow
when the source supports it, with clickable evidence and clear uncertainty.
An Explore page and saved analyses should help users revisit useful repositories.

The project targets a $0 operating budget: public GitHub REST access, optional
free-tier Gemini/Groq analysis, and a possible Supabase free tier for storage.
Free quotas are limits, not guarantees; preserve a useful keyless static-analysis path.
Do not enable billable services or silently introduce a paid dependency.

## Read this status first

**Implemented:** Flutter public-repository analysis, bounded source sampling,
lexical import edges, navigable canvas with pan/zoom/fit/reset, chapters and source
links; session analysis cache/refresh; on-device saved projects; schema v1 and an
optional server adapter; Dart/Gemini local prototype. One earlier local Gemini
success was reported, alongside frequent 503 fallbacks.

**This pass adds:** Cloudflare Workers backend, SQLite Durable Object cache and
team budgets, bounded Gemini retries/evidence validation, a shared Dart package
that fixes backend import analysis, deterministic cross-language/runtime fixtures,
and expanded CI. The Worker is deployed with both encrypted secrets. Hosted
authentication, CORS, static analysis and cache checks passed. Flash-Lite now
passes live connection and synthetic chapter/citation checks after the timeout
fix. Real-repository AI summaries and cache reuse now pass, including the client
snapshot fallback when the server's GitHub quota is limited.

**Still pending:** manual Flutter browser/native
acceptance against the server; maximum-size hosted resource checks; individual user
accounts/public abuse controls; automatic layout, Mermaid export, Explore, shared
history and broader mobile/restart acceptance. Static import edges are not runtime
traces, and AI explanations remain clearly labeled interpretations.

## Setup and commands

Use Flutter **3.47.2 stable**, which bundles Dart **3.13.2**. CI reads its Flutter
version from `environment.flutter` in `pubspec.yaml`. Change the SDK pin deliberately
and verify the lockfile and all checks together; do not downgrade the Dart constraint
to accommodate an older local SDK. No environment variables or API keys are currently required.

```sh
flutter --version
flutter pub get --enforce-lockfile
cd backend
dart pub get --enforce-lockfile
cd ..
flutter run -d chrome
```

Offline UI development: inject `DemoArchitectureService` through
`GitLoreApp(service: DemoArchitectureService())`. This remains explicitly labeled a demo.

Verification, matching CI:

```sh
dart format --output=none --set-exit-if-changed lib test tool packages/gitlore_core/lib backend/bin backend/lib backend/test
flutter analyze --no-pub
flutter test --no-pub --coverage
dart --packages=.dart_tool/package_config.json tool/generate_worker_fixture.dart --check
flutter build web --release --no-pub
cd backend
dart analyze --fatal-infos
dart test
cd worker
npm ci
npm run format:check
npm run check
npm test
npm run test:runtime
npm run build
```

`npm run build` only bundles the Worker; it does not deploy. Format Dart edits
with the same directories above and use `npm run format` for the Worker. The optional live
smoke test is `dart run tool/analyze_repository.dart https://github.com/expressjs/express`.
It consumes public GitHub requests and intentionally stays outside CI.

On Windows, Flutter may report that native plugins require symlink support.
Enable Windows Developer Mode if building desktop targets. In this environment,
dependency packages restored before that warning; the `--no-pub` checks can be tried
with those restored packages. Do not report a failed restore as a successful check.

## Current structure and boundaries

| Location | Responsibility |
| --- | --- |
| `lib/main.dart` | App theme, URL form, loading/errors, workspace, chapters, sources, AI/server settings and local bookshelf |
| `packages/gitlore_core/lib/models/` | Shared pure Dart result, evidence, nodes, chapters and source URLs |
| `packages/gitlore_core/lib/services/` | Injectable analysis boundary, crawler/analyzer/imports, codec, session cache, persistent shelf and server adapter |
| `lib/models/`, `lib/services/` | Compatibility exports for the shared package, except Flutter-specific adapters |
| `backend/worker/src/` | Cloudflare API, durable coordinator/budgets/cache, TypeScript crawler/static analyzer/Gemini |
| `backend/contracts/` | Schema v1 shared by Flutter and both backends |
| `backend/lib/` | Optional Dart local prototype; imports shared package |
| `lib/widgets/architecture_canvas.dart` | Clickable nodes, directed import arrows, selection highlighting, scrolling |
| `test/` | Mocked crawler/unit tests and Flutter widget tests |
| `tool/analyze_repository.dart` | Optional real-GitHub CLI smoke test |
| `.github/workflows/ci.yml` | SDK install, locked restore, formatting, analysis, tests/coverage, release web artifact |
| `android/`, `ios/`, `linux/`, `macos/`, `windows/`, `web/` | Platform scaffolding; avoid incidental generated-file changes |

Current flow:

```text
URL form -> session cache -> GitHub crawler -> RepositoryAnalyzer -> Architecture
                                                               -> map / chapters / sources
                                                               -> persistent on-device bookshelf
```

The cache lives with the workspace state and wraps the injected analysis service.
Keys are validated owner/repo URLs normalized case-insensitively; `.git` and trailing
slashes share results. Successful results expire ten minutes after completion;
cache hits do not extend that lifetime. Least recently used entries are evicted
above ten. Concurrent calls for one repository share a request. Refresh bypasses
completed cache entries; failures are not cached and a failed refresh discards the
old cache entry. Saved projects remain separate snapshots until explicitly saved again.
The client cache resets on reload; saved snapshots persist through a versioned
shared-preferences storage adapter. AI mode routes through the optional server
adapter. Worker cache/budgets are durable; see the latest appendix. The CLI uses
the raw crawler.

## Contracts to preserve

- Input: HTTPS `github.com/owner/repo`, optionally `.git` or a trailing slash.
  Other hosts, credentials, ports, query strings, fragments, and nested tree URLs
  are rejected before network requests. A `FormatException` contains a user-readable error.
- Service: `Future<Architecture> analyze(String url)`; the cache additionally exposes
  `refresh(String url)`. Crawler failures surface as `AnalysisException` messages.
- `Architecture`: `repository` is canonical `owner/name`; `commitSha` identifies a
  live snapshot (`null` means demo); `branch`, `summary`, `technologies`, `warnings`,
  and `fileCount` describe scope. `files` contains sampled path/content pairs.
- Nodes: stable unique IDs, labels, kinds, descriptions, and associated file paths.
  The current UI expects at least one node and story step. Metadata-only results
  include an overview node; each step's `nodeId` must identify an existing node.
- Edges: `from` imports `to`, with both IDs present in nodes. Do not infer request
  flow from edge direction or vertical ordering. The canvas filters invalid,
  duplicate, and self edges. Import matching is approximate and limited to sampled files.
- Sources: `Architecture.sourceUrl(path)` uses the analyzed commit, never a moving
  branch for live results. Excerpts currently show only the first 24 lines.
- Limits: metadata + branch commit + recursive tree, then at most eight text blobs;
  40,000 bytes per file and 180,000 bytes combined; tree responses capped at 8 MB,
  blob JSON at 70 KB, requests/stream inactivity at 20 seconds. Symlinks, binary,
  generated/vendor/test/example files, and lockfiles are skipped by current rules.

Schema v1 exists in `backend/contracts/analysis-v1.schema.json`. Shared Dart codec
and Worker validators enforce references and bounds. AI chapters cite path/line
ranges in sampled files on the analyzed commit; the graph remains static imports.
Validate output, preserve uncertainty and retain static fallback. No Supabase
schema or shared user database exists yet.

## Planned architecture and four-person ownership

Keep Flutter as the shared UI. `backend/worker/` is the selected hosted server,
with its own README/tests; `backend/lib/` retains the local Dart prototype.
The server flow is URL validation -> bounded GitHub snapshot -> analysis
cache -> optional LLM with validated evidence -> versioned result -> Flutter UI.
Supabase may persist normalized summaries and curated public analyses behind
documented access rules; implement and test row-level security before shared writes.

| Workstream | Existing starting point | Next responsibility |
| --- | --- | --- |
| Dev 1: diagram canvas | `lib/widgets/architecture_canvas.dart` | Automatic layout, mobile acceptance and possible export |
| Dev 2: GitHub crawler | Shared Dart services, `backend/worker/src/services/` | Hosted acceptance, monorepo sampling and API capacity |
| Dev 3: prompt engine | Worker Gemini adapter, shared schema/models | Hosted provider verification and richer evidence-backed explanations |
| Dev 4: saved projects/UI | `lib/main.dart`, bookshelf service | Restart/mobile acceptance, screen extraction, progress and Explore |

Coordinate model/API changes across workstreams before implementation. These are
responsibilities, not claims that people or hosted services have already been assigned.

## Decisions and reasons

| Decision | Reason and consequence |
| --- | --- |
| Continue Flutter instead of the original React/Next.js sketch | The inherited app and tests already work in Flutter; preserve that investment and keep services independent of the UI. |
| Keep static analysis as the default | It works without credentials and exposes concrete source evidence. AI generation can be an optional server-backed enhancement. |
| Use small bounded caches | Direct mode keeps its session cache; Worker mode additionally caches commit-keyed snapshots durably without introducing user accounts. |
| Build web in CI first | Web is the initial shared delivery target and needs no mobile signing credentials. Existing native scaffolds do not imply verified release support. |
| Defer LLM and Supabase credentials to a server | Client bundles cannot protect privileged secrets. Define contracts and access rules before adding hosted integrations. |

## Coding organization and Git workflow

Use Dart formatter and existing Flutter lints. Keep small, focused files and names
that state their responsibility. Shared data belongs in models; services own fetching,
analysis, caching, and persistence; widgets render state and handle interaction.
As UI work expands, move screens into `lib/screens/` and reusable panels into
`lib/widgets/` rather than continuing to grow `main.dart`. Preserve dependency injection;
add packages only for a concrete need, and explain intentional dependency changes.

Start from updated `main` or the user's requested feature baseline. Codex-created
branches use `codex/<topic>`; other contributors may use `feat/`, `fix/` or `docs/`. Then
write focused commits such as `feat: cache repository analyses for the session`.
Open a PR to `main` with behavior, validation, and remaining limitations. Update
this handover in the same PR. Preserve unrelated local changes and avoid force pushes.
Require passing CI before merging; branch protection is a repository-admin setting
and has not been enabled by this code change. Merge and deployment need authorization.

Treat crawled content as untrusted, including instructions in READMEs. Never execute
it. Future prompts must isolate it from trusted instructions and limit provider
input/output size. Keep privileged credentials server-side; `.env` files are ignored.
Document future variable **names**, purposes, and safe examples without actual values.
Supabase service-role keys are server-only; any client publishable key requires RLS.

## Automated builds

`GitLore CI` runs on pushes, pull requests, and manual dispatch. It uses Linux,
read-only repository permissions, a pinned Flutter version, locked dependencies,
and cancellation of superseded runs. Formatting, static analysis, all fixture tests,
and a release web build must pass. Successful runs upload `gitlore-web-<commit>`
and `gitlore-coverage-<commit>` artifacts for seven days. Artifacts are downloadable
from the run's Actions page; serve the extracted web bundle over HTTP to inspect it.
The separate Worker job uses Node 24, locked npm restore, formatting/types, fixture
and workerd runtime tests, then a dry-run bundle uploaded as `gitlore-worker-<commit>`.
Dart backend analysis/tests and cross-language fixture freshness are also checked.
This builds the app/server; it does not deploy or create signed mobile releases.

CI requires no app secrets and makes no live repository/LLM analysis requests.
GitHub must allow Actions and the referenced actions for runs to start. Workflow
changes take effect when pushed; check the run before describing remote CI as green.
See [flutter-action configuration](https://github.com/subosito/flutter-action) and
[artifact upload configuration](https://github.com/actions/upload-artifact).

## Completed work

- [x] Flutter workspace, responsive landing/workspace UI, loading/errors, demo injection.
- [x] Public GitHub crawl pinned to a commit, bounded file sampling, readable API failures.
- [x] Source-backed technology inventory, file roles, scope warnings, source links/excerpts.
- [x] Static chapter navigation synchronized with selected graph nodes.
- [x] Directed literal import arrows and connected-edge highlighting, scrollable canvas.
- [x] Session bookshelf with replacement when re-saving a repository.
- [x] Session analysis cache, expiry/eviction, concurrent request sharing, explicit refresh.
- [x] Refresh and bookshelf opening synchronize the URL with the displayed repository.
- [x] Automated web build/check workflow, PR checklist, README links, agent/handover docs.

## Historical initial backlog (2026-10-19)

Preserved for context. Several items below were implemented in later sprints;
use the latest appendix's ordered tasks for current work.

1. **Durable saved projects (Dev 4).** Extract a storage service with a versioned
   serialization contract. Save/open/delete analyses across app restarts; handle
   corrupt, outdated, and full storage without crashing. Show snapshot age/commit.
   Test restart recovery, deletion, replacement, and storage failures with fixtures.
2. **Diagram navigation (Dev 1).** Add zoom, fit/reset, and automatic layout while
   preserving source selection, import semantics, accessible labels, and unconnected
   nodes. Verify cycles, dense maps, narrow screens, and larger graphs.
3. **Progress and crawler coverage (Dev 2/4).** Show fetch/analyze phases; improve
   monorepo/entry-point sampling within explicit budgets. Test partial results,
   truncation, cancellation/navigation, and rate-limit messages.
4. **Server foundation (Dev 2/3).** Pick a free hosting option, define/test the API,
   validate public URLs, isolate credentials, add abuse/rate limits and shared cache
   keys including repository + commit + analyzer version. Document setup and costs.
5. **Optional AI storybook (Dev 3).** Implement one server-side provider behind an
   adapter, strict evidence/schema validation, prompt fixtures and failure fallback.
   Show AI/inferred/observed distinctions; no unsupported request/database story.
6. **Explore and shared persistence (Dev 4).** Curate real public results, add
   Supabase migrations/RLS if selected, test stale schema/commit handling and access.
7. **Export and release.** Decide whether Mermaid export adds value alongside the
   Flutter map; escape untrusted labels and preserve edge meaning. Configure hosting
   only after review. Add native build/signing checks when those targets become required.

## Historical initial limitations and validation record (2026-10-19)

The following describes the initial pass, not the current implementation.

- No parser-level import resolution: comments may produce false matches; aliases,
  dynamic imports, many languages, and unsampled files can be missed.
- Graph layout is a vertical list with curved lanes and scrolling. No zoom/fit yet.
- Session cache saves repeated client requests only; it does not share results
  between users or survive reload. A cached snapshot may be ten minutes old.
- UI/service models currently assume nonempty nodes and steps; preserve that contract
  or introduce explicit empty-result handling before adding a new analysis provider.
- No full request trace, AI generation, persistent bookshelf, auth, hosting, or CI
  validation for native platforms yet.
- Verified locally on 2026-10-19 with Flutter 3.47.2 / Dart 3.13.2: locked dependency
  restore, format check (12 files unchanged), static analysis (no issues), all
  **26 tests** with coverage, and release web build **passed**. The first restore
  showed a Windows symlink warning; the final restore completed with exit code 0.
- Delivery branch: `feat/handover-ci-analysis-cache`; review
  [PR #3](https://github.com/andrewmallory8/GitLore/pull/3). The first
  [GitHub CI run](https://github.com/andrewmallory8/GitLore/actions/runs/39341312214)
  for code commit `5162802` **passed**, including release web compilation and both
  downloadable artifacts (web bundle and coverage). This documentation update
  triggers fresh checks; consult the PR for the latest status. Native release
  builds and the optional live CLI were not run.

## End-of-session update checklist

Record the branch/PR and date, what changed, decisions with reasons, exact checks
and outcomes, reproducible bugs/blockers, and the next priority with acceptance
criteria. Mark completed tasks and remove stale claims. Never record secrets.
The next agent should inspect Git status/history, read this file, run the checks,
and take the first unfinished priority appropriate to the user's request.


## Sprint update — GL-01 and GL-02, 2026-10-19

This append-only update preserves the complete prior handover above. Where the
historical status says zoom/fit is absent or imports use raw regex, this update
supersedes that status. Earlier validation results describe earlier commits, not
this sprint.

### Branch, scope, and user decisions

- Development branch: `feat/sprint-gl-01-04`, based on `main` at `fb58105`.
- User requested a local commit of GL-01 and GL-02 after reporting that the demo
  worked well. No push, merge, deployment, or remote PR is authorized by this
  commit request. Keep changes local until the user explicitly requests a push.
- GL-03 (analysis server/response contract) and GL-04 (persistent bookshelf) remain
  unimplemented. AI integration is explicitly deferred while the user discusses
  provider and cost choices with teammates. Do not enable an AI provider or billing.
- A pre-existing `pubspec.lock` change adjusts only the Flutter SDK constraint
  from `>=3.44.0` to `3.47.2`, matching the existing pubspec pin. It is preserved
  locally and excluded from the GL-01/GL-02 commit; no dependencies were added.

### GL-01 — graph navigation

- `lib/widgets/architecture_canvas.dart` now uses a stateful `InteractiveViewer`
  with drag-to-pan, pinch zoom, Zoom in/out, Fit to view, and Reset controls.
- Zoom is centered on the viewport; fit includes the entire scene, including
  unconnected nodes and import lanes. Reset restores original scale/position.
  Controls wrap on narrow screens. The vertical node layout is retained;
  automatic layout is still future work.
- Node selection, edge highlighting, source excerpts, and import direction remain
  intact. New graph data resets the transform. Corrected a scale calculation
  found during the live demo so zoom after fitting changes incrementally.
- Updated canvas tests cover fit bounds, zoom/reset, pan, and selection at
  320px and 1100px widths, alongside existing cycle/invalid-edge coverage.

### GL-02 — import resolution

- Added `lib/services/import_resolver.dart`; `RepositoryAnalyzer` delegates import
  extraction/resolution to it. Repository code is never executed.
- The lexical scanner skips line/block comments and ordinary quoted strings;
  recognizes JS/TS static imports, re-exports, literal `require` calls, and
  relative Dart import/export directives.
- Resolves sampled exact paths first, then extensionless and directory-index
  candidates (.ts, .tsx, .js, .jsx, .mjs, .cjs); supports .js-to-.ts/.tsx fallback.
  Self edges, duplicates, and unresolved targets are omitted.
- Added six fixture groups in `test/import_resolver_test.dart`, covering supported
  declarations, comments/strings/templates/regex, unsupported references,
  multiline/comment-separated syntax, Dart, and malformed/missing paths.
- This is a lexical subset, not compiler-level resolution. Aliases, package
  resolution, dynamic `import()`, computed require, escaped paths, template
  interpolation, JSX text parsing, and scope/shadowing analysis are unsupported.
  Regex recognition remains heuristic. Unsampled files cannot produce edges.
- README now documents the controls, supported resolution rules, and limitations.

### Validation and demo record

Passed locally with Flutter 3.47.2 / Dart 3.13.2:

- `flutter pub get --enforce-lockfile`
- `dart format --output=none --set-exit-if-changed lib test tool` (14 files)
- `flutter analyze --no-pub` (no issues)
- `flutter build web --release --no-pub`
- `git diff --check`
- All six import fixture groups via a standalone Dart harness using the same
  fixture bodies (temporary harness outside the repo; not a full test-suite run).

Full automated validation remains outstanding: `flutter test --no-pub --coverage`
could not complete because the native x64 engine crashed during CPU detection in
the local sandbox. The Chrome test alternative also failed to launch its browser.
These are not passing widget tests or coverage. Run the full suite in a working
Flutter environment before claiming CI-equivalent validation or full mobile QA.

Manual Chrome release demo at `http://127.0.0.1:8086`: Express analysis loaded six
import edges; Fit showed all nine nodes and lanes, zoom/reset worked, and selecting
utils.js opened its source excerpt. User reported that everything seemed to work
well. The local server is session-dependent; serve a fresh `build/web` if needed.

The emulator's separate internet problem was resolved with Android Studio's Cold
Boot. Android reported validated Wi-Fi and successfully resolved/reached GitHub's
API. A command-line DNS-override launch failed before boot with CPU detection;
no override was needed after the Studio cold boot. Existing apps/data were kept.
This networking check does not establish that the sprint APK was rebuilt/tested.

### Next concrete work

1. Complete full fixture/widget tests and coverage in a working environment;
   validate pinch and source interaction on the current Android sprint build.
2. On user direction, implement GL-03's versioned JSON request/response contract
   and bounded server endpoint, reusing Dart crawler/analyzer logic. The proposed
   optional Flutter server adapter should preserve direct keyless analysis.
3. Keep AI integration deferred; GL-04 durable storage and automatic graph layout
   remain pending. Inspect Git status before starting and preserve the local
   lockfile adjustment. Do not push without explicit user authorization.


## Local AI demo preparation — 2026-10-20

User authorized Gemini free-tier integration and GL-03/GL-04 development. This
supersedes the earlier AI deferral. Hosting remains undecided: Render was rejected
for idle sleep; Cloudflare Workers is only a candidate pending team discussion.
User requested testing with this machine as the server first. No push authorized.

Uncommitted work adds a versioned analysis codec, Dart HTTP backend and Gemini
narrator with evidence checks/static fallback, optional Flutter server adapter,
and shared_preferences-backed local bookshelf. Do not mark GL-03/GL-04 complete.
The backend constructor initialization was corrected during demo preparation.
Existing widget tests now initialize mock preferences.

Local demo: release web build served at http://127.0.0.1:8086; Dart backend binds
127.0.0.1:8087. From repo root run
`dart --packages=backend/.dart_tool/package_config.json backend/bin/server.dart`.
The ignored backend/.env holds GEMINI_API_KEY; never copy it into Flutter or logs.
At preparation time the field was empty and /health reported aiConfigured:false.
User was asked to enter it locally; restart server after saving. Live Gemini
verification has not happened. Enable AI explanation in the web app to use server.

Validation: backend `dart test` passed all 13 tests; release web build passed.
Whole-project analysis reported backend cross-package relative-import resolution
errors; cleanup and full widget/CI validation remain outstanding. Keep existing
historical handover content and append subsequent results. No commit or push made.

### Gemini credential check — 2026-10-20

User saved the local key; server /health now reports configured. Authenticated
Google model listing succeeded without logging credentials. Live generation with
gemini-2.5-flash returned 404: unavailable to new users. Changed only ignored
backend/.env GEMINI_MODEL to gemini-3.8-flash, confirmed listed on Google's API
pricing page with free-tier input/output. Defaults/examples still need updating
after a successful end-to-end test. Restarted local server on port 8087.
Express analysis still fell back to static; a minimal 3.8 Flash generation request
returned HTTP 503 high demand. Key saving succeeded, but successful AI chapters
remain unverified. Do not report AI integration as complete. No billing or push.

### Visible AI failures — 2026-10-20

Added a prominent AI explanation unavailable card when AI is enabled but the
result is static, with the fallback warning and Retry AI analysis (cache-bypassing
refresh). Gemini errors now distinguish HTTP 400/401/403/404/429/500/502/503/504,
with safe actionable messages, plus timeout and HTTP-client connection failures.
Raw provider bodies and secrets are never displayed. Extended HTTP fixture coverage
checks each code and excludes private diagnostic text.
Validation: all 13 backend tests passed; Flutter analysis of lib/test/tool passed;
release web build and diff whitespace check passed. Flutter test was attempted but
crashed again in macos_x64 CPU detection; stopped the failed run. Whole-project
backend analyzer import issues noted above remain unresolved. Local backend restarted
and web build refreshed. User should hard-refresh port 8086 and retry AI analysis.
The model edit in ignored .env was already saved; review Accept is not needed for
server execution. No push or commit.

## Development handoff — 2026-10-21

This append preserves all prior progress and supersedes earlier statements that
AI generation has not been verified. The user successfully obtained an AI
interpretation in the local demo. Most other attempts returned HTTP 503. This
confirms an end-to-end success, not reliable availability or a proven free-tier
cause. The safe static fallback and visible diagnostic/retry card remain essential.
Default and example model settings now match the tested gemini-3.8-flash setting.

### Next developer priority: hosted server component (GL-03)

Add/finish the deployable server component for secure API key storage and API
request/response handling. A local Dart prototype already exists in backend/;
reuse or adapt it rather than assuming these boundaries are absent. Move secrets
to the chosen host's environment/secret store, never Flutter or Git. Own URL/input
validation, bounded GitHub and Gemini requests, response-schema/evidence checks,
readable errors, access control, quota protection, and deployment configuration.
Preserve the versioned contract and keyless static mode. Add bounded transient
retries and assess durable caching; the prototype caches successful AI results
only in process memory and has no automatic retries.

Hosting is still a team decision. Cloudflare Workers was discussed but not chosen;
the Dart HTTP server cannot be deployed there unchanged. Render was rejected for
idle sleep. GL-03 requires actual hosted deployment and remains incomplete.
GL-04 local persistence is implemented with service fixtures, but full restart/UI
and mobile acceptance verification remains outstanding.

### Delivery and validation context

User explicitly authorized committing and pushing the current work-in-progress
to feat/sprint-gl-01-04, with no merge to main. Include intentional dependency and
plugin registration updates for shared_preferences. backend/.env stays ignored;
backend/.env.example is credential-free. Each developer supplies their own key.
Existing 13 backend tests and release web build passed; lib/test/tool analysis
passed. Whole-project backend import analysis and Flutter engine test issues
recorded above remain limitations, not passing CI. Full CI/native acceptance is
required before merging. All historical handover entries above are retained.

## Cloudflare implementation handoff — 2026-10-21

### Scope and branch

- The team selected **Cloudflare Workers**. This supersedes earlier undecided-host
  entries. User authorized a new branch from the latest sprint and implementation.
- Branch: `codex/cloudflare-worker`, based on fetched
  `origin/feat/sprint-gl-01-04` at `13e00c3`. No merge/deployment performed.
  Work is local; this pass has not pushed or opened a remote PR.
- Preserved pre-existing main-branch Flutter-generated edits in the stash named
  `Preserve local Flutter-generated changes before Cloudflare branch`. Leave it
  intact; do not apply it to this branch or drop it without reviewing its owner/context.

### What changed and why

1. Added `backend/worker/` TypeScript implementation. Dart's HTTP server cannot
   run unchanged in Workers. Flutter keeps its existing schema v1 server adapter,
   server settings and keyless direct mode; no frontend rewrite was needed.
2. The Worker checks team authentication, browser origins, schema/root URL and
   4 KB/ten-second body limits before forwarding to a single SQLite Durable Object.
   SQLite is supported on Workers Free. Analysis runs there to keep parsing out
   of the lightweight Free Worker CPU budget; hosted CPU fit is still unverified.
3. `AnalysisCoordinator` persistently coordinates 100 accepted requests/day,
   10/minute, two concurrent distinct jobs, 20 Gemini attempts/day (including
   retries), and a 15-second cooldown between new AI jobs. UTC resets are explicit.
   Identical in-flight calls share work. These are conservative team limits, not
   provider quota guarantees or individual-user authentication.
4. Ported the bounded GitHub crawler, static analyzer and lexical import subset.
   Fetch only public GitHub API endpoints; resolve immutable commits; never execute
   source. Preserve eight-file/40 KB/180 KB budgets and enforce actual blob bytes
   even when tree sizes are understated. Network deadlines abort real transports.
5. Added ten-entry, ten-minute durable LRU cache keyed by canonical repository,
   commit, analyzer, AI flag, model and prompt. Always re-resolve the current commit
   before a cache lookup. Cache successful static/AI results, not AI failure fallbacks.
6. Gemini uses server-only header credentials, bounded excerpts and output,
   one transient HTTP retry at most, durable reservation per attempt, and checked
   evidence/node ownership. No retry on 429/auth failures. Invalid/failed output
   keeps static chapters and safe warnings; import edges never become AI runtime flow.
7. Extracted existing shared Dart implementations unchanged into
   `packages/gitlore_core/lib/models/` and `services/`. Original `lib/` entry points
   re-export them, preserving injection and existing callers. Both Dart packages
   now use a local path dependency, fixing the previously recorded cross-package
   analyzer errors. Updated both lockfiles and Docker copy paths; no unrelated
   dependency upgrades. New Worker tooling has its own npm lockfile.
8. Fixed a reproducible Dart prototype bug: early cancellation while rejecting an
   oversized body closed the socket before delivering its JSON error. Delay
   cancellation until response completion; cover fixed-length and chunked requests.
9. Expanded CI with standalone backend analysis/tests, Dart/Worker fixture parity,
   and a Node 24 job for Worker formatting/types, fixtures, actual Workers runtime
   tests and a dry-run bundle artifact. Builds need no provider credentials and
   do not deploy. Updated contributor/PR instructions and README; removed obsolete
   UI copy claiming that the selected server wakes from an idle sleep.
10. Added ignored local `.dev.vars` patterns and Docker-context exclusions for
    local Worker secrets/dependencies/state. No real key was read, copied or
    configured for this pass. Hosted secrets must use Cloudflare's secret store.

### Structure and setup

Read [`backend/worker/README.md`](../backend/worker/README.md) for the complete
request contract, settings, limits, local workflow, authorized deployment runbook,
secret rotation and limitations. `src/index.ts` is the public boundary;
`coordinator.ts` owns orchestration; `limits.ts` durable quotas/cache; `services/`
owns crawler/static imports/Gemini; `contracts.ts` validates results and citations.

Local: `npm ci`, copy the safe `.dev.vars.example` without overwriting another
developer's file, enter a random team code of at least 32 characters and optional
Gemini key locally, then `npm run dev`. Port 8087 is shared with the Dart prototype:
run one backend at a time. Unlike the local Dart prototype, Workers requires a
team code even locally. Flutter web uses port 8086 and **Server settings**.
`GITLORE_API_URL` may contain the public HTTPS server URL, never a Gemini key.
`backend/.env` is not read by Workers. AI disabled still uses direct keyless GitHub.

### Verification for this branch

Passed locally using Flutter 3.47.2 / Dart 3.13.2 and Node 24.15.0:

- Root `flutter pub get --enforce-lockfile` and backend `dart pub get --enforce-lockfile`.
- Dart format check across `lib test tool packages/gitlore_core/lib backend/bin backend/lib backend/test`.
- Whole-project `flutter analyze --no-pub`: no issues. Backend
  `dart analyze --fatal-infos`: no issues. Previous import errors are resolved.
- `flutter test --no-pub --coverage`: **34 passed**, including the shared Worker
  contract fixture. Earlier engine crashes did not recur during this run.
- Backend `dart test`: **14 passed**, including both oversized-body cases.
- Dart fixture generator `--check`: passed. Worker static output matches that
  Dart example after normalizing only analysis version/timestamp; Ajv validates
  the published schema. This is example parity, not universal compiler equivalence.
- Worker clean `npm ci`: passed, audit reported zero vulnerabilities at restore.
  Prettier and TypeScript checks passed. Node fixture suite: **54 passed**.
  Workerd suite: **2 passed**, using actual SQLite storage, including object
  restart/cache recovery. Outbound calls are mocked; no credentials needed.
- `flutter build web --release --no-pub`: passed, including the Wasm dry run.
- `npm run build`: Wrangler dry-run bundle passed (about 39.6 KiB / 12.1 KiB gzip).
  This is packaging verification, not deployment.
- `git diff --check`: passed before commit.

### What remains unverified or limited

- No Cloudflare account provisioning, hosted endpoint, deployed secrets, custom
  origin, real Worker-to-Gemini request or hosted CPU/memory/quota test yet.
  The selected model preserves the earlier local prototype setting; its access
  and free allowance must be confirmed on the team's Google account. Provider
  503s remain possible after the bounded retry and produce static fallback.
- The shared team code protects a private demo, not a public multi-user service.
  Invalid traffic can still consume Cloudflare requests. API budgets do not
  eliminate unauthenticated GitHub rate limits or guarantee zero provider charges
  if an owner later enables billing. Do not enable paid plans automatically.
- No remote GitHub Actions run for this local branch yet. The local checks passed;
  a future push/PR must obtain green remote CI. Docker image/native app builds,
  live browser-to-Worker/Android HTTPS, secret rotation and device-restart UX were
  not tested here. Earlier manual app demos apply to earlier code only.
- Static resolvers remain lexical subsets with documented unsupported syntax.
  AI citations prove a source reference exists, not that an explanation is correct.
  Single-object coordination is intentionally sized for a small team.

### Next concrete tasks and acceptance criteria

1. **Review and deliver this branch:** once a push is authorized, push the feature
   branch and open a PR against the team's agreed base; do not silently merge
   main or the sprint. Require both CI jobs, artifacts and review before merging.
2. **Authorized hosted acceptance (GL-03):** use Workers Free + SQLite; configure
   real origins and server secrets through prompts; deploy only when authorized.
   Verify health, denied access, static and AI responses decoded by Flutter,
   citations, provider fallback, commit refresh and budgets after object restart.
   Measure CPU/memory/latency with a representative large public tree. Record
   the endpoint, account plan and outcomes here without secrets. GL-03 remains
   incomplete until hosted acceptance passes.
3. **Device acceptance (GL-04/UI):** save/open/replace/delete, restart the app and
   verify persistence; exercise graph controls and hosted HTTPS on Android/web.
   Add fixtures for any newly found behavior rather than relying on live keys.
4. **Then product improvements:** progress states and screen extraction, better
   monorepo coverage and automatic layout, Explore/shared persistence with explicit
   access rules, stronger identity before public release, optional safe exports.

## Cloudflare account setup — 2026-10-21

- User authorized starting Cloudflare setup and connecting the app. The code
  remains on `codex/cloudflare-worker`, implementation commit `75a7eff`.
- `wrangler whoami` confirmed this machine is not authenticated. User needs to
  create a Cloudflare account; the in-app browser is open to the official signup
  page. Account creation, email verification and any terms acceptance are for the
  user to complete. Keep Workers Free; no domain or paid plan has been configured.
- Automatic approval review initially rejected persistent Worker write access
  without permission for those scopes. User then explicitly approved account/profile
  read, Worker script/Durable Object write and Worker diagnostic read, with saved
  local authorization. Use the limited login command below, not Wrangler's much
  broader default scopes. Do not request the same approved permissions again:
  `wrangler login --scopes account:read user:read workers_scripts:write workers_tail:read`.
  The localhost OAuth callback also requests offline access to retain the login.
- The OAuth attempt expired while waiting for account creation and then exited
  with a Windows native-handle assertion. It did not authenticate or deploy.
  Restart the official OAuth flow once signup/email verification is complete. Do not reuse an
  expired authorization URL or inspect stored credential files. Let the user
  complete authentication and approve the permissions in the browser.
- Rechecked Worker TypeScript, 54 fixture tests, two workerd/SQLite runtime tests,
  and the dry-run bundle: all passed. No production deployment or secret upload
  was attempted. No key was read or copied from the local Dart prototype.
- Next: confirm successful login and account Free plan; check for an existing
  `gitlore-api` before creating/updating it; deploy the reviewed Worker with its
  SQLite migration; enter the team code and Gemini key through Cloudflare's secret
  interface; verify health, authentication, CORS, static result and AI/fallback.
  Then connect Flutter using the actual public HTTPS URL and record live results.
  The teammate who owns the Gemini key may need to enter it directly; never ask
  them to paste it into chat. No hosted URL exists yet, so none has been hardcoded.

## Cloudflare agent connection — 2026-10-21

- User created the Cloudflare account and explicitly requested executing the
  appropriate official instructions from
  <https://developers.cloudflare.com/agent-setup/prompt.md>. Retrieved that file
  directly; applied the Codex instructions, preserving the existing Wrangler app.
- Installed all 19 skills from the official `cloudflare/skills` repository into
  this developer's `C:\Users\jackj\.codex\skills\` using the Codex skill installer.
  This is local tooling, not a Flutter or server dependency. Skills become
  available on the next turn. The MCP initially appeared to need an app restart,
  but its tools became available dynamically later in this session.
- Backed up the existing Codex configuration locally before registering a single
  `cloudflare` MCP server at `https://mcp.cloudflare.com/mcp`. Used `codex mcp add`
  to preserve unrelated settings. No credentials/config backups are in this repo.
- The automatic initial OAuth request advertised broad platform permissions. It
  was cancelled before authorization. Requested only `offline_access`, `user:read`,
  `account:read`, `workers-scripts.read`, `workers-scripts.write`, and
  `workers-tail.read` in the subsequent login.
- Automatic approval review distinguished the MCP grant from the previously
  approved Wrangler grant. User explicitly approved this separate saved MCP
  connection, including account/profile read, Worker script/Durable Object
  read/write and diagnostic access. User completed the official browser consent.
  Do not re-request the same approval when continuing this setup.
- Verified: CLI reported `Successfully logged in to MCP server 'cloudflare'`.
  `codex mcp list --json` confirms the server is enabled, uses streamable HTTP
  and has OAuth authentication. Counted all 19 installed skill directories.
  Cloudflare tools subsequently loaded in this session; no restart is needed now.
  Do not inspect stored OAuth credentials or manually extract tokens as a workaround.
- Skipped optional global beta `cf` CLI and user-level instruction changes:
  this project already uses Wrangler, which the official skills explicitly retain.
- No project runtime code changed. Only documentation changed in this checkpoint;
  `git diff --check` is the relevant validation. Last runtime verification remains
  the successful 54 fixture tests, two workerd tests and bundle recorded above.
- The connection is developer access to Cloudflare, not a deployed GitLore server.
  No server secrets or live endpoint exist yet; no deployment, push, merge or
  billing change occurred. Account Free-plan status has not yet been inspected.
- Verified live MCP identity/account lookup and Workers list: the connected
  account has no Workers. Account settings use the `standard` usage model (this
  alone does not establish Free-plan billing status). Workers has no subdomain yet.
  Opening the official Workers landing page shows an email-verification modal:
  user must verify email before Workers setup can proceed. User has been asked
  to click Cloudflare's email verification link. Do not bypass that prerequisite
  with an API deployment. No verification email was requested/sent by the agent.
- **Next action:** after the user verifies email, continue hosted setup.
  Read the installed `wrangler`/`durable-objects` guidance as applicable. Use the
  newly connected MCP to verify the account/Free plan and inspect existing Workers
  before deploying `gitlore-api`. Keep the versioned schema and SQLite migration;
  use Cloudflare's secret interface for Gemini and team credentials, then connect
  Flutter to the actual HTTPS URL and run live acceptance. Deployment remains
  within the user's ongoing server-setup request; no additional generic permission
  question is needed for that already authorized work. New scopes/paid services
  or unrelated resources still require their own authorization.

## First hosted deployment — 2026-10-21

- User completed email verification. Confirmed the blocking modal/banner cleared.
  Dashboard shows the free-tier 100,000 requests/day and 200,000 observability
  events/day allowances. No upgrade, payment, domain or other paid service enabled.
- The account had no existing Worker scripts. Deployed the reviewed Wrangler
  dry-run `dist/index.js` bundle through the newly authorized Cloudflare MCP
  script upload endpoint, rather than extracting OAuth credentials for Wrangler.
  This preserves the existing local Wrangler build and selected deployment config.
- Worker: `gitlore-api`; account: `637c176c0cd455f0beeec6d3cf4f5d12`;
  public endpoint: <https://gitlore-api.jack-j-dugan.workers.dev>.
  Enabled workers.dev; disabled preview URLs. Initial deployment UI reported Ready
  (version prefix `745038ee`). Migration `v1` created SQLite namespace
  `d427c414ef094fc9a46a9a5cfd59f2ad` for `AnalysisCoordinator`; `ANALYSES` is bound.
- Reconciled public variables with wrangler.jsonc: model `gemini-3.8-flash`, browser
  origins `http://localhost:8086,http://127.0.0.1:8086`, compatibility 2026-10-21.
  Logs/traces remain disabled by the existing credential/source privacy decision;
  review sanitized observability before a broader public release.
- The first HTTPS probe hit a transient TLS handshake failure; a later normal
  certificate-verified request succeeded. No TLS check was bypassed. Health
  returned the expected 503/not_configured and aiConfigured:false before secrets:
  the deployed service fails closed until TEAM_ACCESS_TOKEN is configured.
- Generated a random 32-byte team code in ignored `backend/worker/.dev.vars`;
  it was not printed or committed. Gemini is blank locally. Opened that file
  in Notepad for the user to copy its team-code value directly to Cloudflare.
  The user is adding Production secrets with the Secret checkbox selected:
  TEAM_ACCESS_TOKEN and optionally GEMINI_API_KEY from the teammate. Do not read
  private key values or capture the secret-entry screen. No Gemini key was copied
  from backend/.env. Secret names/health presence can be checked without values.
- Flutter's default AI server URL now points to the hosted endpoint; an explicit
  GITLORE_API_URL or Server settings still selects a local development server.
  AI remains off by default, preserving keyless direct GitHub analysis.
- Extended the existing Dart CLI to optionally use ServerArchitectureService:
  runtime environment GITLORE_API_URL / GITLORE_TEAM_ACCESS_TOKEN, optional
  GITLORE_AI=true. Defaults remain direct static GitHub. Never use a Flutter
  build define for the team credential. This permits an actual hosted response
  to be decoded through the same schema/evidence boundary used by Flutter.
- Added a network-free widget check for hosted HTTPS default, masked team-code
  input, rejection of insecure remote URLs and acceptance of a local override.
  Root locked restore, whole-project analysis and all 35 Flutter tests passed.
  Worker locked restore/audit (zero vulnerabilities), format/types, 54 fixture
  tests, two workerd tests and dry-run bundle passed. Additional validation and
  live results will be recorded below once remaining checks/secret entry finish.
- Remaining local checks completed: format check (34 files), Dart fixture parity,
  backend locked restore and issue-free analyzer, all 14 backend tests, and the
  release web build (including Wasm dry run) passed. Total fixture/widget/runtime
  tests this pass: 105. The rebuilt app is served locally on 127.0.0.1:8086 by a
  session-dependent Python server; restart that server if it is no longer running.
- The first private-file open in Codex was queued, so Notepad was launched for
  the user's explicit request to find the team code. Its content was not captured.
  Secret entry remains with the user; the latest safe health check still reports
  503/not_configured, aiConfigured:false. This is expected until the secrets deploy.
- User needed help locating Cloudflare's entry form. In the in-app browser, the
  Add variable form is open with Production selected, key TEAM_ACCESS_TOKEN filled
  and Secret checked. The value is blank for the user to paste from Notepad.
  No credential was entered or submitted by the agent. After the user deploys
  the secret, verify its name/presence and health; do not capture the entry screen
  while the user is typing. Gemini secret entry is still pending as well.
- Pending: verify secret presence/health, wrong-code rejection, browser CORS and
  authenticated static analysis/caching, then real Gemini output or safe fallback.
  Build the release web app and verify the browser against the hosted service.
  Hosted maximum-tree CPU/memory, native device acceptance, uptime and remote
  GitHub CI remain separate checks. No push or merge has been performed.

## Hosted secret verification and runtime fixes — 2026-10-21

- User confirmed adding both Production secrets. Verified only names/types:
  `TEAM_ACCESS_TOKEN` and `GEMINI_API_KEY` are `secret_text`. Never retrieved their
  values. `/health` now returns HTTP 200, `status:ok`, `aiConfigured:true`.
  Presence does not establish provider availability or successful generation.
- Live wrong-code rejection returned 401; allowed-origin preflight returned 204
  with the exact origin; a denied origin returned 403. Authenticated static
  analysis was decoded by the shared Dart server adapter used by Flutter.
- First hosted GitHub analysis exposed a platform mismatch: Workers rejects
  `redirect:"error"` before making the request. Node fetch mocks had hidden this.
  Changed outbound fetches to `redirect:"manual"`; callers reject 3xx without
  following Location or forwarding credentials. Confirmed the old code failed
  a new native workerd Request regression before applying the fix. See
  <https://developers.cloudflare.com/workers/runtime-apis/request/>.
- The deployed fix successfully sampled eight files/146 tree entries from
  `andrewmallory8/GitLore`, commit
  `db8ac640f62a1e07a717b4a6842cb917c991f4ab`, producing nine nodes/ten import edges.
  Two sequential static requests returned HTTP 200 with identical snapshots,
  commit and generatedAt, and the expected browser CORS header. Two earlier
  simultaneous probes returned 502; cause remains unconfirmed. These are not
  counted as passing cache tests or evidence of sustained reliability.
- Added safe, distinct notices for an upstream deadline and incomplete Gemini
  generation; raw exceptions/provider bodies remain hidden. Aborts now surface
  as typed `upstream_timeout` errors, with deterministic regression coverage.
- Live AI probes on GitLore and the one-file `octocat/Hello-World` returned
  schema-valid static fallback, including confirmed 20-second provider deadline
  failures and HTTP 503. No successful hosted AI chapters/citations yet. These
  results do not prove the key is invalid; do not rotate it based only on these
  failures. Failed AI results remain uncached and all attempts consume quota.
- Gemini 3 requests now specify `thinkingConfig.thinkingLevel:"low"`, keeping
  4,096 output tokens and existing 20-second attempt/45-second total deadlines.
  This follows Google's guidance to reduce reasoning for latency; it has not
  resolved the observed provider failures. Older model families omit the setting
  because 2.5 uses a different API. Bumped prompt/cache version to `worker-story-v2`.
  Reference: <https://ai.google.dev/gemini-api/docs/generate-content/thinking>.
- Deployed the tested bundle through authorized Cloudflare MCP. Preserved both
  secret bindings with `keep_bindings:["secret_text"]` and the existing SQLite
  namespace/migration v1. Latest script etag:
  `bcdb78ca80570a2444ee86974bb44eb81ffd1901c2f151debf992ada54fc42e4`.
  Verified secret names/types and healthy configuration after the update.
- Validation: Worker formatting/types, **58** Node fixture tests, **3** real
  workerd tests and dry-run build passed (40.53 KiB / 12.40 KiB gzip). Prior
  unchanged Dart validation in this setup pass: locked restores, format, fixture
  parity, static analysis, **35** Flutter tests, **14** Dart backend tests and
  release web build passed: **110** total local tests with the updated Worker.
  No remote GitHub CI, native-device acceptance, hosted large-tree benchmark or
  authenticated Flutter browser walkthrough was performed. API/adapter acceptance
  is not the same as browser UI acceptance. Logs/traces remain disabled pending
  deliberate sanitized observability work. No push or merge in this checkpoint.
- **Next concrete task:** retry one small AI analysis after provider recovery;
  check Google AI Studio model/key access and free quota privately if it still
  fails. Verify real chapters with checked citations before calling AI ready.
  Keep quota/deadline safeguards; do not solve availability by enabling billing.
  Then run Flutter on port 8086, enter the team code in Server settings, enable
  AI explanation and verify loading, source links and failure/retry behavior.
  The URL already defaults to <https://gitlore-api.jack-j-dugan.workers.dev>.
  Browser origins currently allow only localhost/127.0.0.1:8086; add a future
  hosted Flutter origin deliberately. Team code is session-only, entered at runtime.

## Gemini timeout investigation and fix — 2026-10-21

- User explicitly requested diagnosing and fixing Gemini timeouts, including
  considering reduced complexity. Continued on the clean `codex/cloudflare-worker`
  branch. Deployment remains within the ongoing authorized server-setup work.
- Isolated provider traffic from GitHub with a protected, fixed diagnostic:
  Gemini 3.8 Flash timed out at **20,000 ms** even when asked only to reply `OK`.
  The identical ping with Gemini 3.5 Flash-Lite succeeded with HTTP 200 in
  **3,021 ms**, using the same secret and server. This demonstrates that prompt
  size is not the sole cause and key/Cloudflare connectivity work with Flash-Lite.
  It does not establish whether the older model's delay is capacity, routing or
  model processing. Do not invent a provider-side root cause or claim an invalid key.
- Switched the Worker default/config to stable `gemini-3.5-flash-lite`, which
  Google documents for low latency and offers on the free API tier:
  <https://ai.google.dev/gemini-api/docs/models/gemini-3.5-flash-lite> and
  <https://ai.google.dev/gemini-api/docs/pricing#gemini-3.5-flash-lite>.
  No account plan, billing, key or OAuth permissions were changed.
- Uses minimal thinking on 3.5/3.1 Flash-Lite, low on other Gemini 3 text models,
  and omits unsupported thinkingLevel on older families. Removed explicit low
  temperature for Gemini 3: Google warns it can cause loops/degraded performance.
  The ping did not set temperature, so this is preventive tuning, not a proven
  explanation for the original timeout. References:
  <https://ai.google.dev/gemini-api/docs/generate-content/thinking> and
  <https://ai.google.dev/gemini-api/docs/gemini-3#temperature>.
- Reduced generated narrative from up to eight chapters to **one–four brief
  chapters**, asking for at most two sentences each. Schema/parser cap chapters
  at four; the sentence instruction is prompt guidance, not a sentence parser.
  Preserved source input limits, 4,096-token headroom, checked citations, static
  map, privacy boundary, 20-second attempts/45-second total and all team quotas.
  Prompt/cache version is now `worker-story-v3`, so older results cannot mask
  changed generation settings. Flutter and the optional Dart prototype are unchanged.
- Added `POST /v1/diagnostics/gemini` with strict schemaVersion 1 and optional
  `mode:"ping"|"story"`. Same authentication, origin/content-type/body limits and
  SQLite admission/AI counters as analysis; two shared concurrency slots,
  coalescing per mode, 15-second cooldown, 20 AI attempts/day including retries.
  Ping makes one fixed provider call; story uses the production prompt/validator
  on **two synthetic JS files**, not an actual crawled repository. No custom model,
  prompt, URL or source accepted. Only safe status/timing/count metadata is returned,
  never keys/provider bodies/source. HTTP 200 alone is insufficient: inspect
  `outcome`. Ping reservation failure is 429; story budget failure is fallback.
- Live synthetic story succeeded with **two checked chapters in 6,939 ms**.
  After the final temperature/default changes, it succeeded again in **1,691 ms**.
  These are individual diagnostic observations, not representative benchmarks or
  an SLA. They establish live generation plus the production schema/citation
  checks for synthetic input; real repository accuracy/latency remain unverified.
- A separate blocker surfaced before Gemini: GitHub returned `github_limit`.
  The crawler now includes a validated UTC reset timestamp from the public rate
  header without echoing arbitrary header/body text. The last reported reset was
  **2026-10-21 22:09:29 UTC / 5:09:29 p.m. America/Chicago**. Do not hammer refresh,
  bypass quota, remove immutable-commit checks or silently serve expired snapshots.
  Fresh GitLore/Hello-World end-to-end AI acceptance is pending that reset.
- Final tested bundle deployed through authorized Cloudflare MCP, preserving both
  encrypted secrets and existing SQLite namespace/migration v1. Settings confirm
  the model and secret types. Latest etag:
  `1efc65a5d825b35b31c9c26e14c5b9a4741c538ac9cebcf7f2ec29c0ce7d643c`.
  Logs/traces remain disabled under the existing privacy decision; the protected
  diagnostic provides troubleshooting without provider/source logging.
- CI-equivalent validation passed: locked Flutter/Dart/npm restores; Dart format
  (34 files), analysis and Worker fixture parity; **35 Flutter + 14 Dart backend
  + 69 Worker Node + 4 workerd tests = 122 tests**; Worker formatting/types and
  dry-run build (**45.68 KiB / 13.66 KiB gzip**); release Flutter web build with
  successful Wasm dry run. Runtime coverage includes diagnostics through actual
  SQLite, and fixtures cover denied access/custom input, persisted AI/admission
  limits, deadlines, invalid evidence, excess chapters and safe reset timestamps.
- `npm ci` now reports **two moderate development-tool findings** for Vitest
  4.1.11 / `@vitest/mocker` (GHSA-qxg6-89mg-rqv8, GHSA-xp26-3454-mjgp), with a
  patch indicated in 4.1.12. These are not bundled in the deployed Worker.
  Recorded rather than applying an unrelated dependency update in this fix;
  patch the test tooling in a focused follow-up and rerun Node/workerd suites.
  Earlier zero-audit results above are historical, not current.
- **Next concrete task:** after the GitHub quota reset, make one fresh small
  repository AI request, confirm `analysisKind:"ai"`, checked source links and
  subsequent cache reuse through the Dart adapter; then verify Flutter browser
  behavior on port 8086 and Android. If the shared unauthenticated GitHub quota
  remains unreliable, plan improved server GitHub capacity/caching separately.
  No hosted large-tree benchmark, real browser/native walkthrough, remote GitHub
  CI, push or merge was performed in this checkpoint.

## MVP AI summary acceptance — 2026-10-22

### Submission scope and verified behavior

The user clarified that this submission needs an **MVP**, particularly an actual
server component that holds the Gemini key, makes the AI request and returns the
output to the app. Comic presentation, Explore, search/export and user accounts
are future work, not prerequisites for this MVP. Preserve keyless static mode.

- Real `octocat/Hello-World` returned `analysisKind:ai` through Cloudflare and the
  shared Dart adapter (commit `7fd1a60b01f91b314f59955a4e4d4e80d8edf11d`). This was
  the first real-repository acceptance after the previous synthetic-only tests.
- Real `jonschlinkert/is-number` returned an AI overview and three chapters through
  the adapter, reading six files at commit
  `98e8ff1da1a89f93d1397a24d7413ed15421c139`, generated
  `2026-10-22T14:36:54.091Z` (intermediate prompt v4).
- Final prompt **`worker-story-v5`** passed the larger default demo,
  `expressjs/express`, at commit
  `0dee2c52c7c873498f8ed7d8ee4ddd0a04d3ada8`: eight files, six resolved import
  edges, **three AI chapters**, generated `2026-10-22T14:43:39.184Z`.
  The summary described Express as a minimalist Node.js web framework.
  A second adapter request returned the same summary and exact generation
  timestamp, demonstrating AI cache reuse. The explicit provenance warning
  confirms these Express results used the new client-snapshot fallback.
- These tests exercised the same `ServerArchitectureService` and strict result
  codec used by Flutter, with real public GitHub source and real hosted Gemini.
  `GITLORE_REQUIRE_AI=true` made static fallback fail acceptance instead of
  accidentally counting HTTP 200 as AI success. No real credentials, raw provider
  bodies or full source files were printed or committed.
- A widget fixture additionally verifies that the server's AI overview appears
  in the repository summary. This is not a substitute for manual browser or
  Android device acceptance, which remains a final team demo check.

### Issues found, fixes and reasons

1. **AI chapters previously left the top-level summary static.** The server now
   requests the first chapter as an overview and uses its validated body as
   `summary`. This avoids an extra AI call and an independently uncited summary.
   AI failure still preserves the original static summary.
2. **Shared GitHub quota remained unreliable.** Early requests returned
   `github_limit` before Gemini despite the prior day's reset having passed.
   `ServerArchitectureService` now handles that specific error once: its existing
   bounded Dart crawler fetches current public source using the client's quota,
   then uploads a snapshot to authenticated `/v1/explain-snapshot`. Other errors,
   especially invalid credentials, do not initiate local crawling. An upload
   failure cannot recursively trigger another upload. Direct server crawling
   remains the normal path; no GitHub limit is bypassed or disabled.
3. **Express still encountered a response/evidence fallback with the older
   generation format.** The exact older failing provider output was deliberately
   not captured. Simplified Gemini's private output to `{title,body,sourcePath}`
   chapters, with sourcePath constrained to an enum of supplied excerpts. The
   server chooses the known static node and attaches the exact supplied excerpt
   range (up to 100 lines), rather than trusting generated IDs/line numbers.
   Invalid or absent source references still fail validation. These are broad
   supporting windows, not guaranteed pinpoint citations or verified semantics.
   The final simplified format succeeded on Express; no claim is made that this
   eliminates provider HTTP 503s or other future availability failures.
4. **Client snapshots must not become trusted graphs or poison server caches.**
   Added `backend/worker/src/services/snapshot.ts` to validate and rebuild static
   analysis from source. It rejects extra fields/prebuilt summaries and graphs,
   invalid public URLs/commit IDs/paths, duplicate files, more than eight files,
   over-40,000-byte individual UTF-8 files and over-180,000-byte total source.
   Only this new route accepts a **1,100,000-byte JSON envelope** to accommodate
   escaping; existing analysis/diagnostic routes retain **4,096 bytes** and all
   body deadlines remain ten seconds. All routes share durable quotas and two
   active slots. Cache identity includes actual normalized source and metadata,
   analyzer/model/prompt versions, and a separate domain from server crawls.
   A claimed SHA alone cannot cause reuse for different uploaded content.

### Trust, privacy and remaining limitations

- Gemini key stays in Cloudflare Production secrets and is sent only by the
  Worker to Google's API. The app knows only the runtime team code. Source
  fallback does not move Gemini requests or its privileged key onto the client.
- A client snapshot is untrusted input: during a GitHub outage/quota failure the
  server cannot independently verify its claimed commit/content. The app's
  crawler resolves a real pinned snapshot, but the API explicitly labels server
  provenance as unverified. No crawled/uploaded source is executed. Existing
  source links are pinned to the supplied commit; they are not server attestation.
- A quota fallback uses two team API requests: failed server crawl plus snapshot
  upload. Both count toward 100/day and 10/minute. Gemini attempts, including
  retries, still share 20/day and a 15-second new-job cooldown. Client GitHub
  quotas can also run out. Cached AI avoids another provider attempt but does
  not exempt incoming requests or the client's fresh commit/source lookup.
- Snapshot rebuilding intentionally omits unverified GitHub description/language
  metadata; technology labels can be less complete than a direct server crawl.
- Provider HTTP 503, timeouts and static fallback remain possible. Live tests
  are individual acceptance observations, not an uptime/latency SLA. Early
  GitLore analysis returned HTTP 503 fallback; do not describe all tested repos
  as successful. Maximum-size hosted resource benchmarking, sanitized
  observability, independent identities and production abuse hardening remain
  beyond this MVP. Existing two moderate Vitest development-tool advisories are
  unchanged and should be patched separately.
- The optional Dart local prototype does not implement the new snapshot route;
  the verified hosted MVP uses Cloudflare Workers. Do not replace it with that
  prototype when following the demo instructions.

### Validation and deployment

- Locked Flutter/Dart/npm restores passed. Dart formatting (34 files), analyzers,
  static Dart/Worker fixture parity, **36 Flutter + 16 Dart backend + 81 Worker
  fixture + 5 workerd tests = 138 local tests** passed. Release Flutter web build
  and Wasm dry run passed; Worker formatting/types and dry-run bundle passed
  (**48.71 KiB / 14.33 KiB gzip**).
- New fixtures cover quota-triggered client transport, denial before crawling,
  bounded snapshot validation, source-sensitive cache identity, AI/static summary
  behavior, server-owned evidence ranges and the visible overview. One runtime
  test initially hit the real singleton's cooldown from a previous test; fixed
  test-time isolation by advancing the mocked clock, without clearing budgets
  or changing production limits. Final real SQLite tests pass.
- Final Worker deployed within the user's ongoing server/MVP authorization.
  Preserved `ANALYSES`, migration v1, both secret bindings and allowed origins.
  Script etag:
  `2b21094e223cdfc7cf34c144cfd998b189047b17f6237b60d7d9c8afcb201558`.
- Updated README and Worker runbook with the demo, endpoint shape, byte budgets,
  cache/provenance behavior and CLI acceptance mode. Earlier dated statuses and
  prompt versions above are historical; this section supersedes them.

### Next agent / team actions

1. Use `codex/cloudflare-worker` and the updated app build. Run
   `flutter run -d chrome --web-hostname=127.0.0.1 --web-port=8086` so browser CORS
   matches the production allowlist. The existing Python preview on port 8086
   may still be running on this machine; stop/reuse it deliberately before
   starting a different server on that port. Do not run both simultaneously.
2. Open Server settings, use the already-default hosted URL and enter the
   existing team code privately. Enable AI explanation, analyze Express, inspect
   the AI label/summary/chapters and open a source link. Show the import map and
   save/reopen the result. Repeat on Android if required by the course rubric.
3. For CLI acceptance, supply `GITLORE_API_URL`, `GITLORE_TEAM_ACCESS_TOKEN` and
   `GITLORE_AI=true` privately at runtime; set `GITLORE_REQUIRE_AI=true` to fail on
   static fallback. Run the existing `tool/analyze_repository.dart` with Express
   or is-number. It prints model, commit, generation timestamp and chapter count,
   which distinguish real AI/cache reuse from fallback. Do not use Flutter
   defines or committed scripts for privileged values.
4. Keep the final manual device/demo check separate from API/adapter and fixture
   acceptance. Confirm the submission uses this branch's code; no merge has
   been authorized. Investigate a fresh failure by its specific quota/provider
   notice rather than reverting to the older Gemini model or removing safeguards.

## Progress, recovery and storybook demo — 2026-10-22

Working branch: codex/progress-recovery-storybook, from codex/cloudflare-worker
17d08b2. User authorized these three objectives but forbids commits/pushes until
their demo. Never move or edit any Trello cards. No Worker deployment required or
performed; hosted behavior and team quotas remain unchanged.

- Added optional progress callbacks to shared GitHub/server services. Direct
  analysis reports metadata, tree, actual selected file reads, and map building.
  Hosted mode reports server waiting, snapshot upload and result validation; no
  simulated remote phases or percentages. Flutter announces progress accessibly.
- Recovery preserves the prior result during work and on failure, explicitly
  labels it as not refreshed, retries the failed URL bypassing client cache, and
  offers direct static analysis/server settings in AI mode. GitHub reset headers
  and numeric Retry-After hints populate a local suggested retry time when visible.
  Unknown reset times are not invented. Hosted browser CORS currently does not
  expose Retry-After, so that header is only available to native/CLI clients unless
  a future authorized Worker change exposes it. API messages remain visible.
- Added separate StorybookPresentation widget with sequential panels, navigation,
  progress, selected-component highlight/map, source links and AI/static/demo
  distinctions. It uses existing chapters; no new Gemini calls or generated art.
- Added fixtures for crawler progress, server retry hints, presentation at narrow
  and wide widths, and failed-refresh preservation.

Validation: locked backend restore passed; whole-project Flutter analysis passed;
17 backend tests passed; release web/Wasm build and git diff whitespace check
passed. Native Flutter tests still crash in macos_x64 CPU detection on this machine
and could not verify the new widget fixtures. No claim of full CI/mobile acceptance.
Manual in-app browser: real Express static analysis showed fetching/file progress;
presentation opened and moved to panel 2 with matching component; invalid URL
showed error/retry while retaining Express; corrected URL reopened cached result.
Demo at http://127.0.0.1:8086/?demo=storybook. User still needs to demo AI mode and
mobile behavior. No credentials, commits, pushes, Trello edits or merges.

### User demo acceptance and local checkpoint — 2026-10-22

The user demoed this build and reported that everything seems to be working
great, then explicitly authorized updating the handover and committing the
changes on the current development branch, codex/progress-recovery-storybook.
This supersedes the earlier pending user-demo/commit restriction for this batch.
Preserve all preceding progress. This authorization is for a local commit only;
no push, merge, deployment, or Trello edits are authorized. Never edit/move Trello
cards in this project.

Delivered scope: observed analysis progress, recovery actions with preserved
previous results and available retry timing, and the separate storybook
presentation mode. The user feedback is a manual demo acceptance, not evidence
of every AI failure path or Android verification. The validation results and
Flutter engine/CORS limitations recorded above remain applicable.

Suggested next objectives, pending implementation authorization:
1. Curated Explore gallery with repository descriptions and technology tags;
   explicitly identify demo/cached content and when a selection starts analysis.
2. Search and technology filters for Explore and saved projects, with result
   counts and helpful empty states.
3. Bookshelf polish: confirmation for individual deletion and browser/Android
   save/open/delete/restart acceptance.
Before merging, run the new widget fixtures in a working Flutter environment
and complete native acceptance. Keep secrets in ignored local files or the
Cloudflare secret store; no credentials belong in the commit.

## Explore and bookshelf demo — 2026-10-22

User reported publishing the prior checkpoint and authorized the next objectives.
Work remains uncommitted on codex/progress-recovery-storybook. Never edit Trello.
Added curated Explore (Express, is-number, GitLore), descriptions/technology tags,
and explicit fresh-analysis disclosure. Selection bypasses the client cache via
refresh, uses current AI settings, and preserves hosted quotas/cache behavior.
Shared ProjectFilter provides case-insensitive name search (also descriptions in
Explore), technology selection, counts, no-results guidance and clear filters.
Saved projects use their analyzed technology metadata. Individual removal now
requires confirmation; cancellation preserves the save.

Verification: whole-project analysis, release web/Wasm build, diff whitespace
check passed. Added an Explore filter/selection widget fixture; it has not run
because this machine's Flutter widget engine remains blocked by the documented
CPU detection crash. Browser check confirmed combined filters/empty/reset, fresh
analysis from Explore, save surviving reload, and delete confirmation/cancel.
Actual delete persistence and Android restart acceptance remain outstanding; do
not claim full mobile completion. Demo available on port 8086. No commit, push,
Worker deployment, or Trello modification.

### Explore demo accepted and delivery authorized — 2026-10-22

User tested the Explore/filter/bookshelf demo, reported "Looks great!", and
explicitly authorized updating this handover, committing and pushing this batch
to codex/progress-recovery-storybook. This supersedes the preceding uncommitted
status for this batch. Preserve prior history; do not merge main or edit Trello.

Delivered: curated Explore gallery with clear fresh-analysis behavior, reusable
search/technology filters for Explore and saved projects, result counts/empty
states, and individual-delete confirmation. README and interaction fixture are
included. Existing analysis/build/manual browser results above apply; widget
execution, actual delete persistence and Android restart acceptance remain open.
Next priority is to run the new fixtures in a working Flutter environment and
complete those device/persistence checks before merge. Export (diagram/Mermaid
and cited Markdown walkthrough) is a potential next product objective, subject
to user direction. No hosted Worker changes or deployment are part of this batch.

## Visual redesign demo — 2026-10-22

User authorized a visual overhaul, dark mode, a non-AI Analyze icon, and graph
gesture isolation. Work remains local on codex/progress-recovery-storybook; no
commit/push until user demo approval. Trello must never be changed.

Added central light/dark slate-and-blue theme, themed surfaces/inputs/cards/chips,
fixed top navigation and responsive typography. Result mode has a compact workspace
heading instead of the landing hero. Theme toggle is in navigation, starts from
system preference, persists locally via shared_preferences, and preserves the
active service/result. Analyze uses a search icon in static mode and sparkle only
when AI is enabled. Graph nodes/background/edges now match the palette.

GraphInteractionNotification disables the surrounding scroll view while a mouse
is over the graph or touch pointers are active, with cancel/up/exit handling.
Pointer-signal resolution consumes graph wheel events; InteractiveViewer retains
zoom/pan. Both workspace and presentation participate.

Browser checks: light/dark screenshots inspected, saved snapshot reopened, theme
switch preserved current analysis, and wheel over graph zoomed without moving
page position. Full Android touch and narrow-screen acceptance remain pending.
Added theme/static-icon widget fixture; native widget execution remains blocked
by the previously documented local Flutter CPU detection crash. No hosted API
change or deployment. Review final build and analysis results before delivery.

### Responsive layout refinements — 2026-10-22

Following the visual demo, the header surface now stretches across the window;
workspace and header share proportional gutters (3.5%, bounded at 16–72px).
Removed the fixed desktop content/input width caps. Explore uses a responsive
one-to-three-column gallery; saved cards fill their available width. Graph height
tracks viewport height within readable bounds. Text and touch targets retain
usable sizes rather than scaling every dimension by percentage.

Dot grid is painted in viewport coordinates with transform-aware offsets, behind
the interactive scene, so it covers the graph even beyond node bounds when panning.
Static analysis passed. Widget execution remains subject to the previously
recorded local engine crash; mobile acceptance remains pending. No commit/push.
Release web build (including Wasm dry run) and diff whitespace check passed.
Reloaded browser demo and inspected Explore: full-width header, aligned gutters,
and two-column gallery at the preview window width render correctly.


### README accuracy audit — 2026-10-22

User reported that an AI interpretation called GitLore LLM-free. Audited README
against Flutter mode selection, crawler/cache, Worker Gemini implementation,
platform permissions, and CI. Moved explicit static-vs-optional-Gemini behavior
into the opening paragraphs and scoped the static pipeline description to AI off.
Clarified citation validation does not prove generated claims, fallback versus
request failures, client cache staleness/fallback reuse, historical deployment
evidence, and platform acceptance limits. Updated stale team milestones and
distinguished existing manual Worker deployment from absent automated deployment.
Removed unrelated optional Cloudflare developer-tool setup from the app README.

Documentation only in this batch; inspected implementation and diff, no runtime
code changes or new build/tests. Earlier UI changes remain uncommitted. Android
debug APK was built/installed and launched on Pixel 10 Pro in the preceding turn;
DNS resolved after emulator restart. Full mobile acceptance remains user-driven.
These README edits are local: GitHub analysis reads the remote default branch,
not this working tree. Publishing/merging and refreshing are separate actions;
do not commit, push, merge, or deploy without authorization.

### Export and selected-component connections — 2026-10-22

User accepted general mobile behavior and requested export plus connection filtering.
Added pure Dart ArchitectureExport (Mermaid and Markdown), an export preview dialog,
clipboard action, and share_plus file delivery. Markdown includes the map, snapshot
metadata, pinned AI citations or clearly labeled related source files, and warnings.
Demo exports do not invent pinned references. Mermaid uses generated node IDs and
numeric label entities to prevent source text becoming syntax; dangling edges omitted.
Standalone Mermaid retains source links and limitations in comments. No network/AI
calls for export. Added share_plus, its locked dependencies and required generated
platform registrants. Native sharing destinations vary; copy is the fallback.
Selected component details now filter edges by either endpoint and show a scoped
empty state, preserving the full graph.

Validation: Flutter analysis passed; 20 Dart backend tests passed including 3 new
export fixtures (escaping, references, demo provenance). Web/Wasm build and Android
debug build passed; APK installed and launched in the existing emulator. Browser
export dialog inspected with saved snapshot. Native widget engine limitation from
previous entries remains; file destination/round-trip rendering and final mobile
export acceptance are pending user test. README updated. No commit/push/deployment.
User will authorize commit/push after final demo and handle main merge themselves.

### Final demo accepted; development delivery authorized — 2026-10-22

User reported "Everything looks great!" after the export/mobile demo and explicitly
authorized this handover update, commit, and push to codex/progress-recovery-storybook.
This supersedes the preceding pending-demo/no-commit status for the current batch.
Preserve all earlier history. User will handle merging main; do not merge or deploy.

Delivery includes slate/blue light and dark themes with persisted preference,
responsive full-width navigation and gallery, viewport-filling graph dots and
isolated graph gestures, static/AI button icons, README accuracy corrections,
Mermaid/Markdown export with preview/copy/file delivery, and component-scoped
import connections. share_plus and required platform registrants/lockfile are
intentional dependency changes. No provider credentials belong in this commit.

Validation remains as recorded above: locked restore, format, analysis, 20 Dart
backend tests, release web/Wasm and Android debug builds passed; browser preview
and user mobile/final demos accepted. Native Flutter widget test execution on this
machine remains blocked by the previously documented CPU detection issue. User
acceptance does not imply every export destination/platform has been tested.
Next: verify development-branch CI, especially widget tests, before user merges;
exercise exported Mermaid/Markdown in the team's chosen documentation tools.
No Trello cards changed. No Worker deployment or main merge is included.
