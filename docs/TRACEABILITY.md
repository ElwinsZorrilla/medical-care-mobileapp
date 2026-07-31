# Matriz de trazabilidad

Se llena al cerrar cada fase (LOOP.md §0 R8). Es lo que un jurado pide para
comprobar que los 37 RF están cubiertos, y lo que a vos te dice qué falta.

**Leyenda:** ⬜ pendiente · ✅ cubierto · ⚠️ parcial (con razón) · ⛔ sin backend

> **Tras F00 (2026-07-30).** El contrato quedó verificado contra el backend real
> y aparecieron huecos del lado servidor que ninguna cantidad de trabajo en el
> front cierra. **10 de 37 RF no tienen API** (RF-28..RF-37) y otros 3 quedan
> parciales. Detalle y opciones en [`BACKEND_ISSUES.md`](BACKEND_ISSUES.md).
>
> Un requisito faltante **declarado** vale más que uno faltante escondido: por
> eso están marcados acá y no en blanco.

## Requerimientos funcionales

| RF | Descripción corta | Fase | Pantalla / módulo | Prueba | Estado |
|---|---|---|---|---|---|
| RF-01 | Registro con rol | F04 | `auth/registro` | | ⬜ |
| RF-02 | Correo único y válido | F04 | `auth/registro` | | ⬜ |
| RF-03 | Login → JWT | F04 | `auth/login` | | ⬜ |
| RF-04 | Refresh token | F03 | `refresh_interceptor` | | ⬜ |
| RF-05 | Logout invalida refresh | F04 | `auth/repository` | | ⚠️ no hay `/auth/logout` ni revocación; solo borrado local ([#3](BACKEND_ISSUES.md)) |
| RF-06 | Acceso por rol | F04 | `router/guards` | | ⬜ |
| RF-07 | Perfil paciente | F05 | `perfil/paciente` | | ⬜ |
| RF-08 | Perfil médico | F05 | `perfil/medico` | | ⬜ |
| RF-09 | ID desde el token | F05 | `perfil/repository` | | ⬜ |
| RF-10 | Editar solo el propio | F05 | `perfil/guards` | | ⬜ |
| RF-11 | Estado de verificación | F05 | `perfil/medico` | | ⬜ |
| RF-12 | Catálogo especialidades | F06 | `especialidades` | | ⬜ |
| RF-13 | Médico ↔ especialidad | F06 | `especialidades` | | ⬜ |
| RF-14 | Filtrar por especialidad | F06 | `busqueda` | | ⚠️ filtro por especialidad sí; búsqueda por texto no existe ([#8](BACKEND_ISSUES.md)) |
| RF-15 | Listados paginados | F06 | `busqueda` | | ⬜ |
| RF-16 | Definir franjas | F07 | `agenda/disponibilidad` | | ⬜ |
| RF-17 | Activar/desactivar franja | F07 | `agenda/disponibilidad` | | ⬜ |
| RF-18 | Turnos libres por fecha | F07 | `agenda/turnos` | | ⬜ |
| RF-19 | Reservar cita | F08 | `citas/reservar` | | ⬜ |
| RF-20 | **Control de concurrencia** | F08 | `citas/repository` | | ⬜ |
| RF-21 | Motivo de consulta | F08 | `citas/reservar` | | ⬜ |
| RF-22 | Cancelar con motivo | F08 | `citas/cancelar` | | ⬜ |
| RF-23 | Estados de cita | F02+F08 | `core/domain/cita_estado.dart`, `core/widgets/status_rail.dart` | `cita_estado_test.dart` (12) + 20 goldens | ⚠️ Los 5 estados mapeados, pintados y con golden. `CONFIRMADA` y `NO_ASISTIO` son inalcanzables: no hay endpoint de transición ([#4](BACKEND_ISSUES.md)) |
| RF-24 | Mis citas / mi agenda | F08 | `citas/lista` | | ⬜ |
| RF-25 | Registrar consulta | F09 | `historial/consulta` | | ⬜ |
| RF-26 | Emitir recetas | F09 | `historial/receta` | | ⬜ |
| RF-27 | Ver historial | F09 | `historial/paciente` | | ⬜ |
| RF-28 | Notificar eventos | F10 | `notificaciones` | | ⛔ |
| RF-29 | Recordatorios 24h/1h | F10 | `notificaciones/push` | | ⛔ |
| RF-30 | Marcar leída | F10 | `notificaciones/bandeja` | | ⛔ |
| RF-31 | Conversación | F11 | `chat/conversacion` | | ⛔ |
| RF-32 | Mensajes en tiempo real | F11 | `chat/socket` | | ⛔ |
| RF-33 | Estado de lectura | F11 | `chat/mensaje` | | ⛔ |
| RF-34 | Adjuntar archivos | F11 | `chat/adjuntos` | | ⛔ |
| RF-35 | Sesión de videollamada | F12 | `video/sala` | | ⛔ |
| RF-36 | Enlace de sala | F12 | `video/repository` | | ⛔ |
| RF-37 | Estado de videollamada | F12 | `video/estado` | | ⛔ |

**RF-28..RF-37 — ⛔ sin backend.** Las tres áreas tienen tabla y entidad
TypeORM, pero cero endpoints: no hay controller, service ni módulo registrado
en `app.module.ts`, y no existe transporte de tiempo real, proveedor de push ni
de video. **F10, F11 y F12 no tienen contra qué construirse.** La decisión
(implementarlo en el back / recortar alcance / mockear declarándolo) está
planteada en [`BACKEND_ISSUES.md` #5](BACKEND_ISSUES.md) y no le corresponde
tomarla al front en solitario.

## Requerimientos no funcionales

| RNF | Descripción corta | Fase | Evidencia | Estado |
|---|---|---|---|---|
| RNF-01 | Contraseñas cifradas | — | Responsabilidad del back. El front solo verifica que nunca vuelva en la respuesta. | ⬜ |
| RNF-02 | JWT + guards de rol | F03,F04 | | ⬜ |
| RNF-03 | Refresh cifrado en reposo | F03 | `flutter_secure_storage` | ⬜ |
| RNF-04 | Sin secretos en código | F01 | `core/config/env.dart` (`String.fromEnvironment`, valida al arrancar) + hook pre-commit · 6 pruebas | ✅ |
| RNF-05 | Cabeceras, CORS, rate limit | F14 | `nginx.conf` | ⬜ |
| RNF-06 | Historial restringido | F09 | | ⬜ |
| RNF-07 | Listados con paginación | F06 | | ⬜ |
| RNF-08 | Notificaciones asíncronas | — | Back | ⬜ |
| RNF-09 | Healthcheck | F14 | `/healthz` | ⬜ |
| RNF-10 | Concurrencia sin duplicar | F08 | Manejo de 409 | ⬜ |
| RNF-11 | Arquitectura modular | F01 | `lib/core/{config,router}` creado; `lib/features/` se puebla por fase (F04+). La modularidad se demuestra cuando haya más de un módulo. | ⚠️ |
| RNF-12 | Migraciones versionadas | — | Back | ⬜ |
| RNF-13 | Tipado estricto + linter | F01 | `analysis_options.yaml` (strict-casts/inference/raw-types, custom_lint, `avoid_print: error`) · `flutter analyze --fatal-infos` en cero | ✅ |
| RNF-14 | Pruebas por módulo | todas | Cobertura ≥ 80% | ⬜ |
| RNF-15 | Swagger | F00 | `docs/openapi.json` — 29 endpoints, extraído de `/docs-json` | ✅ |
| RNF-16 | Errores claros y uniformes | F03 | Jerarquía `Failure` | ⬜ |
| RNF-17 | Docker | F14 | `FLUTTER_VERSION` alineado a 3.44.5 en F01; falta verificar el build | ⬜ |
| RNF-18 | **UTC ↔ America/Santo_Domingo** | F13 | `AppTime` + auditoría | ⬜ |
| RNF-19 | Escalable a nuevos proveedores | F12 | Interfaz `VideoProvider` | ⬜ |

Cinco RNF son del backend, no del front. Están listados igual porque el jurado
va a preguntar por los 19 y la respuesta correcta es "ese se cumple del lado
servidor", no una fila en blanco.
