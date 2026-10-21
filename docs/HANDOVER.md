# GitLore handover

Last updated: 2026-10-21 (America/Chicago).
Current pass: `codex/cloudflare-worker`, based on `feat/sprint-gl-01-04` at `13e00c3`.
See **Cloudflare agent connection — 2026-10-21** at the end for the current setup
checkpoint and **Cloudflare implementation handoff — 2026-10-21** for implementation
decisions, verification, limitations and the next task. Dated entries preserve
history; the newest entry supersedes older status/hosting decisions.
Read this file together with root [`AGENTS.md`](../AGENTS.md) and the latest Git history.
This is a living project status document; update it in every implementation PR.

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
and expanded CI. The Workers implementation is locally verified, not deployed.

**Still pending:** hosted provisioning/secrets/live acceptance; individual user
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
  available on the next turn; MCP loading requires restarting the agent/app.
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
  This session's callable tools still lack Cloudflare: restart Codex to load it.
  Do not inspect stored OAuth credentials or manually extract tokens as a workaround.
- Skipped optional global beta `cf` CLI and user-level instruction changes:
  this project already uses Wrangler, which the official skills explicitly retain.
- No project runtime code changed. Only documentation changed in this checkpoint;
  `git diff --check` is the relevant validation. Last runtime verification remains
  the successful 54 fixture tests, two workerd tests and bundle recorded above.
- The connection is developer access to Cloudflare, not a deployed GitLore server.
  No server secrets or live endpoint exist yet; no deployment, push, merge or
  billing change occurred. Account Free-plan status has not yet been inspected.
- **Next action:** restart Codex, reopen this chat and continue hosted setup.
  Read the installed `wrangler`/`durable-objects` guidance as applicable. Use the
  newly connected MCP to verify the account/Free plan and inspect existing Workers
  before deploying `gitlore-api`. Keep the versioned schema and SQLite migration;
  use Cloudflare's secret interface for Gemini and team credentials, then connect
  Flutter to the actual HTTPS URL and run live acceptance. Deployment remains
  within the user's ongoing server-setup request; no additional generic permission
  question is needed for that already authorized work. New scopes/paid services
  or unrelated resources still require their own authorization.
