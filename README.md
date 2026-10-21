# GitLore

A Flutter app that turns a public GitHub repository into a source-backed architecture inventory and guided code tour.

New contributors and AI agents: start with [AGENTS.md](AGENTS.md) and the
[project handover](docs/HANDOVER.md) for the product goal, architecture, setup,
coding rules, current status, and prioritized next tasks.

## Run

```sh
flutter pub get --enforce-lockfile
flutter run -d chrome
```

Paste a public `https://github.com/owner/repo` URL and select **Analyze repository**. No keys or backend setup are required. Flutter desktop and mobile targets are supported too; Android and macOS network permissions are included.

## Real repository analysis

The application calls GitHub's public REST API directly:

1. Fetch repository metadata and resolve the default branch to a commit SHA.
2. Fetch the recursive Git tree from that commit.
3. Rank README, dependency manifests, entry points, and selected source files.
4. Fetch up to eight UTF-8 text files, each at most 40,000 bytes, with a combined 180,000-byte budget. Skip generated files, vendor folders, tests, examples, symlinks, and lockfiles. Tree responses are limited to 8 MB and individual blob responses to 70 KB.
5. Extract declared technologies, display file roles with uncertainty labels, and resolve literal relative imports between sampled JS/TS/Dart files.
6. Build a repository-specific chapter tour with source excerpts and clickable GitHub links pinned to the analyzed commit.

This is **deterministic static analysis, not LLM analysis or a verified runtime request trace**. File roles are inferred from naming; dependency declarations do not prove runtime usage. Import extraction uses a conservative lexical scanner rather than a complete language parser. It skips line/block comments and ordinary quoted strings, and supports JS/TS static imports, re-exports, literal require calls, extensionless paths and directory index files among sampled sources. Exact paths take precedence; supported extensions are .ts, .tsx, .js, .jsx, .mjs and .cjs, with .js-to-.ts/.tsx fallback. Relative Dart import/export directives are also supported. Aliases, package resolution, dynamic import(), computed require calls, escaped specifiers, template interpolation, JSX text parsing and scope/shadowing analysis are unsupported. Regex recognition is heuristic; this is not compiler-level resolution. The canvas draws arrows labeled **imports** from importing files to imported files. Only resolved references between sampled files create arrows; unconnected nodes remain visible. Drag to pan and pinch to zoom, or use Zoom in/out, Fit to view and Reset above the map. Fit includes all nodes and import lanes; Reset returns to the original scale and position. Selecting a node opens its existing source details and highlights its incoming and outgoing arrows. Vertical ordering does not imply data flow. A database or HTTP request flow is never invented.

Coverage and truncated-tree warnings are shown under **Analysis scope & limitations**. Empty repositories, inaccessible repositories, network failures, and GitHub rate limits produce readable errors. Unsupported repositories still show metadata and any supported files; the app does not execute repository code. Source excerpts show the first 24 lines; open a source link for the complete file.

Public GitHub requests share an unauthenticated API quota. One analysis uses three inventory requests plus up to eight file requests. The workspace reuses successful results for ten minutes in a session cache of up to ten repositories. **Refresh analysis** checks the displayed repository again immediately; overlapping requests share one fetch. Analysis cache resets on reload; saved projects persist locally through shared preferences. See [GitHub rate limits](https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api) and [tree API documentation](https://docs.github.com/en/rest/git/trees). Never embed private GitHub or LLM credentials in a Flutter client.

## Optional AI server

Cloudflare Workers is the selected host. The [Workers backend and runbook](backend/worker/README.md)
provide a server-only Gemini key, team access code, bounded requests, checked
citations, durable budgets/cache, retries and static fallback. Implementation is
tested locally and deployed at [the team server](https://gitlore-api.jack-j-dugan.workers.dev).
See the latest [handover](docs/HANDOVER.md) for live acceptance and Gemini setup status.
Both server secrets are configured. Hosted static analysis, authentication and
caching passed live checks. Gemini now uses Flash-Lite with brief chapters and
passes live connection/synthetic citation checks. Fresh real-repository AI
verification is pending GitHub's separate public quota reset. See the handover
and the backend's protected diagnostic endpoint for details.
The [Dart prototype](backend/README.md)
is still available for local experiments.

Enable **AI explanation**, then use **Server settings** to enter the team code;
the hosted URL is already the default. Enter the Gemini key only in the server's
secret store. For local development, change Server settings to port 8087 or use
`--dart-define=GITLORE_API_URL=http://127.0.0.1:8087` (Android emulator: `10.0.2.2`). The public
URL may also be set with `--dart-define=GITLORE_API_URL=...`; never use a define
for a privileged key. Turning AI off preserves direct keyless GitHub analysis.
Provider failures show a static fallback and retry action.

Cloudflare's optional [agent setup guide](https://developers.cloudflare.com/agent-setup/prompt.md)
connects developer tools to Cloudflare through OAuth and installs coding skills.
This is local developer setup, separate from deploying the GitLore server or
configuring its Gemini key. Each developer authorizes their own connection;
If the new tools do not appear, restart Codex to load the MCP server. Keep its configuration
and OAuth credentials outside this repository.

## Team handoff

| Owner | Starting files | Next milestone |
| --- | --- | --- |
| Diagram canvas | `lib/widgets/architecture_canvas.dart` | Add automatic graph layout; validate the new zoom/fit controls across devices |
| GitHub crawler | `packages/gitlore_core/lib/services/`, `backend/worker/src/services/github.ts` | Hosted verification and better monorepo sampling |
| Prompt engine | `backend/worker/src/services/gemini.ts`, `backend/contracts/` | Hosted Gemini acceptance and better evidence-backed explanations |
| Saved projects & UI | `lib/main.dart`, shared `bookshelf_service.dart` | Restart/mobile acceptance, Explore and progress |

`ArchitectureService` is injectable through `GitLoreApp(service: ...)`. The app uses `GitHubArchitectureService` by default; `DemoArchitectureService` remains available for offline UI development. Re-saving replaces the local snapshot. Shared models/services live in `packages/gitlore_core/lib/`; matching files in `lib/` are compatibility exports.

## Verify

Use Flutter **3.47.2 stable** / Dart **3.13.2** to match CI. No environment variables
or app secrets are needed. On Windows, native plugin setup may require Developer Mode.

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
backend tests and a shared contract fixture check also run. Deployment and native
release builds remain future work.

Before finishing a change, update [docs/HANDOVER.md](docs/HANDOVER.md) with completed
work, decisions, validation, and the next steps. Use a feature branch and PR to `main`.

### Local AI demo errors

With AI explanation enabled, unsuccessful AI generation displays an explicit
fallback card above the static result. It includes a safe reason (such as Gemini
HTTP 503, quota, configuration, connection, or timeout) and Retry AI analysis.
Retry refreshes the analysis rather than reusing the client cache. Provider secrets
and raw error responses are not shown. Both local backend options use port 8087;
run one at a time. Workers reads ignored `backend/worker/.dev.vars`; the Dart
prototype reads ignored `backend/.env`. Hosted Workers uses Cloudflare secrets.
Restart local servers after changing configuration.
