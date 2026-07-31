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
| RF-01 | Registro con rol | F04 | `features/auth/.../registro_screen.dart` | `pantallas_auth_test.dart`, `auth_repository_test.dart` | ✅ |
| RF-02 | Correo único y válido | F04 | Validación local + 409 del backend | prueba de 409 con mensaje accionable | ✅ |
| RF-03 | Login → JWT | F04 | `login_screen.dart` + `AuthRepository.iniciarSesion` | camino feliz + 401 + sin conexión | ✅ |
| RF-04 | Refresh token | F03 | `core/network/refresh_interceptor.dart` | `refresh_interceptor_test.dart` — 5 peticiones concurrentes con 401 disparan **1** refresh | ✅ |
| RF-05 | Logout invalida refresh | F04 | `auth/repository` | | ⚠️ no hay `/auth/logout` ni revocación; solo borrado local ([#3](BACKEND_ISSUES.md)) |
| RF-06 | Acceso por rol | F04 | `core/router/app_router.dart` — `redirect` con los 3 estados de sesión | `router_guard_test.dart` (9) | ✅ |
| RF-07 | Perfil paciente | F05 | `features/perfil/.../perfil_screen.dart` | `perfil_repository_test.dart`, `perfil_screen_test.dart` | ✅ |
| RF-08 | Perfil médico | F05 | misma pantalla, resuelta por rol del token | mapeo de especialidades y tarifa | ✅ |
| RF-09 | ID desde el token | F05 | `PerfilApi` usa `/patients/me` y `/doctors/me`; ninguna ruta recibe id del cliente | ✅ |
| RF-10 | Editar solo el propio | F05 | PATCH sin id para paciente; 403 del backend para médico ajeno | prueba de 403 + PATCH sin campos no editables | ✅ |
| RF-11 | Estado de verificación | F05 | `BadgeVerificacion` — color + glifo + etiqueta + **explicación** de qué implica | 3 estados con prueba de widget | ✅ |
| RF-12 | Catálogo especialidades | F06 | `busqueda` — filtro horizontal con las 10 sembradas | `busqueda_repository_test.dart` | ✅ |
| RF-13 | Médico ↔ especialidad | F06 | Especialidades anidadas en cada médico del listado | prueba de `especialidadesTexto` | ✅ |
| RF-14 | Filtrar por especialidad | F06 | `FiltroEspecialidad` + `?especialidadId=` | prueba de que el filtro viaja | ⚠️ el filtro por especialidad funciona; **búsqueda por texto no existe en el backend** ([#8](BACKEND_ISSUES.md)) |
| RF-15 | Listados paginados | F06 | `core/domain/pagina.dart` + scroll infinito con precarga | `pagina_test.dart` (16) — incluye el caso de última página exactamente llena | ✅ |
| RF-16 | Definir franjas | F07 | `features/agenda/.../disponibilidad_screen.dart` | `agenda_repository_test.dart` (26), `disponibilidad_screen_test.dart` (13) | ✅ |
| RF-17 | Activar/desactivar franja | F07 | Desactivar con confirmación; el backend no ofrece reactivar | prueba de confirmar y de cancelar | ⚠️ solo desactivar: `PATCH /desactivar` es de una sola dirección |
| RF-18 | Turnos libres por fecha | F07 | `AgendaRepository.turnos` resuelve `?fecha=` en calendario dominicano | prueba de que 01:00Z del 18 pide el 17 | ✅ |
| RF-19 | Reservar cita | F08 | `CitasRepository.reservar`; manda `fecha` y el ISO exacto del turno | `citas_repository_test.dart` (20) | ✅ |
| RF-20 | **Control de concurrencia** | F08 | `ReaccionAConflicto.para` clasifica el 409 sobrecargado; nunca reintenta en silencio | 6 pruebas: turno tomado, carrera perdida, modalidad, 400 de franja, conflicto desconocido, sin conexión | ✅ |
| RF-21 | Motivo de consulta | F08 | `motivoConsulta` opcional en la reserva, visible en la tarjeta | prueba de ida y vuelta | ✅ |
| RF-22 | Cancelar con motivo | F08 | Diálogo con motivo obligatorio; 403 y 409 con mensaje propio | 4 pruebas de widget + 3 de repositorio | ✅ |
| RF-23 | Estados de cita | F02+F08 | `core/domain/cita_estado.dart`, `core/widgets/status_rail.dart` | `cita_estado_test.dart` (12) + 20 goldens | ⚠️ Los 5 estados mapeados, pintados y con golden. `CONFIRMADA` y `NO_ASISTIO` son inalcanzables: no hay endpoint de transición ([#4](BACKEND_ISSUES.md)) |
| RF-24 | Mis citas / mi agenda | F08 | Una pantalla, dos rutas según rol; scroll infinito y caché de médicos | pruebas de los 4 estados y de ambos roles | ✅ |
| RF-25 | Registrar consulta | F09 | `HistorialRepository.registrar`; `SignosVitales` impone forma al `jsonb` libre | `historial_test.dart` (21) | ✅ |
| RF-26 | Emitir recetas | F09 | Van en la misma llamada que la consulta, no aparte | prueba de que viajan juntas | ✅ |
| RF-27 | Ver historial | F09 | `historial_screen.dart`, ruta elegida por rol | `historial_screen_test.dart` (11) | ✅ |
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
| RNF-02 | JWT + guards de rol | F03,F04 | `auth_interceptor.dart` inyecta el Bearer · `redirect` del router bloquea el área ajena por rol | ✅ |
| RNF-03 | Refresh cifrado en reposo | F03 | `core/storage/secure_store.dart` sobre `flutter_secure_storage` (Keystore / Keychain). Nunca `SharedPreferences` | ✅ |
| RNF-04 | Sin secretos en código | F01 | `core/config/env.dart` (`String.fromEnvironment`, valida al arrancar) + hook pre-commit · 6 pruebas | ✅ |
| RNF-05 | Cabeceras, CORS, rate limit | F14 | `docker/security-headers.conf` (nosniff, DENY, Referrer-Policy, Permissions-Policy, CSP) + `limit_req` a 30 r/s con ráfaga 100, y `server_tokens off`. **CORS se elimina por topología**: nginx proxea `/api` al backend, mismo origen, sin preflight. Medido con `curl` sobre el contenedor, no leído del archivo — el job `imagen` del CI repite las comprobaciones | ✅ |
| RNF-06 | Historial restringido | F09 | **No hay parámetro de paciente**: la ruta la elige el rol de la sesión, así que el acceso cruzado no se puede expresar. El backend además filtra por token | ✅ |
| RNF-07 | Listados con paginación | F06 | `Pagina<T>` calcula `totalPaginas` porque el backend no manda `lastPage`; límite recortado a 50 en el repositorio | ✅ |
| RNF-08 | Notificaciones asíncronas | — | Back | ⬜ |
| RNF-09 | Healthcheck | F14 | `/healthz` responde `ok` y devuelve 503 si falta el build. `HEALTHCHECK` del contenedor verificado en `healthy` — usaba `localhost`, que resuelve a ::1, y quedaba `unhealthy` para siempre | ✅ |
| RNF-10 | Concurrencia sin duplicar | F08 | El backend lo garantiza (bloqueo pesimista + índice único, verificado en F00 con carrera real). El front refresca la grilla y avisa; **nunca reintenta en silencio** | ✅ |
| RNF-11 | Arquitectura modular | F01,F04,F05,F13 | Seis módulos con las tres capas; lo compartido de dominio (`Especialidad`, `TipoUsuario`, `FechaCalendario`, `PerfilMedico`) subió a `core/`. **Corregido en F13:** esta fila decía "ninguno importa del otro" y era falso — cinco features importan `dioClienteProvider` y `sesionActualProvider` desde `features/auth/presentation/` (7 archivos). `test/arquitectura_test.dart` vuelve la regla ejecutable y lleva el registro; el rediseño de dónde vive la sesión queda pendiente. Ver `HARDENING.md` §7.b | ⚠️ |
| RNF-12 | Migraciones versionadas | — | Back | ⬜ |
| RNF-13 | Tipado estricto + linter | F01 | `analysis_options.yaml` (strict-casts/inference/raw-types, custom_lint, `avoid_print: error`) · `flutter analyze --fatal-infos` en cero | ✅ |
| RNF-14 | Pruebas por módulo | todas,F13 | **86.0 %** de línea (2297/2672), 445 pruebas, excluyendo código generado. Ver `docs/HARDENING.md` | ✅ |
| RNF-15 | Swagger | F00 | `docs/openapi.json` — 29 endpoints, extraído de `/docs-json` | ✅ |
| RNF-16 | Errores claros y uniformes | F03 | Jerarquía sellada `Failure` + `FailureMapper`; 21 pruebas de mapeo HTTP→dominio | ✅ |
| RNF-17 | Docker | F14 | `docker build --target verify` termina en 0: **445 pruebas, cobertura 86.0 %** dentro del contenedor. Targets `verify`, `goldens` y `web`; `artifacts`/`export` eliminados porque nunca compilaron (sin SDK de Android). El APK se compila en el job `apk` del CI | ✅ |
| RNF-18 | **UTC ↔ America/Santo_Domingo** | F13 | `core/time/app_time.dart` es el único borde de conversión; desfase fijo −4 h para coincidir con el backend (ADR-005). `test/core/time/disciplina_utc_test.dart` recorre `lib/` y falla ante `DateTime.now()` o formateo fuera de `AppTime` — 24 pruebas, comprobada falsificable | ✅ |
| RNF-19 | Escalable a nuevos proveedores | F12 | Interfaz `VideoProvider` | ⬜ |

Cinco RNF son del backend, no del front. Están listados igual porque el jurado
va a preguntar por los 19 y la respuesta correcta es "ese se cumple del lado
servidor", no una fila en blanco.
