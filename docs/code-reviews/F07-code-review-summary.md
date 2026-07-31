# Code Review: F07 — Disponibilidad

**Verdict:** ✅ APPROVED

| | |
| - | - |
| **Branch** | `main` (staged) |
| **Title** | Franjas del médico y cálculo de turnos libres |
| **Files Changed** | 11 |
| **Lines Changed** | +1810 |
| **Date** | 2026-07-31 |

---

## Summary

F07 cierra RF-16 y RF-18, y deja RF-17 parcial por una limitación del backend.
Es la fase donde RNF-18 vuelve a poner a prueba todo, porque **el mismo nombre
de campo significa dos cosas distintas según el endpoint**: `horaInicio` es
`"08:00"` hora local en una franja, y `2026-08-17T12:00:00.000Z` en un turno.

Una prueba de widget encontró un **bug de layout real** que no se ve en el
emulador de escritorio.

---

## Findings Overview

| Severity | In Scope | Out of Scope |
| -------- | -------- | ------------ |
| 🔴 CRITICAL | 0 | 0 |
| 🟠 HIGH | 1 | 0 |
| 🟡 MEDIUM | 1 | 0 |
| 🟢 LOW | 1 | 0 |
| ℹ️ INFO | 1 | 0 |

---

## In Scope Findings

### 🟠 HIGH-001: El formulario desbordaba y escondía el botón de guardar *(corregido)*

**Domains:** [UI, Accessibility]
**Location:** `lib/features/agenda/presentation/screens/disponibilidad_screen.dart`

```
A RenderFlex overflowed by 22 pixels on the bottom.
```

La hoja modal de "nueva franja" era una `Column` de altura fija. Con el
teclado abierto —que es el estado normal mientras se llena— **el botón
"Guardar franja" queda fuera de vista**. El médico ve un formulario que no
puede enviar.

Veintidós píxeles en el emulador de escritorio; en un Android de gama media
con la barra de navegación por gestos y `textScale` ampliado, bastante más.
Es exactamente el caso que el rubro 3.4 pide cubrir —"el layout sobrevive
`textScaleFactor` 2.0 sin recortes"— y que no aparece si solo se prueba a
mano en una pantalla grande.

Lo encontró una prueba de widget escrita para otra cosa: el `RenderFlex` tiró
excepción al abrir el formulario.

**Corrección:** `SingleChildScrollView` en la hoja. El contenido hace scroll
en vez de recortarse.

---

### 🟡 MEDIUM-001: Faltaban los operadores de comparación *(corregido)*

**Location:** `lib/features/agenda/domain/disponibilidad.dart`

`HoraDelDia` definía `<` y `>` pero no `<=` ni `>=`. La validación del
formulario usa `_fin <= _inicio` y no compilaba.

Vale anotarlo porque el fallo es del tipo correcto: **el compilador atrapó lo
que la lógica necesitaba**. Si `HoraDelDia` hubiera sido un `int` de minutos,
la comparación habría compilado sin que nadie revisara si el criterio era el
adecuado.

---

### 🟢 LOW-001: Un test cuyo nombre no describía lo que verificaba *(corregido)*

**Location:** `test/features/agenda/disponibilidad_screen_test.dart`

La prueba se llamaba "hora fin menor que inicio se valida en local" y en
realidad guardaba con los valores por defecto y comprobaba el día enviado.
Mover el selector de hora en un test es incómodo, así que había escrito otra
cosa y dejado el nombre.

Un nombre que miente es peor que no tenerlo: quien lea el reporte de
cobertura va a creer que ese camino está protegido.

**Corrección:** renombrada a "guarda con la numeración de día del backend",
que es lo que hace. La validación de horas queda cubierta por
`agenda_repository_test` a nivel de dominio.

---

### ℹ️ INFO-001: RF-17 se cumple a medias

`PATCH /availability/{id}/desactivar` existe; **no hay endpoint para
reactivar**. Desactivar es de una sola dirección.

Por eso la acción pide confirmación y el diálogo lo dice explícitamente
("No se puede reactivar: tendrías que crearla de nuevo"). Sin ese aviso, un
toque accidental obliga a rehacer la franja, y el médico no tiene forma de
saberlo antes.

La matriz dice ⚠️ con la razón.

---

## Lo que sostiene la fase: dos significados, un nombre

| Endpoint | `horaInicio` | Qué es |
| --- | --- | --- |
| `GET /availability/me` | `"08:00"` | hora de pared local, sin fecha ni zona |
| `GET .../slots?fecha=` | `"2026-08-17T12:00:00.000Z"` | instante absoluto UTC |

Son campos con el mismo nombre y tipos incompatibles. El código los separa en
**dos tipos distintos** —`HoraDelDia` y `DateTime` UTC— para que confundirlos
no compile, en vez de confiar en que nadie se equivoque.

Tres decisiones relacionadas, todas con prueba:

1. **`?fecha=` se resuelve en calendario dominicano.** A las 21:00 del lunes
   en RD ya es martes en UTC; mandar la fecha UTC mostraría los turnos del día
   equivocado. Hay prueba de que `01:00Z del 18` pide `2026-08-17`.
2. **`DiaSemana` numera 0 = domingo**, como `getUTCDay()` de JavaScript. Dart
   numera al revés (1 = lunes … 7 = domingo), así que existe
   `desdeWeekdayDart` con su prueba: pasar el `weekday` de Dart directo
   funcionaría para todos los días **menos el domingo**, que se iría a la otra
   punta de la semana.
3. **El turno guarda el string crudo del servidor.** Al reservar hay que
   mandar ese mismo valor; reconstruirlo con `toIso8601String()` puede diferir
   en milisegundos y el backend no encontraría el turno. Lo va a usar F08.

---

## Rubro aplicado — docs/REVIEW_GATE.md

| Sección | Resultado |
| --- | --- |
| 3.1 Seguridad | ✅ `/availability/me` saca el médico del token; ninguna ruta recibe id de usuario |
| 3.2 Corrección | ✅ **BLOQUEANTE de RNF-18 cubierto**: `?fecha=` en calendario local, con prueba del caso 20:00–23:59 · `DiaSemana` y `ModalidadFranja` fallan ruidoso |
| 3.3 Arquitectura | ✅ `ModalidadCita`/`ModalidadFranja` en `core` desde el principio — la lección de F06 aplicada antes de necesitarla |
| 3.4 UI y diseño | ✅ tras corregir HIGH-001 · horas en `data` (mono tabular) · chips de 48dp · confirmación antes de una acción irreversible |
| 3.5 Pruebas | ✅ 39 nuevas · camino feliz y de error por caso de uso · los 4 estados de pantalla |
| 3.6 Higiene | ✅ analyze en cero |

**Sobre la retroalimentación del formulario:** el médico ve cuántos turnos
genera la franja **antes** de guardar. Sin eso, descubre el efecto de elegir
turnos de 45 min en una franja de 2 horas cuando un paciente no encuentra
hueco — y para entonces ya no relaciona una cosa con la otra.

**Sobre validar `horaFin > horaInicio` en local:** el backend responde **409**
en ese caso, no 400. Un 409 se lee como "conflicto con algo que ya existe", y
mostrarlo tal cual confundiría. Se valida antes y el mensaje apunta al campo.

---

## Files Reviewed

| File | Findings |
| ---- | -------- |
| `lib/features/agenda/presentation/screens/disponibilidad_screen.dart` | 1 (HIGH-001) |
| `lib/features/agenda/domain/disponibilidad.dart` | 1 (MEDIUM-001) |
| `test/features/agenda/disponibilidad_screen_test.dart` | 1 (LOW-001) |
| `lib/core/domain/modalidad.dart` | 0 |
| `lib/features/agenda/data/` (3) | 0 |
| `lib/features/agenda/presentation/providers/agenda_provider.dart` | 0 |
| `test/features/agenda/agenda_repository_test.dart` | 0 |
| `lib/core/router/app_router.dart` | 0 |

---

## Estado de VERIFY

```
format      106 archivos, 0 cambios
codegen     build_runner OK
analyze     No issues found!     (--fatal-infos --fatal-warnings)
test        212 pruebas + 20 goldens
cobertura   72.9%  (minimo 70%)
VERIFY OK   exit 0
```

VERDICT: APPROVED
