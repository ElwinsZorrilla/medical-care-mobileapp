# syntax=docker/dockerfile:1.7
#
# Targets:
#   --target verify   → corre scripts/verify.sh; el build falla si la barra
#                       no pasa. Es la misma puerta que el gate local.
#   --target goldens  → regenera los goldens en Linux, la plataforma
#                       canonica. Unica forma soportada de actualizarlos; el
#                       comando completo esta encima del stage `goldens-build`.
#   --target web      → build web servido por nginx (RNF-05, RNF-09)
#
# Aca **no** se compila el APK, y los targets `artifacts`/`export` que lo
# intentaban se eliminaron en F14: nunca produjeron un byte. El detalle esta
# mas abajo, encima del stage `web-build`.
#
# Un APK tampoco corre dentro de un contenedor. Lo que se contiene aca es el
# **build**: misma version de SDK, mismas dependencias, misma barra en
# cualquier maquina del equipo y en CI.

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

# Sin `--mount=type=cache`. Parece la opcion obvia para acelerar, pero un
# cache mount de BuildKit **no queda en la capa**: se monta solo durante ese
# RUN. Los stages que heredan de `deps` encontraban /opt/pub-cache vacio, y el
# sintoma no era un fallo sino algo peor —
#
#   Warning: Couldn't read file ".../flutter_lints-6.0.0/lib/flutter.yaml"
#
# analysis_options.yaml incluye `package:flutter_lints/flutter.yaml`. Sin ese
# archivo el analizador se queda sin reglas y `flutter analyze` respondia
# "No issues found" sin haber comprobado nada. La puerta pasaba en verde con
# la vara en el suelo, que es justo lo que R5 prohibe.
#
# Escribiendo en la capa, el cache de capas de Docker cumple la misma funcion:
# mientras pubspec.lock no cambie, esta capa se reutiliza.
RUN flutter pub get

# ─────────────────────────────────────────────────────────────────────────
# Verificación: el mismo verify.sh que corre en local. Falla el build si algo
# no pasa — no se publica un artefacto que no aprobó el gate.
# ─────────────────────────────────────────────────────────────────────────
FROM deps AS verify
COPY . .
RUN ./scripts/verify.sh

# ─────────────────────────────────────────────────────────────────────────
# Regeneracion de goldens.
#
# Un golden es un rasterizado y no es identico bit a bit entre sistemas: los
# generados en Windows fallan aca por ~66 pixeles de antialiasing sin que nada
# este roto. Linux es la plataforma canonica —la misma donde corre el CI— y
# este stage es la unica forma soportada de regenerarlos:
#
#   docker build --target goldens -o test/core/widgets/goldens \
#     -f docker/Dockerfile .
#
# Hereda de `deps` y no de `verify` a proposito: si los goldens estan
# desactualizados, `verify` falla, y entonces no se podria regenerarlos.
# ─────────────────────────────────────────────────────────────────────────
FROM deps AS goldens-build
COPY . .
RUN flutter test --update-goldens test/core/widgets/status_rail_golden_test.dart

FROM scratch AS goldens
COPY --from=goldens-build /app/test/core/widgets/goldens /

# ─────────────────────────────────────────────────────────────────────────
# Target web
# ─────────────────────────────────────────────────────────────────────────
#
# Acá **no** se compila el APK, y los targets `artifacts`/`export` que lo
# intentaban se eliminaron. Nunca produjeron un byte: `flutter build apk`
# necesita el SDK de Android completo —cmdline-tools, platform-tools,
# build-tools— y el stage instalaba solo el JDK. El comando que el README
# documentaba (`--target export -o ./dist`) fallaba con "No Android SDK
# found" en la primera invocacion.
#
# Instalarlo habria sumado ~2 GB a la imagen para producir un artefacto que
# ademas no es distribuible: android/app/build.gradle.kts firma el release
# con la configuracion de depuracion. La compilacion Android vive en el job
# `apk` de .github/workflows/ci.yml, sobre un runner que ya trae el SDK.
FROM verify AS web-build
ARG API_BASE_URL

# Docker no tiene build-args obligatorios, asi que se comprueba a mano. Sin
# esto el build sale VERDE con la URL vacia y el fallo aparece recien en el
# navegador: `Env.validar()` lanza antes de `runApp`, la pagina queda en
# blanco, y el HEALTHCHECK sigue devolviendo 200 porque nginx sirve el HTML
# perfectamente. Un contenedor "sano" que no muestra nada es peor que uno que
# no arranca. El `case` rechaza tambien la URL presente pero relativa, que es
# lo mismo que rechaza core/config/env.dart.
RUN case "$API_BASE_URL" in \
      http://*|https://*) ;; \
      *) echo "FALTA o es invalida --build-arg API_BASE_URL (recibido: '$API_BASE_URL')." >&2; \
         echo "  Ej: --build-arg API_BASE_URL=http://localhost:8080/api" >&2; \
         exit 1 ;; \
    esac

# `--no-web-resources-cdn` es obligatorio, no una optimizacion.
#
# Por omision `flutter_bootstrap.js` baja CanvasKit de
# https://www.gstatic.com/flutter-canvaskit. La CSP de
# docker/security-headers.conf declara `script-src 'self'`, asi que el
# navegador bloquea esa descarga y la app se queda en blanco — comprobado en
# el bundle servido, donde `useLocalCanvasKit` salia en falso. Con la bandera,
# canvaskit se empaqueta en build/web/canvaskit y se sirve del mismo origen.
# De regalo, el contenedor deja de necesitar salida a internet para arrancar.
RUN flutter build web --release --no-web-resources-cdn \
      --dart-define=API_BASE_URL="$API_BASE_URL"

FROM nginx:1.27-alpine AS web
COPY --from=web-build /app/build/web /usr/share/nginx/html
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
# Se incluye desde cada `location`: en nginx `add_header` no se hereda.
COPY docker/security-headers.conf /etc/nginx/security-headers.conf

RUN addgroup -S app && adduser -S app -G app \
 && touch /var/run/nginx.pid \
 && chown -R app:app /var/run/nginx.pid /var/cache/nginx /usr/share/nginx/html
USER app

EXPOSE 8080
# 127.0.0.1 y no `localhost`: dentro del contenedor `localhost` resuelve
# primero a ::1, nginx escucha solo en IPv4, y el healthcheck fallaba con
# "connection refused" aunque el servidor respondiera perfecto desde fuera.
# El contenedor quedaba `unhealthy` y cualquier orquestador lo habria
# reiniciado en bucle. Comprobado con `docker inspect` en F14.
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8080/healthz || exit 1

CMD ["nginx", "-g", "daemon off;"]
