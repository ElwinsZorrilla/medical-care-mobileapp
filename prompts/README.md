# Prompts por fase

Se pegan en Claude Code, uno por fase, en orden. Cada uno arranca el ciclo
completo de `LOOP.md`.

---

## Plantilla base

Todas las fases comparten este encabezado. Está acá una sola vez; los prompts
de abajo lo asumen.

```
CONTEXTO OBLIGATORIO — leer antes de escribir una línea:
  LOOP.md · docs/ARCHITECTURE.md · docs/DESIGN_SYSTEM.md
  docs/API_CONTRACT.md · docs/REVIEW_GATE.md

REGLAS INVARIANTES (LOOP.md §0):
  Cero atribución de IA. CLAUDE.md nunca se versiona. No tocar el backend.
  Sin APPROVED no hay commit. flutter analyze en cero. Nada en duro.
  Todo DateTime en UTC.

CICLO:
  1. PLAN    — lista de archivos, RF cubiertos, riesgos. PARÁ acá y mostrámelo.
  2. BUILD   — solo después de que yo apruebe el plan.
  3. VERIFY  — ./scripts/verify.sh
  4. GATE    — /code-reviewer-pro con docs/REVIEW_GATE.md → .review/verdict
  5. COMMIT  — solo con VERDICT: APPROVED
  6. LOG     — docs/TRACEABILITY.md + PROGRESS.md

Si el gate pide cambios: volvé a 2 con los hallazgos. A la 3ra vuelta, PARÁ
y decime qué hallazgo se repite — el problema es el diseño de la fase.
```

---

## F00 — Reconocimiento del contrato

```
[plantilla base]

FASE F00 — Verificar el contrato real del backend.

No escribas UI. No crees el proyecto Flutter todavía.

1. Levantá el back local (../medical-care-back) y sacá el OpenAPI a
   docs/openapi.json
2. Generá los DTOs con swagger_parser en lib/core/api/
3. Reescribí docs/API_CONTRACT.md con lo REAL, resolviendo cada ❓
4. Confirmá con curl estas cuatro, que son las que rompen todo si se asumen mal:
   a) Código HTTP cuando dos reservas piden el mismo turno (se espera 409)
   b) Si ?fecha=YYYY-MM-DD se interpreta en UTC o en America/Santo_Domingo
   c) Si /auth/refresh rota el refresh token o devuelve el mismo
   d) Transporte de realtime (Socket.IO vs WS) y cómo se autentica el handshake
5. Armá una colección Bruno en tools/api/ con los 6 flujos críticos

Si algo del back está mal (ej: no maneja concurrencia en reserva), NO lo
arregles. Abrí issue en el repo del back y anotalo en docs/BACKEND_ISSUES.md.

Salida: docs/API_CONTRACT.md sin un solo ❓.
```

---

## F01 — Fundación

```
[plantilla base]

FASE F01 — Esqueleto del proyecto. Cubre RNF-11, RNF-13, RNF-17.

1. flutter create con org com.unapec.medicare, plataformas android e ios
2. Estructura de carpetas exacta de docs/ARCHITECTURE.md
3. pubspec.yaml con las dependencias de ARCHITECTURE.md §Dependencias.
   Resolvé versiones reales y fijá pubspec.lock.
4. analysis_options.yaml ESTRICTO:
   - include: package:flutter_lints/flutter.yaml
   - strict-casts, strict-inference, strict-raw-types en true
   - custom_lint + riverpod_lint activos
   - prohibí avoid_print como error
5. lib/core/config/env.dart — API_BASE_URL y SOCKET_URL por
   String.fromEnvironment. Que falle al arrancar si vienen vacíos, no cuando
   se haga la primera petición.
6. scripts/verify.sh (LOOP.md §3), ejecutable
7. .gitignore y .githooks ya están. Corré: git config core.hooksPath .githooks

Salida: `flutter run` levanta pantalla en blanco, verify.sh en verde.
```

---

## F02 — Design System

```
[plantilla base]

FASE F02 — El sistema de diseño en código. Cubre RNF-16.

Los tokens y el theme ya están escritos en seed/. Copialos y seguí:

1. Copiá seed/lib/core/theme/ y seed/lib/core/time/ a lib/core/
2. Corré flutter analyze. Van a aparecer 2 o 3 desajustes de versión de API
   (ver docs/VERIFICATION.md). Arreglalos, no los silencies con ignore.
3. Construí lib/core/widgets/ — 12 componentes, todos derivados de tokens:
   StatusRail · DataField · AppCard · AppButton · AppTextField
   EmptyState · ErrorState · LoadingSkeleton · OfflineBanner
   AppScaffold · SectionHeader · Avatar
4. Densidad: AppDensity se resuelve por el rol del usuario. Paciente →
   patient, médico → clinician.
5. Pantalla de galería en lib/dev/gallery.dart — todos los componentes, los 5
   estados de cita, ambas densidades, claro y oscuro. Es la herramienta de
   revisión visual, no va a producción.
6. Goldens del StatusRail: 5 estados × 2 densidades × 2 temas = 20.

DISCIPLINA (el gate lo revisa): cero Color(0xFF...), cero EdgeInsets con
números sueltos, cero TextStyle inline. Todo sale de AppColors / Space /
context.text. Un literal en un widget es rechazo directo.

Salida: la galería corre y se ve como describe docs/DESIGN_SYSTEM.md §6.
```

---

## F03 — Capa de red

```
[plantilla base]

FASE F03 — Red y seguridad. Cubre RNF-01..05, RNF-16.

1. lib/core/network/dio_client.dart — baseUrl de Env, timeouts 15s
2. auth_interceptor.dart — inyecta Bearer desde SecureStore
3. refresh_interceptor.dart — SINGLE-FLIGHT. Esto es lo crítico:
   - Completer<String>? compartido, NO un bool
   - N peticiones con 401 en paralelo → UN solo refresh
   - las demás esperan ese mismo Future y reintentan con el token nuevo
   - el endpoint /auth/refresh NUNCA se reintenta a sí mismo
   - si el refresh da 401 → limpiar sesión y mandar a login
4. Result<T> + jerarquía sealed de Failure (ARCHITECTURE.md §Errores).
   Mensajes en español, desde el lado del usuario.
5. Mapeo DioException → Failure. Que 409 caiga en Conflicto: RF-20 depende.
6. SecureStore sobre flutter_secure_storage. Tokens JAMÁS en SharedPreferences.
7. Interceptor de logging que REDACTE Authorization, password y cualquier
   campo clínico. Solo en debug.

PRUEBAS OBLIGATORIAS:
  - 5 peticiones concurrentes con 401 disparan exactamente 1 refresh
  - refresh que falla limpia la sesión
  - cada código HTTP mapea al Failure correcto

Salida: verify.sh verde con esas pruebas pasando.
```

---

## F04 a F12 — Features

Todas siguen la misma forma. Sustituí `{…}`:

```
[plantilla base]

FASE {FXX} — {nombre}. Cubre {RF-aa..RF-bb}.

1. domain/  — entidades y casos de uso. Sin json, sin dio, sin Flutter.
2. data/    — DTO freezed desde el contrato REAL de F00, api, repositorio.
              El repositorio traduce DTO→entidad y DioException→Failure.
3. presentation/ — providers Riverpod, pantallas, widgets.
              Los 4 estados en cada pantalla: cargando, vacío, error, offline.
4. Pruebas: camino feliz + al menos un error por caso de uso.
            Widget test por pantalla con condicionales.
5. Trazabilidad: una fila por RF en docs/TRACEABILITY.md.

Solo tokens del design system. Copia según DESIGN_SYSTEM.md §8.
```

**Notas por fase — lo que cada una tiene de particular:**

| Fase | Lo que hay que cuidar |
|---|---|
| **F04** Auth | El guard de go_router redirige por rol (RF-06). Estado de sesión: `desconocido / autenticado / anónimo`. Los tres, o parpadea el login al arrancar. |
| **F05** Perfiles | El ID sale del token, nunca de un form (RF-09). Editar solo el propio (RF-10). Estado de verificación del médico visible y explicado (RF-11). |
| **F06** Búsqueda | Paginación real con scroll infinito (RF-15). Debounce de 300ms en el buscador. |
| **F07** Agenda | Todo el cálculo de turnos en UTC; se pinta local. La grilla de turnos es la pantalla más propensa al bug de zona horaria. |
| **F08** Citas | **El 409 (RF-20) es la lógica central.** Al recibirlo: refrescar grilla + mensaje llano. Nunca reintentar en silencio. Confirmación de cancelación con motivo (RF-22). |
| **F09** Historial | Solo paciente titular y médico tratante (RNF-06). Datos clínicos con tipografía `data`, contraste AAA. |
| **F10** Notificaciones | Push + bandeja in-app. Deep link a la cita. Probar en device físico, el emulador miente con background. |
| **F11** Chat | Reconexión con backoff exponencial. Cola de mensajes offline. Adjuntos con límite de tamaño y tipos permitidos (RF-34). |
| **F12** Video | Detrás de una interfaz `VideoProvider` (RNF-19). Permisos de cámara y micrófono con explicación antes del prompt del sistema. Device físico obligatorio. |

---

## F13 — Endurecimiento

```
[plantilla base]

FASE F13 — Cubre RNF-06..10, RNF-14, RNF-18.

1. AUDITORÍA DE ZONA HORARIA: buscá en todo el repo `DateTime.now()`,
   `.toLocal()` y `DateTime.parse` sin `.toUtc()`. Cada aparición se justifica
   o se corrige. Agregá una prueba que falle si un DateTime local se serializa.
2. ACCESIBILIDAD: correr con textScale 2.0 y arreglar recortes. Semantics en
   todo ícono que actúe solo. Foco visible. Contraste AA/AAA.
3. RENDIMIENTO: const donde corresponda, ListView.builder en todo listado,
   cached_network_image, perfil de jank en la agenda del médico con 50 citas.
4. OFFLINE: banner global, cola de reintentos, caché de lo último visto.
5. COBERTURA a 80% global. Los huecos que queden se justifican por escrito.
6. i18n: cero strings hardcodeados en widgets, todo por ARB.

Salida: reporte docs/HARDENING.md con antes/después medible.
```

---

## F14 — Docker y CI

```
[plantilla base]

FASE F14 — Cubre RNF-17.

1. Copiá docker/ del paquete del loop
2. Verificá que `docker build --target verify` pase
3. Verificá que `docker compose up` levante front web + back + db + redis y
   que se pueda hacer login desde el navegador
4. .github/workflows/ci.yml: verify en cada PR, artifacts en tag
5. README.md del repo: instalación, arranque, arquitectura, cómo correr
   pruebas, cómo levantar con Docker.
   SIN mencionar herramientas de IA en ninguna línea.

Salida: compose levanta el sistema completo y el flujo de login funciona en
el navegador contra el back real.
```

---

## F15 — Cierre

```
[plantilla base]

FASE F15 — Revisión final de todo el proyecto.

1. /code-reviewer-pro sobre el diff COMPLETO (main...HEAD desde el inicio),
   no solo la última fase
2. docs/TRACEABILITY.md completo: los 37 RF y 19 RNF con su evidencia
3. Cualquier RF sin cubrir se documenta explícito con su razón. Un requisito
   faltante declarado vale más que uno faltante escondido.
4. Barrido final: ningún rastro de IA en código, commits, docs o README
5. Tag v1.0.0

Salida: matriz completa y APPROVED sobre el proyecto entero.
```
