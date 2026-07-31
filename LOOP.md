# MediCare Mobile — Loop de ingeniería

Ciclo de desarrollo con puertas de calidad para construir el frontend Flutter
completo (37 RF / 19 RNF) contra el backend existente.

**Regla dura del proyecto:** ningún commit entra al repo sin un `APPROVED` del
revisor. El gate es mecánico, no de buena fe: hay un hook que lo bloquea.

---

## 0. Reglas invariantes

Aplican en TODAS las fases. Violación = fase rechazada, sin discusión.

| # | Regla |
|---|---|
| R1 | **Cero atribución de autoría.** Ningún `Co-Authored-By`, ningún emoji de bot, ninguna mención a herramientas de IA en código, comentarios, commits, README o docs. |
| R2 | **`CLAUDE.md`, `.claude/`, `.mcp.json` jamás se versionan.** Están en `.gitignore` y en el hook de pre-commit. |
| R3 | **El backend no se toca.** Excepción única: bug que bloquea el front. En ese caso se abre issue en el repo del back, no se commitea desde acá. |
| R4 | **No se commitea sin `APPROVED`.** Ver §4. |
| R5 | **`flutter analyze` en cero.** Cero warnings, cero infos. No se baja la barra del linter para pasar. |
| R6 | **Nada de datos quemados.** Ni URLs, ni llaves, ni IDs. Todo por `--dart-define`. |
| R7 | **Toda fecha viaja en UTC.** Se convierte a `America/Santo_Domingo` solo al pintar. (RNF-18) |
| R8 | Cada fase cierra con su fila de trazabilidad actualizada en `docs/TRACEABILITY.md`. |

---

## 1. El loop

Cada fase corre este ciclo. No se salta ningún paso.

```
        ┌──────────────────────────────────────────────────┐
        │                                                  │
        ▼                                                  │
  ①  CONTEXTO   lee ARCHITECTURE + DESIGN_SYSTEM +         │
                API_CONTRACT + el prompt de la fase        │
        │                                                  │
        ▼                                                  │
  ②  PLAN       lista de archivos a tocar, RF que cubre,   │
                riesgos. NO escribe código todavía.        │
        │         ── revisión humana rápida (2 min) ──     │
        ▼                                                  │
  ③  BUILD      implementa exactamente lo planeado         │
        │                                                  │
        ▼                                                  │
  ④  VERIFY     format · analyze · build_runner · test     │
        │         ¿falla? ─────────────────────────────────┤
        ▼                                                  │
  ⑤  GATE       /code-reviewer-pro                         │
        │         ¿CHANGES_REQUESTED? ────────────────────►┤ (máx 3 vueltas)
        │                                                  │
        ▼  APPROVED                                        │
  ⑥  COMMIT     commit limpio + push                       │
        │                                                  │
        ▼                                                  │
  ⑦  LOG        PROGRESS.md + TRACEABILITY.md              │
        │                                                  │
        └──► siguiente fase
```

**Corte por bucle infinito:** si una fase llega a la 3ra vuelta de
`CHANGES_REQUESTED`, se detiene. No se sigue parchando. Se para, se lee el
hallazgo repetido, y se decide si el problema está en el diseño de la fase, no
en la implementación. Escalar a humano.

---

## 2. Fases

Orden no negociable — cada una depende de la anterior.

| Fase | Nombre | Cubre | Sale con |
|---|---|---|---|
| **F00** | Reconocimiento del contrato | — | `API_CONTRACT.md` verificado contra Swagger real |
| **F01** | Fundación | RNF-11,13,17 | Proyecto, carpetas, DI, env, router, analysis_options |
| **F02** | Design System | RNF-15,16 | Tokens, theme, tipografía, 12 componentes base + galería |
| **F03** | Capa de red | RNF-01..05,16 | Dio, interceptores, refresh single-flight, mapeo de errores |
| **F04** | Autenticación | RF-01..06 | Registro, login, refresh, logout, guard por rol |
| **F05** | Perfiles | RF-07..11 | Perfil paciente, perfil médico, estado de verificación |
| **F06** | Especialidades y búsqueda | RF-12..15 | Catálogo, filtro, listado paginado |
| **F07** | Disponibilidad | RF-16..18 | Franjas del médico, cálculo de turnos libres |
| **F08** | Citas | RF-19..24 | Reserva, concurrencia, cancelación, estados, agenda |
| **F09** | Historial clínico | RF-25..27 | Consulta, signos vitales, recetas, historial paciente |
| **F10** | Notificaciones | RF-28..30 | Bandeja, push, marcar leída |
| **F11** | Chat | RF-31..34 | Conversación, tiempo real, lectura, adjuntos |
| **F12** | Videollamada | RF-35..37 | Sala, enlace, estados |
| **F13** | Endurecimiento | RNF-06..10,14,18 | Zona horaria, a11y, perf, cobertura de pruebas |
| **F14** | Docker + CI | RNF-17 | Build reproducible, compose e2e, pipeline |
| **F15** | Cierre | todos | Review final, matriz completa, tag `v1.0.0` |

**F00 es obligatoria y va primera.** El repo del back es privado; el contrato de
API en `docs/API_CONTRACT.md` está **inferido de los requerimientos, no leído**.
Construir sobre un contrato no verificado es la forma más cara de perder una
semana. F00 lo confirma contra el Swagger real (RNF-15 garantiza que existe).

---

## 3. Paso ④ VERIFY — comandos exactos

Un solo comando, todo o nada. Guardar como `scripts/verify.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

dart format --set-exit-if-changed lib test
dart run build_runner build --delete-conflicting-outputs
flutter analyze --fatal-infos --fatal-warnings
flutter test --coverage

# Cobertura mínima por fase
pct=$(lcov --summary coverage/lcov.info 2>&1 | grep -oP 'lines\.*: \K[0-9.]+')
awk -v p="$pct" 'BEGIN { exit (p >= 70) ? 0 : 1 }' \
  || { echo "FALLA: cobertura ${pct}% < 70%"; exit 1; }

echo "VERIFY OK"
```

Si `verify.sh` no sale en 0, **no se pasa al gate**. Se vuelve a ③.

---

## 4. Paso ⑤ GATE — la puerta de revisión

Ver `docs/REVIEW_GATE.md` para el rubro completo y el formato de salida.

**Invocación:**

```
/code-reviewer-pro

Alcance: fase {FXX} — {nombre}
Diff: git diff --stat main...HEAD
Requerimientos cubiertos: {RF-xx..RF-yy}
Rubro: docs/REVIEW_GATE.md
Contrato: docs/API_CONTRACT.md
Diseño: docs/DESIGN_SYSTEM.md

Emite veredicto en la última línea, exactamente:
VERDICT: APPROVED
o
VERDICT: CHANGES_REQUESTED
```

**Enforcement mecánico.** El veredicto se escribe a `.review/verdict` y el hook
`pre-commit` lo lee. Instalación (una sola vez):

```bash
git config core.hooksPath .githooks
chmod +x .githooks/*
```

El hook bloquea el commit si:
- `.review/verdict` no dice `APPROVED`, o
- el veredicto es más viejo que el archivo modificado más reciente (o sea, se
  aprobó y después se siguió tocando código — el `APPROVED` caducó), o
- el staging incluye `CLAUDE.md`, `.claude/`, `.env` o `*.jks`.

---

## 5. Paso ⑥ COMMIT — formato

Conventional commits, español, sin firma de nadie.

```
feat(citas): reserva con control de concurrencia optimista

Implementa RF-19..RF-21. El cliente envía el slot con su versión; si el
servidor responde 409 se refresca la grilla y se avisa al usuario en vez
de reintentar en silencio.

Refs: RF-19, RF-20, RF-21, RNF-10
```

Prefijos: `feat` `fix` `refactor` `test` `docs` `chore` `perf` `style`
Ámbitos: `auth` `perfil` `agenda` `citas` `historial` `chat` `video`
`notificaciones` `core` `ui` `docker`

**Config obligatoria antes del primer commit:**

```bash
git config user.name  "Tu Nombre"
git config user.email "tu@correo.com"
git config commit.gpgsign false
```

El hook `commit-msg` rechaza cualquier mensaje que contenga atribución de
herramientas de IA o emojis de bot. (R1)

---

## 6. Arranque

```bash
git clone https://github.com/ElwinsZorrilla/medical-care-mobileapp.git
cd medical-care-mobileapp

# 1. Copiar los artefactos del loop
cp -r ~/medicare-loop/docs      .
cp -r ~/medicare-loop/prompts   .
cp    ~/medicare-loop/.gitignore .
cp -r ~/medicare-loop/githooks  .githooks
cp -r ~/medicare-loop/docker    .

# 2. Activar el gate
git config core.hooksPath .githooks
chmod +x .githooks/*

# 3. Primera fase
#    Pegar prompts/README.md §F00
```

Después de F00, cada fase es: pegar el prompt de la fase desde
`prompts/README.md`, dejar correr el loop, verificar el `APPROVED`, siguiente.

---

## 7. Qué NO hace este loop

Sinceridad sobre los límites, para que no te sorprenda a mitad de camino:

- **No valida el contrato del back por vos.** F00 lo hace con tu Swagger. Si el
  Swagger está desactualizado respecto al código, el front va a fallar en
  runtime y ninguna cantidad de review lo va a atrapar.
- **No "dockeriza la app móvil".** Eso no existe: un APK no corre en un
  contenedor. Lo que F14 sí hace es contenerizar el **build** (reproducible) y
  el target **web** para la defensa. Ver `docker/README.md`.
- **No reemplaza pruebas en dispositivo real.** El emulador y Flutter web no
  detectan problemas de permisos, cámara, notificaciones en background ni
  consumo de batería. F12 (video) y F10 (push) exigen device físico.
