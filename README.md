# GitLore

A Flutter starter for turning a repository into an interactive architecture story.

## Run

With Flutter installed:

```sh
flutter pub get
flutter run -d chrome
```

You can also run on a configured desktop or mobile target. No API keys or additional packages are needed for this demo.

## What works

- Responsive repository input and URL validation.
- Clearly labeled sample architecture for any accepted repository URL.
- Clickable native Flutter diagram with component descriptions and illustrative file paths.
- Four story chapters with synchronized node highlighting.
- Save and reopen projects during the current session.
- Loading and error states.

**This starter does not fetch GitHub or call an LLM.** Submitted URLs label the demo fixture; its nodes and paths are examples, not claims about that repository. Saved projects reset when the application restarts.

## Team handoff

| Owner | Starting files | Next milestone |
| --- | --- | --- |
| Diagram canvas | `lib/widgets/architecture_canvas.dart` | Add arbitrary edges, graph layout, zoom, and source links |
| GitHub crawler | New server endpoint | Retrieve bounded README, tree, manifests, and entry points from public repos |
| Prompt engine | `lib/models/architecture.dart`, `lib/services/architecture_service.dart` | Produce validated architecture data with file evidence |
| Saved projects & UI | `lib/main.dart` | Add persistent storage, Explore, and cached analyses |

Implement `ArchitectureService` with an HTTP-backed service and inject it through `GitLoreApp(service: ...)`. Keep GitHub credentials, provider keys, and model calls on the server. The current ordered list of nodes represents a linear example; add explicit edges to the model for real architecture graphs.

A future server should validate GitHub URLs independently, cap fetch sizes and file counts, avoid generated/binary files, treat repository text as untrusted input, and cache by repository plus commit SHA. Include evidence and uncertainty in generated explanations. Do not infer missing components as facts.

## Verify

```sh
flutter analyze
flutter test
flutter build web
```
