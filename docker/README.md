# Docker

## Qué se puede y qué no

**No se puede** meter una app Android en un contenedor y correrla. Un APK
necesita Android Runtime; Docker no lo provee. Lo que se contiene acá es el
**build** y el **front web**, que es lo que de verdad sirve.

**Tampoco se compila el APK acá.** Los targets `artifacts` y `export` que lo
intentaban se eliminaron en F14: nunca produjeron un byte. `flutter build apk`
necesita el SDK de Android completo —cmdline-tools, platform-tools,
build-tools— y el stage instalaba solo el JDK, así que el comando que este
mismo archivo documentaba fallaba con *"No Android SDK found"*. Sumarlo habría
engordado la imagen ~2 GB para producir un artefacto que además no es
distribuible: `android/app/build.gradle.kts:32` firma el release con la
configuración de depuración. La compilación Android vive en el job `apk` de
`.github/workflows/ci.yml`, sobre un runner que ya trae el SDK.

**Lo que sí hace este setup:**

1. **Barra de calidad reproducible** — el SDK, las dependencias y los flags
   quedan fijados en la imagen. `--target verify` corre el mismo
   `scripts/verify.sh` que el gate local, con la misma versión de Flutter, en
   cualquier máquina del equipo y en CI.
2. **Goldens deterministas** — Linux es la plataforma canónica. Un golden es
   un rasterizado y no es idéntico bit a bit entre sistemas: los generados en
   Windows fallan acá por ~66 píxeles de antialiasing sin que nada esté roto.
3. **Front web servido con nginx** — con las cabeceras de seguridad, el rate
   limit y el healthcheck de RNF-05 y RNF-09, comprobados con `curl` y no por
   inspección del archivo.

## Uso

```bash
# Correr la barra completa dentro del contenedor
docker build --target verify -f docker/Dockerfile .

# Regenerar los goldens (unica forma soportada)
docker build --target goldens -o test/core/widgets/goldens -f docker/Dockerfile .

# Imagen web
docker build --target web -t medicare-front \
  --build-arg API_BASE_URL=http://localhost:8080/api \
  -f docker/Dockerfile .
docker run --rm --network medicare -p 8080:8080 medicare-front

# Solo el front, sin backend
docker compose -f docker/docker-compose.yml up --build

# Front + api + db + cache
docker compose -f docker/docker-compose.yml --profile full up --build
```

`API_BASE_URL` es obligatorio y el build lo rechaza si falta o no es absoluta.
Sin ese guard el build salía verde y el fallo aparecía recién en el navegador:
`Env.validar()` lanza antes de `runApp`, la página queda en blanco, y el
healthcheck sigue devolviendo 200 porque nginx sirve el HTML perfectamente.

## Comprobaciones

Lo que se afirma en la matriz se puede repetir a mano:

```bash
# Red propia y no la bridge por defecto: el `resolver 127.0.0.11` del proxy
# /api solo existe en redes definidas por el usuario.
docker network create medicare
docker run -d --name front --network medicare -p 8080:8080 medicare-front

# RNF-09 — la primera sonda tarda hasta `start-period`, asi que se espera
until [ "$(docker inspect -f '{{.State.Health.Status}}' front)" = healthy ]; do sleep 2; done
curl -i http://localhost:8080/healthz

# RNF-05 — en el documento, en un asset y en una ruta del router
for r in / /main.dart.js /citas; do curl -sI "http://localhost:8080$r"; done

# RNF-05 — rate limit (desde dentro: por la red el cuello de botella es el cliente)
docker exec front sh -c 'i=0; while [ $i -lt 400 ]; do \
  wget -q -S -O /dev/null http://127.0.0.1:8080/manifest.json 2>&1 \
  | grep -oE "HTTP/1.1 [0-9]+"; i=$((i+1)); done' | sort | uniq -c
```

El job `imagen` del pipeline corre estas mismas comprobaciones y algunas mas
(que el servidor no anuncia su version, que CanvasKit se sirve local, y que el
proxy entrega la ruta con el prefijo /api). RNF-05
estuvo trece fases dado por cumplido porque las directivas estaban escritas en
`nginx.conf`; medidas, el documento HTML salía **sin ninguna** —en nginx
`add_header` no se hereda, y los `location` con cabecera propia descartaban
las del bloque `server`. Por eso lo que se verifica es la respuesta servida.

## Notas

- **CORS no se resuelve con una cabecera**, se resuelve con la topología.
  nginx proxea `/api` al backend, así que front y API comparten origen y no
  hay preflight. Es además lo que permite que la CSP diga `connect-src 'self'`
  sin meter el host del backend —que es un `--dart-define`— dentro de una
  cabecera. El `enableCors` del backend sigue pendiente
  ([BACKEND_ISSUES.md #2](../docs/BACKEND_ISSUES.md)).
- El build **no** es reproducible byte a byte. Fijar el SDK y el lockfile
  elimina el "en mi máquina sí compila", que es el problema real, pero
  `flutter build` incorpora marcas de tiempo y rutas: dos builds del mismo
  commit dan artefactos equivalentes, no idénticos. Afirmar lo contrario en
  una defensa es pedir que te lo desmientan.
- El firmado de release **no ocurre en el contenedor**. El keystore nunca
  entra a una imagen.
- `TZ: UTC` en db y api no es decorativo: si Postgres arranca en
  `America/Santo_Domingo`, los `TIMESTAMPTZ` se guardan bien pero cualquier
  `now()` de una migración sale corrido (RNF-18).
