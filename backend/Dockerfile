FROM dart:3.13.2 AS build
WORKDIR /app
COPY backend/pubspec.* backend/
COPY packages/gitlore_core packages/gitlore_core
WORKDIR /app/backend
RUN dart pub get --enforce-lockfile
WORKDIR /app
COPY backend/bin backend/bin
COPY backend/lib backend/lib
RUN dart --packages=backend/.dart_tool/package_config.json compile exe backend/bin/server.dart -o /app/server
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && rm -rf /var/lib/apt/lists/*
COPY --from=build /app/server /usr/local/bin/gitlore
USER 65534:65534
ENV HOST=0.0.0.0 PORT=8087
EXPOSE 8087
CMD ["/usr/local/bin/gitlore"]
