# GitLore

A Flutter app that turns a public GitHub repository into a source-backed architecture inventory and guided code tour.

## Run

```sh
flutter pub get
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

This is **deterministic static analysis, not LLM analysis or a verified runtime request trace**. File roles are inferred from naming; dependency declarations do not prove runtime usage. Import extraction uses literal patterns rather than a complete language parser and may include references in comments or miss aliases, dynamic imports, and other languages. The canvas draws arrows labeled **imports** from importing files to imported files. Only resolved references between sampled files create arrows; unconnected nodes remain visible. Scroll horizontally and vertically to explore larger maps. Selecting a node opens its existing source details and highlights its incoming and outgoing arrows. Vertical ordering does not imply data flow. A database or HTTP request flow is never invented.

Coverage and truncated-tree warnings are shown under **Analysis scope & limitations**. Empty repositories, inaccessible repositories, network failures, and GitHub rate limits produce readable errors. Unsupported repositories still show metadata and any supported files; the app does not execute repository code. Source excerpts show the first 24 lines; open a source link for the complete file.

Public GitHub requests share an unauthenticated API quota. One analysis uses three inventory requests plus up to eight file requests. There is no persistent cache yet. See [GitHub rate limits](https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api) and [tree API documentation](https://docs.github.com/en/rest/git/trees). Never embed private GitHub or LLM credentials in a Flutter client; add a server endpoint for authenticated access or AI analysis.

## Team handoff

| Owner | Starting files | Next milestone |
| --- | --- | --- |
| Diagram canvas | `lib/widgets/architecture_canvas.dart` | Add automatic graph layout, zoom, and fit-to-view controls |
| GitHub crawler | `lib/services/github_architecture_service.dart` | Add server-side caching and better monorepo sampling |
| Prompt engine | `lib/services/repository_analyzer.dart`, `lib/models/architecture.dart` | Add an optional server-hosted LLM that returns evidence and uncertainty |
| Saved projects & UI | `lib/main.dart` | Add persistent storage, Explore, and analysis progress |

`ArchitectureService` is injectable through `GitLoreApp(service: ...)`. The app uses `GitHubArchitectureService` by default; `DemoArchitectureService` remains available for offline UI development. Saved projects last for the current session; re-saving replaces the old analysis with the current result.

## Verify

```sh
flutter analyze
flutter test
flutter build web
dart run tool/analyze_repository.dart https://github.com/expressjs/express
```

Unit tests use mocked GitHub responses and verify commit pinning, content-based results, literal import edges, bounded sampling, partial coverage, invalid URLs, and API failures. Widget tests cover source excerpts, chapters, saved projects, and narrow layouts. The CLI performs a real public GitHub smoke test without launching Flutter.
