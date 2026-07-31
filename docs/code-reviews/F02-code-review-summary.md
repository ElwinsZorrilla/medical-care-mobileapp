# Code Review: F02 — Design System

**Verdict:** ✅ APPROVED

| | |
| - | - |
| **Branch** | `main` (staged) |
| **Title** | Sistema de diseño en código: tokens, tema, 12 componentes, galería y goldens |
| **Files Changed** | 41 |
| **Lines Changed** | +2954 / -10 |
| **Date** | 2026-07-31 |

---

## Summary

F02 entrega el sistema de diseño completo: tokens, paleta derivada para claro
y oscuro, escala tipográfica de tres cortes, las dos densidades como extensión
de `Theme`, los 12 componentes base, la galería de revisión visual y 20
goldens del riel de estado.

La disciplina que el rubro exige se sostiene: **cero colores, tamaños o
espacios literales en widgets** — todo sale de `AppColors` / `Space` /
`context.text`. `flutter analyze --fatal-infos` en cero y cobertura 87.3%.

Durante la revisión aparecieron cuatro hallazgos, ninguno bloqueante. Los
cuatro se corrigieron antes de emitir el veredicto y quedan documentados abajo,
porque un hallazgo silenciado no enseña nada.

El hallazgo que importa no es de estilo: **una prueba que no podía fallar.**

---

## Findings Overview

| Severity | In Scope | Out of Scope |
| -------- | -------- | ------------ |
| 🔴 CRITICAL | 0 | 0 |
| 🟠 HIGH | 0 | 0 |
| 🟡 MEDIUM | 1 | 0 |
| 🟢 LOW | 3 | 0 |
| ℹ️ INFO | 1 | 0 |

Bajo el rubro del proyecto (`docs/REVIEW_GATE.md` §2) hace falta **3 o más
MAYOR** para tumbar la fase. Hubo 1 MAYOR y 3 MENOR → `APPROVED`, y aun así se
corrigieron todos.

---

## In Scope Findings

### 🟡 MEDIUM-001: Una prueba que no podía fallar *(corregido)*

**Domains:** [Test Quality]
**Location:** `test/core/widgets/widgets_test.dart` — "el riel mide exactamente 4px"

```dart
expect(riel.constraints?.maxWidth ?? Strokes.riel, Strokes.riel);
```

Si `constraints` fuera nulo, el `??` devuelve `Strokes.riel` y la aserción
compara **el token contra sí mismo**: verde siempre, midiera lo que midiera el
riel.

Es el peor tipo de prueba: da confianza donde no hay cobertura. El riel de 4px
es el elemento firma del sistema, justamente lo que debe estar protegido; una
prueba verde que no verifica nada es peor que no tenerla, porque nadie vuelve a
mirar.

**Corrección aplicada** — medir lo renderizado en vez de la propiedad:

```dart
expect(tester.getSize(find.byType(AnimatedContainer)).width, Strokes.riel);
```

Verificado: la prueba ahora falla si se cambia el ancho del riel.

---

### 🟢 LOW-001: Duración literal fuera de `Motion` *(corregido)*

**Location:** `lib/core/widgets/loading_skeleton.dart:55`

`const Duration(milliseconds: 900)` escrito dentro del widget. `Motion` es el
dueño de las duraciones del sistema; una suelta acá es la primera grieta por
donde después entran las demás.

**Corrección:** se agregó `Motion.skeleton` a los tokens y el widget lo usa.

---

### 🟢 LOW-002: Números mágicos en la galería *(corregido)*

**Location:** `lib/dev/gallery.dart:174,194`

`height: 260` repetido para encuadrar `EmptyState` y `ErrorState`. Es código de
desarrollo, no de producción, pero la galería es la vitrina de la disciplina
del sistema: si ahí se toleran literales, el argumento se debilita solo.

**Corrección:** constante `_altoDemo` con comentario de por qué existe y por
qué no aplica en la app real.

---

### 🟢 LOW-003: La galería renderizaba distinto que producción *(corregido)*

**Location:** `lib/dev/gallery_main.dart`

`main.dart` fija `GoogleFonts.config.allowRuntimeFetching = false`, pero
`gallery_main.dart` no lo hacía. La galería es **la herramienta con la que se
aprueba el diseño**: si renderiza con tipografías bajadas por red y producción
con las empaquetadas, la revisión visual estaría aprobando algo que no es lo
que ve el usuario.

**Corrección:** mismo ajuste en los dos puntos de entrada.

---

### ℹ️ INFO-001: Decisión de empaquetar las tipografías

**Location:** `google_fonts/`, `pubspec.yaml`

Durante F02 se descubrió que `google_fonts` descarga las familias por HTTP en
el primer arranque. Para el usuario que describe `DESIGN_SYSTEM.md` §1
—Android de gama media, datos móviles lentos— eso significa arrancar sin la
tipografía de marca, y sin conexión no tenerla nunca.

Se empaquetaron las 5 instancias que el sistema usa (**576 KB**) y se apagó la
descarga en runtime. Efecto secundario valioso: los goldens dejan de depender
de una descarga y pasan a ser deterministas.

Las tres familias son SIL OFL 1.1, redistribuibles dentro de una app. Licencias
y origen documentados en `google_fonts/NOTICE.md`.

---

## Rubro aplicado — docs/REVIEW_GATE.md

| Sección | Resultado |
| --- | --- |
| 3.1 Seguridad | ✅ sin secretos, sin `print`, sin URLs en duro |
| 3.2 Corrección | ✅ `CitaEstado.fromApi` falla ruidoso ante un estado desconocido, con prueba |
| 3.3 Arquitectura | ✅ `core/` no importa de `features/`; ningún widget toca `dio` |
| 3.4 UI y diseño | ✅ cero literales en widgets · 48dp verificado en botón, tarjeta, banner y encabezado · estado siempre color **+ glifo + etiqueta** · `Motion.of` respeta movimiento reducido · `textScale` 2.0 sin excepciones |
| 3.5 Pruebas | ✅ 38 pruebas + 20 goldens · cobertura 87.3% ≥ 70% |
| 3.6 Higiene | ✅ `analyze --fatal-infos` en cero · cero atribución de IA · sin `TODO` sueltos |

**Sobre 3.4 y el daltonismo:** hay prueba explícita de que los cinco estados
tienen glifo distinto, no solo color. Es el punto del design system más fácil
de romper sin darse cuenta y ahora tiene red propia.

**Sobre los goldens:** se generan con el render de texto bloqueado
(`PlatformGoldensConfig(enabled: false)`), así que comparan **layout** y no el
motor de fuentes de cada máquina. Un golden hecho en Windows no falla en el
Linux del pipeline por una diferencia de antialiasing.

---

## Files Reviewed

| File | Findings |
| ---- | -------- |
| `test/core/widgets/widgets_test.dart` | 1 (MEDIUM-001) |
| `lib/core/widgets/loading_skeleton.dart` | 1 (LOW-001) |
| `lib/dev/gallery.dart` | 1 (LOW-002) |
| `lib/dev/gallery_main.dart` | 1 (LOW-003) |
| `pubspec.yaml` · `google_fonts/` | 1 (INFO-001) |
| `lib/core/theme/tokens.dart` · `app_theme.dart` · `density_provider.dart` | 0 |
| `lib/core/domain/cita_estado.dart` | 0 |
| `lib/core/time/app_time.dart` | 0 |
| `lib/core/widgets/` (los otros 11) | 0 |
| `test/core/domain/cita_estado_test.dart` | 0 |
| `test/core/time/app_time_test.dart` | 0 |
| `test/core/widgets/status_rail_golden_test.dart` | 0 |
| `test/flutter_test_config.dart` · `dart_test.yaml` | 0 |
| `lib/app.dart` · `lib/main.dart` | 0 |

---

## Estado de VERIFY tras las correcciones

```
format      33 archivos, 0 cambios
codegen     build_runner OK
analyze     No issues found!     (--fatal-infos --fatal-warnings)
test        38 pruebas + 20 goldens
cobertura   87.3%  (minimo 70%)
VERIFY OK   exit 0
```

VERDICT: APPROVED
