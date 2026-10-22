# GitLore

A Flutter app that turns a public GitHub repository into a source-backed architecture inventory and guided code tour, with optional **Gemini LLM explanations through a Cloudflare Workers backend**.

GitLore has two analysis modes:
- **AI off (default):** deterministic static analysis runs without an LLM or team access code.
- **AI on:** the server calls Gemini to generate a summary and cited chapters from sampled source excerpts. The architecture map still comes from static analysis. Gemini credentials remain on the server; users enter a team access code.

GitLore is **not an LLM-free application**. Its static mode works independently of its optional LLM integration. Neither mode proves runtime behavior, and AI explanations can be wrong.

New contributors and AI agents: start with [AGENTS.md](AGENTS.md) and the
[project handover](docs/HANDOVER.md) for the product goal, architecture, setup,
coding rules, current status, and prioritized next tasks.

## Run

```sh
flutter pub get --enforce-lockfile
flutter run -d chrome
```

Paste a public `https://github.com/owner/repo` URL and select **Analyze repository**. Static mode requires no keys or backend setup. Optional AI requires a configured server and its team access code. Web builds and an Android emulator build have been exercised; full mobile compatibility acceptance is still pending. Other Flutter platform scaffolds are present, but this is not a claim that every platform has been verified. Android and macOS network permissions are included.

## Static repository analysis (AI off)

In the default static mode, the application calls GitHub's public REST API directly:

1. Fetch repository metadata and resolve the default branch to a commit SHA.
2. Fetch the recursive Git tree from that commit.
3. Rank README, dependency manifests, entry points, and selected source files.
4. Fetch up to eight UTF-8 text files, each at most 40,000 bytes, with a combined 180,000-byte budget. Skip generated files, vendor folders, tests, examples, symlinks, and lockfiles. Tree responses are limited to 8 MB and individual blob responses to 70 KB.
5. Extract declared technologies, display file roles with uncertainty labels, and resolve literal relative imports between sampled JS/TS/Dart files.
6. Build a repository-specific chapter tour with source excerpts and clickable GitHub links pinned to the analyzed commit.

This pipeline is **deterministic static analysis**. Enabling AI adds Gemini-generated explanations to its results; it does not turn the import map into a verified runtime request trace. File roles are inferred from naming; dependency declarations do not prove runtime usage. Import extraction uses a conservative lexical scanner rather than a complete language parser. It skips line/block comments and ordinary quoted strings, and supports JS/TS static imports, re-exports, literal require calls, extensionless paths and directory index files among sampled sources. Exact paths take precedence; supported extensions are .ts, .tsx, .js, .jsx, .mjs and .cjs, with .js-to-.ts/.tsx fallback. Relative Dart import/export directives are also supported. Aliases, package resolution, dynamic import(), computed require calls, escaped specifiers, template interpolation, JSX text parsing and scope/shadowing analysis are unsupported. Regex recognition is heuristic; this is not compiler-level resolution. The canvas draws arrows labeled **imports** from importing files to imported files. Only resolved references between sampled files create arrows; unconnected nodes remain visible. Drag to pan and pinch to zoom, or use Zoom in/out, Fit to view and Reset above the map. Fit includes all nodes and import lanes; Reset returns to the original scale and position. Selecting a node opens its existing source details and highlights its incoming and outgoing arrows. Vertical ordering does not imply data flow. The static map does not synthesize database or HTTP request flows. Gemini is instructed not to invent them, but its explanations still require human verification.

Coverage and truncated-tree warnings are shown under **Analysis scope & limitations**. Empty repositories, inaccessible repositories, network failures, and GitHub rate limits produce readable errors. Unsupported repositories still show metadata and any supported files; the app does not execute repository code. Source excerpts show the first 24 lines; open a source link for the complete file.

Public GitHub requests share an unauthenticated API quota. A successful direct static crawl uses three inventory requests plus up to eight file requests. The workspace reuses returned results for ten minutes in a session cache of up to ten repositories, without rechecking the current commit on a cache hit. This can include a static fallback returned by an AI request; Retry AI bypasses the client cache. **Refresh analysis** checks the displayed repository again immediately; overlapping requests share one fetch. Analysis cache resets on reload; saved projects persist locally through shared preferences. See [GitHub rate limits](https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api) and [tree API documentation](https://docs.github.com/en/rest/git/trees). Never embed private GitHub or LLM credentials in a Flutter client.

## Optional AI server

Cloudflare Workers is the selected host. The [Workers backend and runbook](backend/worker/README.md)
provide a server-only Gemini key, team access code, bounded requests, checked
citations, durable budgets/cache, retries and static fallback. The handover records local tests and deployment at [the team server](https://gitlore-api.jack-j-dugan.workers.dev).
See the latest [handover](docs/HANDOVER.md) for live acceptance and Gemini setup status.
The handover records configured server secrets and successful real-repository AI summaries and chapters
that passed through Cloudflare and the Flutter adapter, including Express and a
JavaScript utility repository. If the server's GitHub quota is exhausted, the app
fetches the same bounded public source itself and sends it to the authenticated
server for AI analysis. Gemini requests and its key always stay on the server.
Successful AI summaries reuse the first cited overview chapter; the static map
remains available. See the handover for exact evidence and remaining limitations.
Citation checks validate references to supplied excerpts, not whether every generated claim is true. Source sampling can omit important parts of a repository. Deployment/configuration status above is historical acceptance evidence, not a continuous availability guarantee.
The [Dart prototype](backend/README.md)
is still available for local experiments.

Enable **AI explanation**, then use **Server settings** to enter the team code;
the hosted URL is already the default. Enter the Gemini key only in the server's
secret store. For local development, change Server settings to port 8087 or use
`--dart-define=GITLORE_API_URL=http://127.0.0.1:8087` (Android emulator: `10.0.2.2`). The public
URL may also be set with `--dart-define=GITLORE_API_URL=...`; never use a define
for a privileged key. Turning AI off preserves direct keyless GitHub analysis.
When static analysis has completed, handled Gemini failures return a static fallback with a retry action. Authentication, network, or earlier server failures may instead show an error with retry/settings/static-mode recovery options.

For the MVP web demo, use an origin allowed by the server:

```sh
flutter run -d chrome --web-hostname=127.0.0.1 --web-port=8086
```

Enable **AI explanation**, enter the existing team code in **Server settings**,
and analyze `https://github.com/expressjs/express`. A successful result is labeled
AI and shows an AI-written summary plus cited chapters. Try
`https://github.com/jonschlinkert/is-number` for a smaller code example. The team
code must be entered again after an app restart. Free provider/API quotas can
still cause fallback; a static result must not be presented as successful AI.

## Team handoff

| Owner | Starting files | Next milestone |
| --- | --- | --- |
| Diagram canvas | `lib/widgets/architecture_canvas.dart` | Add automatic graph layout; validate the new zoom/fit controls across devices |
| GitHub crawler | `packages/gitlore_core/lib/services/`, `backend/worker/src/services/github.ts` | Broader language/monorepo coverage and sampling verification |
| Prompt engine | `backend/worker/src/services/gemini.ts`, `backend/contracts/` | Broader explanation/citation acceptance; monitor provider failures |
| Saved projects & UI | `lib/main.dart`, shared `bookshelf_service.dart` | Complete mobile/restart acceptance; add diagram and Markdown export |

`ArchitectureService` is injectable through `GitLoreApp(service: ...)`. The app uses `GitHubArchitectureService` by default; `DemoArchitectureService` remains available for offline UI development. Re-saving replaces the local snapshot. Shared models/services live in `packages/gitlore_core/lib/`; matching files in `lib/` are compatibility exports.

## Verify

Use Flutter **3.47.2 stable** / Dart **3.13.2** to match CI. No environment variables
or app secrets are needed for fixture-based verification. On Windows, native plugin setup may require Developer Mode.

```sh
flutter pub get --enforce-lockfile
cd backend
dart pub get --enforce-lockfile
cd ..
dart format --output=none --set-exit-if-changed lib test tool packages/gitlore_core/lib backend/bin backend/lib backend/test
flutter analyze --no-pub
flutter test --no-pub --coverage
dart --packages=.dart_tool/package_config.json tool/generate_worker_fixture.dart --check
flutter build web --release --no-pub
cd backend
dart analyze --fatal-infos
dart test
```

Unit tests use mocked GitHub responses and verify commit pinning, content-based results, literal import edges, bounded sampling, partial coverage, invalid URLs, and API failures. Widget tests cover source excerpts, chapters, saved projects, and narrow layouts. Run the separate [Worker checks](backend/worker/README.md#verification) too. The optional root command `dart run tool/analyze_repository.dart https://github.com/expressjs/express` performs a real public GitHub smoke test without launching Flutter.

The same CLI can check the hosted server using runtime environment variables:
`GITLORE_API_URL` for its HTTPS URL, `GITLORE_TEAM_ACCESS_TOKEN` for the team code,
and optional `GITLORE_AI=true` for an AI request. These are CLI environment
variables, not Flutter build defines. Load the team code privately from your
ignored settings; never paste it into a command, log or Git. Static requests are
the CLI default and consume no Gemini quota. Live checks are intentionally outside CI.

## Automated builds

[GitLore CI](.github/workflows/ci.yml) runs on every push and pull request, with
manual runs available in GitHub Actions. It restores locked dependencies, checks
formatting, analyzes code, runs unit/widget tests, and builds the release web app.
Successful runs attach the web bundle and coverage report as downloadable artifacts
for seven days. Tests use fixtures and require no GitHub or LLM keys. CI builds the
web target. A separate Node.js job verifies Worker formatting/types, fixtures,
actual Workers runtime behavior and a Wrangler dry-run bundle artifact. Dart
backend tests and a shared contract fixture check also run. Automated deployment and native
release artifacts are not part of this workflow; the Worker has been deployed separately.

Before finishing a change, update [docs/HANDOVER.md](docs/HANDOVER.md) with completed
work, decisions, validation, and the next steps. Use a feature branch and PR to `main`.

### Local AI demo errors

With AI explanation enabled, a returned static fallback displays an explicit
fallback card above the static result. Requests that fail before a result is available instead show recovery actions and retain any previous result. It includes a safe reason (such as Gemini
HTTP 503, quota, configuration, connection, or timeout) and Retry AI analysis.
Retry refreshes the analysis rather than reusing the client cache. Provider secrets
and raw error responses are not shown. Both local backend options use port 8087;
run one at a time. Workers reads ignored `backend/worker/.dev.vars`; the Dart
prototype reads ignored `backend/.env`. Hosted Workers uses Cloudflare secrets.
Restart local servers after changing configuration.

### Progress, recovery and presentation

Analysis displays observed client stages, including selected file reads. Hosted
AI shows a server-wait state rather than guessed server progress. Failures retain
the previous result with a stale-result notice and recovery actions; available
quota timing hints appear as a suggested local retry time.

Choose **Present storybook** on a result for a focused sequential walkthrough,
component highlighting and source citations. AI/static/demo labels and import-map
limitations stay visible. Presentation uses the loaded result without another AI
request; Back returns to the workspace.

### Explore and personal library

Explore offers curated repository starting points with descriptions and technology
tags. Selecting one requests a fresh analysis using the current AI setting; these
are not precomputed demonstrations. Search and technology filters are available
in Explore and Saved projects, with result counts and clear-filter controls.
Individual saved-project deletion requires confirmation and affects only this
device's saved snapshot, never the GitHub repository.

### Appearance and graph navigation

Use the sun/moon control in the fixed navigation bar to switch light/dark themes.
The preference is saved on this device. Static Analyze uses a search icon; the
sparkle appears only in AI mode. Scroll/drag inside the graph manipulates the
canvas while the surrounding page stays still; move outside it to scroll the page.

### Export

Choose **Export analysis** on a loaded result. Export a Mermaid `.mmd` import map
or a Markdown `.md` walkthrough containing the map, chapters, repository/commit,
source references and limitations. Exports use the loaded snapshot without new API
calls. Diagram source references and warnings are retained as Mermaid comments.
The preview offers **Copy text** and **Download / share** on web or **Share file**
on mobile. Browser/device support determines whether a share sheet or download
opens; mobile saving destinations depend on installed apps. Copy remains available
if file export is unsupported. Export does not publish anything automatically.
