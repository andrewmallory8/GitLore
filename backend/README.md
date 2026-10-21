# Local analysis server prototype

The selected hosted implementation is [Cloudflare Workers](worker/README.md).
This Dart server remains for local experiments; it is not the Workers entry point.
Both implement schema v1. Dart models/services are shared through the pure Dart
`packages/gitlore_core` path dependency; do not import out of package boundaries.

Use Dart 3.13.2. From this directory run `dart pub get --enforce-lockfile`
and `dart test`. Copy `.env.example` to `.env` without overwriting existing keys.
Set GEMINI_API_KEY locally; do not commit it. Restart after environment changes.

From the repository root run:

```sh
dart --packages=backend/.dart_tool/package_config.json backend/bin/server.dart
```

Default URL is http://127.0.0.1:8087. GET /health reports configuration presence
only; POST /v1/analyze accepts the versioned JSON in contracts/. Flutter's AI
explanation switch uses this endpoint. Serve web on port 8086 for the default
allowed browser origins. Leave team access code empty for local defaults.

For public binding, configure HOST, ALLOWED_HOSTS, ALLOWED_ORIGINS and a
TEAM_ACCESS_TOKEN of at least 32 characters. Workers adds deployment configuration,
durable budgets/cache and retries; hosted verification remains pending. The Dockerfile
is a deployment starting point, not a verified hosted service.

Gemini failures retain static analysis and return safe warnings. No raw provider
errors or credentials are returned. In-memory cache and request limits reset on
restart. Free-tier quotas and model availability can change.
