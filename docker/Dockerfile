# syntax=docker/dockerfile:1.7
#
# Dos targets:
#   --target artifacts  → compila APK/AAB, los deja en /out (build reproducible)
#   --target web        → sirve el build web con nginx (demo y pruebas e2e)
#
# Un APK no corre dentro de un contenedor. Lo que se contiene acá es el
# **build**, que es lo que de verdad hace falta reproducible: misma versión de
# SDK, mismas dependencias, mismo resultado en cualquier máquina del equipo y
# en CI.

# ─────────────────────────────────────────────────────────────────────────
# Base: SDK de Flutter fijado por versión. Nunca 'latest'.
# ─────────────────────────────────────────────────────────────────────────
FROM debian:bookworm-slim AS flutter-sdk

ARG FLUTTER_VERSION=3.44.5
ENV FLUTTER_HOME=/opt/flutter \
    PATH=/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:$PATH \
    PUB_CACHE=/opt/pub-cache

RUN apt-get update && apt-get install -y --no-install-recommends \
      curl git unzip xz-utils zip ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch "$FLUTTER_VERSION" \
      https://github.com/flutter/flutter.git "$FLUTTER_HOME" \
    && git config --global --add safe.directory "$FLUTTER_HOME" \
    && flutter --version \
    && flutter precache --universal

# ─────────────────────────────────────────────────────────────────────────
# Dependencias: capa aparte para que el caché sobreviva a cambios de código.
# ─────────────────────────────────────────────────────────────────────────
FROM flutter-sdk AS deps
WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN --mount=type=cache,target=/opt/pub-cache flutter pub get

# ─────────────────────────────────────────────────────────────────────────
# Verificación: el mismo verify.sh que corre en local. Falla el build si algo
# no pasa — no se publica un artefacto que no aprobó el gate.
# ─────────────────────────────────────────────────────────────────────────
FROM deps AS verify
COPY . .
RUN ./scripts/verify.sh

# ─────────────────────────────────────────────────────────────────────────
# Artefactos Android
# ─────────────────────────────────────────────────────────────────────────
FROM verify AS artifacts

ARG API_BASE_URL
ARG SOCKET_URL
ARG BUILD_NUMBER=1

RUN apt-get update && apt-get install -y --no-install-recommends \
      openjdk-17-jdk-headless \
    && rm -rf /var/lib/apt/lists/*
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64

RUN flutter build apk --release \
      --build-number="$BUILD_NUMBER" \
      --dart-define=API_BASE_URL="$API_BASE_URL" \
      --dart-define=SOCKET_URL="$SOCKET_URL" \
 && flutter build appbundle --release \
      --build-number="$BUILD_NUMBER" \
      --dart-define=API_BASE_URL="$API_BASE_URL" \
      --dart-define=SOCKET_URL="$SOCKET_URL" \
 && mkdir -p /out \
 && cp build/app/outputs/flutter-apk/app-release.apk /out/ \
 && cp build/app/outputs/bundle/release/app-release.aab /out/

# Etapa de exportación: `docker build --target export -o ./dist .`
FROM scratch AS export
COPY --from=artifacts /out /

# ─────────────────────────────────────────────────────────────────────────
# Target web
# ─────────────────────────────────────────────────────────────────────────
FROM verify AS web-build
ARG API_BASE_URL
ARG SOCKET_URL
RUN flutter build web --release \
      --dart-define=API_BASE_URL="$API_BASE_URL" \
      --dart-define=SOCKET_URL="$SOCKET_URL"

FROM nginx:1.27-alpine AS web
COPY --from=web-build /app/build/web /usr/share/nginx/html
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf

RUN addgroup -S app && adduser -S app -G app \
 && touch /var/run/nginx.pid \
 && chown -R app:app /var/run/nginx.pid /var/cache/nginx /usr/share/nginx/html
USER app

EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost:8080/healthz || exit 1

CMD ["nginx", "-g", "daemon off;"]
