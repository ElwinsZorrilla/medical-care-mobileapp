# Code Review: F01 — Fundación

**Verdict:** ✅ APPROVED *(vuelta 2 — los 3 hallazgos de la vuelta 1 quedaron cerrados)*

| | |
| - | - |
| **Branch** | `main` (staged, sin commitear) |
| **Title** | Esqueleto del proyecto Flutter: DI, env, router, linter estricto |
| **Files Changed** | 83 (19 revisables; `android/`, `ios/`, `web/` son salida sin modificar de `flutter create`) |
| **Lines Changed** | +2209 / -168 (revisables: +713 / -168) |
| **Date** | 2026-07-30 |

---

## Summary

F01 entrega el esqueleto del proyecto con buena disciplina: cero secretos en
código, `Env` que falla al arrancar en vez de en la primera petición, linter
estricto con `flutter analyze --fatal-infos` en cero, y 91.3% de cobertura con
camino feliz y de error por cada regla de validación.

Los dos hallazgos que bloquean **no están en el código Dart sino en el
empaquetado**, y los dos rompen algo real: el stage `verify` del Dockerfile no
puede ejecutar `verify.sh` porque el archivo no tiene bit de ejecución en el
índice de git, y la ausencia de `.dockerignore` haría que `COPY . .` meta al
contenedor un `.dart_tool` de 55 MB lleno de rutas absolutas de Windows.

El primero además tiene una consecuencia peor que el build: **los hooks de
`.githooks/` tampoco son ejecutables, y git los saltea en silencio.** En un
clon nuevo, la regla R4 —"no se commitea sin APPROVED"— no se aplica: falla
abierta, sin avisar.

---

## Findings Overview

| Severity | In Scope | Out of Scope |
| -------- | -------- | ------------ |
| 🔴 CRITICAL | 0 | 0 |
| 🟠 HIGH | 2 | 0 |
| 🟡 MEDIUM | 1 | 0 |
| 🟢 LOW | 0 | 1 |
| ℹ️ INFO | 2 | 0 |

---

## In Scope Findings

### 🟠 HIGH-001: `verify.sh` y los hooks no son ejecutables — el gate falla abierto

**Domains:** [Security, DevOps]
**Location:** `scripts/verify.sh`, `.githooks/pre-commit`, `.githooks/commit-msg`

Los tres archivos están en el índice con modo `100644`:

```
100644  .githooks/commit-msg
100644  .githooks/pre-commit
100644  scripts/verify.sh
```

Dos consecuencias distintas, las dos reales:

1. **El build de Docker se rompe.** `docker/Dockerfile:46` ahora hace
   `RUN ./scripts/verify.sh`. Sin bit de ejecución, el contenedor responde
   `permission denied` y el stage `verify` falla siempre.

2. **El gate deja de existir en un clon nuevo.** Git **saltea en silencio**
   los hooks que no son ejecutables — no advierte, no falla, simplemente no
   los corre. Alguien que clone el repo y configure `core.hooksPath` según
   LOOP.md §4 va a creer que el gate está activo mientras commitea sin
   ninguna revisión. La regla dura del proyecto (R4) queda anulada sin que
   nadie se entere.

LOOP.md §6 manda `chmod +x .githooks/*` después del clon, pero eso es una
salvaguarda manual para algo que el repo puede garantizar solo. Que el
mecanismo de enforcement dependa de que alguien recuerde un paso es
exactamente el agujero que el gate pretendía cerrar.

**Recommendation:**
Guardar el bit de ejecución en el índice, que es portable y sobrevive al clon:

```bash
git update-index --chmod=+x scripts/verify.sh
git update-index --chmod=+x .githooks/pre-commit
git update-index --chmod=+x .githooks/commit-msg
```

Como red adicional, que el hook avise si se auto-detecta no ejecutable.

---

### 🟠 HIGH-002: Falta `.dockerignore` — se copian 111 MB y rutas absolutas de Windows

**Domains:** [DevOps, Architecture]
**Location:** `docker/Dockerfile:45` (`COPY . .`)

No existe `.dockerignore` en la raíz del proyecto. El stage `verify` hace
`COPY . .`, así que arrastra al contexto de build todo lo que hay en disco:

```
55M  .dart_tool
56M  build
441K .git
```

El problema no es solo el peso. `.dart_tool/package_config.json` guarda rutas
**absolutas de la máquina que lo generó**:

```
file:///C:/Users/ezorr/AppData/Local/Pub/Cache/hosted/pub.dev/alchemist-0.12.1
```

Dentro del contenedor Linux esas rutas no existen. Se copian encima del
`package_config.json` válido que generó el stage `deps` con su
`flutter pub get`, y el resultado es un build que falla —o peor, que resuelve
paquetes de forma impredecible— por una razón que no aparece en ningún log
obvio.

Esto contradice de frente el objetivo declarado del Dockerfile: "el APK que
sale de tu máquina es byte a byte el mismo que sale de CI". Hoy el contenido
de tu `.dart_tool` local entra al build.

**Recommendation:**
Agregar `.dockerignore` en la raíz:

```
.dart_tool/
build/
coverage/
.git/
.github/
.githooks/
.idea/
.vscode/
android/.gradle/
ios/Pods/
ios/.symlinks/
docs/
prompts/
*.md
```

---

### 🟡 MEDIUM-001: `lib/features/` no existe, pero la matriz declara RNF-11 cubierto

**Domains:** [Documentation, Architecture]
**Location:** `docs/TRACEABILITY.md` (fila RNF-11)

La matriz afirma:

> RNF-11 | Arquitectura modular | F01 | `lib/core/` + `lib/features/` según ARCHITECTURE.md | ✅

La estructura real es:

```
lib/core/config
lib/core/router
```

`lib/features/` no existe. La evidencia citada no es verificable, y la matriz
de trazabilidad es justamente el documento que un jurado usa para comprobar
cumplimiento: una fila con evidencia falsa vale menos que una fila vacía.

**Recommendation:**
O crear `lib/features/.gitkeep` con la estructura de dominios de
ARCHITECTURE.md, o bajar RNF-11 a ⬜/⚠️ y describir la evidencia real
(`lib/core/` creado, features pendientes por fase). La segunda es más honesta:
la modularidad se demuestra cuando hay más de un módulo.

---

### ℹ️ INFO-001: `Env.validar()` revienta sin pantalla de error

**Location:** `lib/main.dart:13`

Si falta `API_BASE_URL`, la excepción sube sin capturar y la app cierra sin
mensaje. Es el comportamiento buscado —fallar temprano y ruidoso— y como el
valor se fija en compilación con `--dart-define`, una config mala es un build
malo, no un estado de runtime. Se deja anotado por si en F04 se quiere una
pantalla de error legible en vez de un cierre seco.

---

### ℹ️ INFO-002: El template del revisor trae atribución de IA

**Location:** `~/.claude/skills/code-reviewer-pro/assets/summary-report-template.md:108`

La última línea del template es una firma de herramienta de IA. Este reporte
la omite a propósito: viola LOOP.md §0 R1 y el propio `.githooks/pre-commit`
la bloquearía. Conviene editar el template para que no reintroduzca la firma
en cada revisión.

---

## Out of Scope

| Severity | Issue | Location |
| -------- | ----- | -------- |
| 🟢 LOW | Imágenes base con vulnerabilidades conocidas: `debian:bookworm-slim` (1 crítica, 2 altas) y `nginx:1.27-alpine` (4 críticas, 26 altas). Preexistente, entra en F14. | `docker/Dockerfile:15,91` |

---

## Action Items

### Must Fix (blocks merge)

- (ninguno — no hay hallazgos CRITICAL)

### Should Fix

- [ ] HIGH-001 — `git update-index --chmod=+x` en `verify.sh` y los dos hooks
- [ ] HIGH-002 — agregar `.dockerignore`

### Consider

- [ ] MEDIUM-001 — alinear la fila RNF-11 de `TRACEABILITY.md` con la realidad

---

## Files Reviewed

| File | Findings |
| ---- | -------- |
| `scripts/verify.sh` | 1 (HIGH-001) |
| `.githooks/pre-commit` | 1 (HIGH-001) |
| `.githooks/commit-msg` | 1 (HIGH-001) |
| `docker/Dockerfile` | 2 (HIGH-002, LOW fuera de alcance) |
| `docs/TRACEABILITY.md` | 1 (MEDIUM-001) |
| `lib/main.dart` | 1 (INFO-001) |
| `lib/core/config/env.dart` | 0 |
| `lib/core/router/app_router.dart` | 0 |
| `lib/app.dart` | 0 |
| `test/core/config/env_test.dart` | 0 |
| `test/app_test.dart` | 0 |
| `pubspec.yaml` · `pubspec.lock` | 0 |
| `analysis_options.yaml` | 0 |
| `.gitignore` · `.gitattributes` | 0 |
| `LOOP.md` · `docs/ARCHITECTURE.md` · `docs/BACKEND_ISSUES.md` | 0 |
| `docker/docker-compose.yml` · `docker/README.md` | 0 |

---

## Rubro aplicado — docs/REVIEW_GATE.md

| Sección | Resultado |
| --- | --- |
| 3.1 Seguridad | ✅ sin secretos ni URLs en duro (solo `String.fromEnvironment`); sin `print`/`debugPrint`; sin `badCertificateCallback` |
| 3.2 Corrección | ✅ sin `DateTime` en F01; el resto no aplica todavía |
| 3.3 Arquitectura | ✅ sin dependencias entre features; presentación no toca `dio` |
| 3.4 UI y diseño | ✅ cero literales de color, tamaño o espacio en widgets |
| 3.5 Pruebas | ✅ 8/8, camino feliz y de error, cobertura 91.3% ≥ 70% |
| 3.6 Higiene | ⚠️ `flutter analyze` en cero y cero atribución de IA, pero ver HIGH-001 |

La prueba que exige 3.5 —"que rompa si alguien mete un `DateTime` local en un
payload"— no aplica en F01: todavía no hay payloads. Queda como requisito de
entrada de **F03**, junto con `AppTime`.

---

## Vuelta 2 — resolución

Los tres hallazgos se corrigieron y se verificaron uno por uno. `verify.sh`
volvió a salir en 0 después de los cambios.

| Hallazgo | Corrección | Verificación |
| --- | --- | --- |
| 🟠 HIGH-001 | `git update-index --chmod=+x` sobre los tres archivos | El índice ahora dice `100755` en `scripts/verify.sh`, `.githooks/pre-commit` y `.githooks/commit-msg`. Sobrevive al clon: no depende de que nadie corra `chmod`. |
| 🟠 HIGH-002 | `.dockerignore` en la raíz | Excluye `.dart_tool/`, `build/`, `.git/`, docs y material de firma. El `COPY . .` deja de arrastrar rutas absolutas del host. |
| 🟡 MEDIUM-001 | Fila RNF-11 reescrita | Pasa de ✅ a ⚠️ con la evidencia real: `lib/core/{config,router}` creado, `features/` por fase. |

**Sobre MEDIUM-001:** se eligió corregir la afirmación en vez de crear
`lib/features/` con `.gitkeep`. Una carpeta vacía haría verdadera la fila sin
hacer verdadero el requisito — la modularidad se demuestra con módulos, no con
directorios. Un ⚠️ con la razón escrita vale más que un ✅ que no resiste que
lo abran.

Estado final de VERIFY tras las correcciones:

```
format      7 archivos, 0 cambios
codegen     build_runner OK
analyze     No issues found!     (--fatal-infos --fatal-warnings)
test        8/8
cobertura   91.3%  (minimo 70%)
VERIFY OK   exit 0
```

Queda pendiente para F14, fuera del alcance de esta fase: las imágenes base
del Dockerfile con vulnerabilidades conocidas.

VERDICT: APPROVED
