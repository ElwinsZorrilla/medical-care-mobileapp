# Docker

## Qué se puede y qué no

**No se puede** meter una app Android en un contenedor y correrla. Un APK
necesita Android Runtime; Docker no lo provee. Cualquiera que diga
"dockericé mi app Flutter móvil" en realidad hizo una de estas dos cosas:

**Lo que sí hace este setup:**

1. **Build reproducible** — el SDK, las dependencias y los flags quedan fijados
   en la imagen. El APK que sale de tu máquina es byte a byte el mismo que sale
   de CI y el de tu compañero. Esto es lo que resuelve el "en mi máquina sí
   compila".
2. **Target web servido con nginx** — Flutter web corriendo en un contenedor,
   levantado junto al backend con compose. Sirve para la defensa del proyecto y
   para pruebas end-to-end sin emulador.

Eso cubre RNF-17 de verdad. Decir que se "contenerizó la app móvil" sin esta
distinción es lo que un jurado técnico va a picar en la presentación.

## Uso

```bash
# APK + AAB firmables → ./dist
docker build --target export -o ./dist \
  --build-arg API_BASE_URL=https://api.tu-dominio.do \
  --build-arg SOCKET_URL=wss://api.tu-dominio.do \
  -f docker/Dockerfile .

# Solo verificar (format + analyze + test), sin producir artefactos
docker build --target verify -f docker/Dockerfile .

# Front web + back + db + redis
docker compose -f docker/docker-compose.yml up --build
```

## Notas

- `--target verify` es la misma barra que el gate local. Si falla acá, falla el
  pipeline. No se saltea.
- El firmado de release **no ocurre en el contenedor**. El keystore nunca entra
  a una imagen. Se firma fuera, con las llaves en el secret store de CI.
- `TZ: UTC` en db y api no es decorativo: si el contenedor de Postgres arranca
  en `America/Santo_Domingo`, los `TIMESTAMPTZ` se guardan bien pero cualquier
  `now()` en una migración sale corrido. (RNF-18)
