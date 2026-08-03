# MediCare — app móvil

Cliente Flutter para agenda médica, historia clínica y consultas. Habla con un
backend NestJS que vive en otro repositorio.

```
MedicalCare/
├── back/    ← API NestJS + PostgreSQL (repo aparte)
└── front/   ← este repositorio
```

## Arrancar

Necesitas **Flutter 3.44.5** (la versión está fijada; otra puede compilar y
comportarse distinto).

```bash
flutter pub get
dart run build_runner build          # genera *.g.dart y *.freezed.dart
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api
```

`API_BASE_URL` **es obligatoria y no tiene valor por defecto**. La app valida
al arrancar y falla ruidosamente si falta: un error de configuración tiene que
verse como error de configuración, no como una pantalla en blanco (RNF-04).

- Emulador Android → `http://10.0.2.2:3000/api`
- Dispositivo físico → la IP de tu máquina en la red local
- El sufijo `/api` es obligatorio: el backend monta todo bajo ese prefijo.

Nada de URLs, llaves ni identificadores en el código. Todo entra por
`--dart-define` (ver `lib/core/config/env.dart`).

## La barra de calidad

```bash
./scripts/verify.sh
```

Formato, codegen, `flutter analyze --fatal-infos`, pruebas y umbral de
cobertura, en ese orden y todo o nada. Es la misma barra que corre en CI y
dentro del contenedor; si falla acá, falla en los tres sitios.

```bash
git config core.hooksPath .githooks   # una vez, al clonar
```

Los hooks bloquean el commit si se cuela un secreto, un archivo que no se
versiona, o si la revisión de código no está aprobada y vigente. Un `push`
los saltea, así que `.github/workflows/ci.yml` replica lo mismo.

## Docker y web

```bash
docker build --target verify -f docker/Dockerfile .        # la barra, aislada
docker compose -f docker/docker-compose.yml up --build     # front web en :8080
```

Detalle completo en [`docker/README.md`](docker/README.md), incluido por qué
el APK **no** se compila en el contenedor y cómo se regeneran los goldens.

## Estado

De los **37 requerimientos funcionales**: 32 completos y 5 parciales con su
razón escrita. Ninguno queda sin implementar.

Los 10 que en F00 quedaron sin backend —notificaciones, chat y videollamada—
ya tienen API y están construidos contra el servidor real, sin un solo mock de
endpoint. El Swagger pasó de 29 rutas a **38**.

**Los 5 parciales son huecos del lado servidor**, no trabajo pendiente del
front. En los cinco, la mitad que el backend soporta está construida y
probada; la otra mitad no tiene contra qué construirse:

| RF | Lo que hay | Lo que falta del servidor |
|---|---|---|
| RF-05 | El token se borra localmente al salir | No existe `/auth/logout` ni revocación: el refresh sigue siendo válido |
| RF-14 | Filtro por especialidad, con debounce | `GET /doctors` no acepta `q` ni `nombre` ([#8](docs/BACKEND_ISSUES.md)) |
| RF-17 | Desactivar una franja, con confirmación | `PATCH /desactivar` es de una sola dirección: no hay cómo reactivarla |
| RF-23 | Los 5 estados mapeados, pintados y con golden | `CONFIRMADA` y `NO_ASISTIO` son inalcanzables: no hay endpoint de transición ([#4](docs/BACKEND_ISSUES.md)) |
| RF-34 | El adjunto viaja, vuelve y se pinta | No hay **ninguna** ruta que reciba un archivo ([#9](docs/BACKEND_ISSUES.md)) |

En RF-14 y RF-34 se decidió **no** ofrecer la mitad que no funciona: ni un
buscador por nombre que filtre solo la página cargada, ni un selector de
archivos que no puede subir nada. Un control que promete algo que no ocurre es
peor que su ausencia — el usuario culpa a su conexión.

De los **19 no funcionales**: 15 completos, 2 parciales y 2 que son
responsabilidad del backend (RNF-01 cifrado de contraseñas, RNF-12 migraciones
versionadas).

La matriz completa —qué cubre cada requerimiento, con qué archivo y con qué
prueba— está en [`docs/TRACEABILITY.md`](docs/TRACEABILITY.md). Los huecos del
lado servidor, en [`docs/BACKEND_ISSUES.md`](docs/BACKEND_ISSUES.md).

| | |
|---|---|
| Cobertura de línea | 83.4 % (excluyendo código generado) |
| Pruebas | 618 (614 + 4 goldens que solo corren en Linux) |
| `flutter analyze --fatal-infos` | 0 |

## Documentación

| Archivo | Para qué |
|---|---|
| [`ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Capas, reglas de dependencia y por qué |
| [`API_CONTRACT.md`](docs/API_CONTRACT.md) | El contrato **verificado** contra el backend real, no inferido |
| [`BACKEND_ISSUES.md`](docs/BACKEND_ISSUES.md) | Lo que falta o está roto del lado servidor |
| [`DESIGN_SYSTEM.md`](docs/DESIGN_SYSTEM.md) | Tokens, densidades y reglas de interfaz |
| [`TRACEABILITY.md`](docs/TRACEABILITY.md) | RF/RNF ↔ código ↔ prueba |
| [`HARDENING.md`](docs/HARDENING.md) | Qué se endureció y qué se midió |
| [`REVIEW_GATE.md`](docs/REVIEW_GATE.md) | El rubro con el que se revisa cada fase |
| [`VERIFICATION.md`](docs/VERIFICATION.md) | Cómo comprobar a mano lo que se afirma |

## Dos decisiones que sorprenden

**Las fechas viajan siempre en UTC** y se convierten en un solo sitio
(`core/time/app_time.dart`), con un desfase **fijo de −4 h** en vez de la zona
IANA. Es deliberado: coincide con el backend, que hace lo mismo. Usar la zona
real haría que los dos discreparan si alguna vez vuelve el horario de verano.
Hay una prueba que recorre el código fuente y falla si alguien mete un
`DateTime.now()` suelto.

**Los goldens solo corren en Linux.** Un golden es un rasterizado y no es
idéntico bit a bit entre sistemas: los generados en Windows fallan en el
contenedor por 66 píxeles de antialiasing sin que nada esté roto. Linux es la
plataforma canónica —donde corre el CI— y fuera de ahí se saltan diciendo por
qué. Se regeneran con `docker build --target goldens`.
