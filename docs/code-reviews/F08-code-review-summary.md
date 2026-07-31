# Code Review: F08 — Citas

**Verdict:** ✅ APPROVED

| | |
| - | - |
| **Branch** | `main` (staged) |
| **Title** | Reserva con control de concurrencia, cancelación y listados por rol |
| **Files Changed** | 13 |
| **Lines Changed** | +2130 |
| **Date** | 2026-07-31 |

---

## Summary

F08 cierra RF-19 a RF-24 y RNF-10. Es **la fase central del proyecto**: el 409
de RF-20, que F00 verificó con una carrera real contra el backend.

Dos decisiones cargan la fase, y las dos vienen de hallazgos de F00: cómo se
clasifica un 409 sobrecargado, y cómo se evita el N+1 de los listados.

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

### 🟠 HIGH-001: Las pruebas salían a la red de verdad *(corregido)*

**Domains:** [Test Quality]
**Location:** `test/features/citas/mis_citas_screen_test.dart`

Los tests de pantalla tardaban **entre 15 y 30 segundos cada uno** y varios
fallaban. La causa: se sobreescribió `citasRepositoryProvider` pero **no**
`medicoDirectorioProvider`, así que la caché de médicos usaba el `Dio` real e
intentaba resolver `/doctors/2` contra un host inexistente. Cada prueba
esperaba el timeout completo.

Es un fallo peor que lento: una suite que sale a la red es **no
determinista**. Pasa o falla según haya conexión, según el DNS, según si
alguien levantó algo en ese puerto. Y el tiempo la vuelve la primera candidata
a que alguien la marque `skip` cuando estorbe.

**Corrección:** `HttpClientAdapter` falso que responde 404. El directorio
devuelve `null` de inmediato —que además es el caso interesante, "la cita se
pinta aunque el nombre no se resuelva"— y la suite bajó de **32s a 4s**.

---

### 🟡 MEDIUM-001: `Failure` es sellada y no se puede extender *(replanteado)*

**Domains:** [Architecture]
**Location:** `lib/features/citas/data/citas_repository.dart`

La primera versión declaraba `final class FalloReserva extends Failure` para
llevar la reacción junto al mensaje. No compila: `Failure` es **sealed**, y
Dart exige que todas sus variantes vivan en la misma librería.

La salida fácil era mover `FalloReserva` a `core/error/failure.dart`. Habría
compilado, y habría metido conocimiento de reservas —un detalle de un feature—
en el archivo de errores que comparte toda la app. La jerarquía sellada está
haciendo justo su trabajo al impedirlo.

**Solución:** el repositorio devuelve los tipos que **ya existen**
(`TurnoInvalido`, `Conflicto`) y `ReaccionAConflicto.para(Failure)` —en el
dominio de `citas`— traduce a la decisión. Ninguna pantalla vuelve a
interpretar el texto del servidor, y `core` no aprende nada sobre reservas.

---

### 🟢 LOW-001: Una prueba con datos que no probaban nada *(corregido)*

**Location:** `test/features/citas/citas_repository_test.dart`

`expect(pagina.hayMas, isTrue)` con `total: 3` y `limit: 10`. Falló, y tenía
razón en fallar: tres elementos caben en una página, así que `hayMas` es
correctamente `false`.

El dato del test estaba mal, no el código. Se corrigió a `total: 30` y se
agregó la prueba del caso contrario, que faltaba.

---

### ℹ️ INFO-001: El filtro de estado es del lado cliente

`ListAppointmentsQueryDto` del backend **solo acepta paginación**: no hay
`estado`, `desde` ni `hasta` (F00). El filtro de RF-23 opera sobre la página
cargada.

Es una limitación real y visible: con varias páginas, filtrar por "cancelada"
muestra solo las canceladas **de lo que se cargó**. Se documenta acá y en la
matriz en vez de disimularlo, porque la alternativa —pedir `limit=50` y
llamarlo "todas"— sería mentir con más pasos.

---

## Lo que sostiene la fase

### 1. El 409 está sobrecargado y las reacciones son opuestas

F00 verificó que el backend usa `409` para al menos tres cosas, sin código de
error propio. El texto es lo único que las distingue:

| Mensaje del servidor | Reacción | Por qué |
| --- | --- | --- |
| `Ese turno ya fue reservado` | **refrescar la grilla** | el turno no existe más |
| `...por otro paciente` | **refrescar la grilla** | se perdió la carrera |
| `solo admite modalidad PRESENCIAL` | **corregir la modalidad** | refrescar borraría la selección sin arreglar nada |
| `La cita ya estaba cancelada` | mostrar el mensaje | no hay nada que rehacer |

Y el `400` de esa ruta **no es validación**: significa "ese turno no está en
ninguna franja", que también pide refrescar. Mapearlo a `Validacion` pintaría
un campo en rojo cuando el problema es que la grilla quedó vieja.

**Nunca se reintenta en silencio.** El turno ya no existe: reintentar
produciría el mismo 409 mientras el usuario mira la app pensar sin entender
por qué. Seis pruebas cubren cada rama.

### 2. El N+1 que anotó F00

`AppointmentResponseDto` devuelve **ids planos**: `idMedico: 2`, sin nombre.
Una lista de 10 citas serían 10 peticiones a `/doctors/{id}`; la agenda con 50
citas, 50. Con datos móviles lentos eso es la diferencia entre una lista que
aparece y una que tarda.

`MedicoDirectorio` cachea por id y **coalesce las peticiones simultáneas** —el
mismo patrón del refresh single-flight de F03—. Diez citas de tres médicos son
tres peticiones. En la agenda del médico no resuelve nada: todas las citas son
suyas.

Y si un nombre no se resuelve, **la cita se pinta igual**: fecha, hora y
estado ya son útiles. Bloquear la lista por un nombre que no llegó sería peor
que mostrarla incompleta.

---

## Rubro aplicado — docs/REVIEW_GATE.md

| Sección | Resultado |
| --- | --- |
| 3.1 Seguridad | ✅ ninguna ruta recibe id de usuario; el backend resuelve paciente y médico desde el token |
| 3.2 Corrección | ✅ **BLOQUEANTE de RF-20 cubierto**: 409 explícito, refresco de grilla, sin reintento silencioso · `CitaEstado.fromApi` falla ruidoso · paginación real |
| 3.3 Arquitectura | ✅ `citas` no importa de ningún feature; `MedicoDirectorio` en `core` |
| 3.4 UI y diseño | ✅ el riel de estado carga el peso visual · fecha y hora en versalitas + mono · cero literales · el nombre de la acción no cambia entre botón y confirmación |
| 3.5 Pruebas | ✅ 33 nuevas · camino feliz y de error por caso de uso · los 4 estados |
| 3.6 Higiene | ✅ analyze en cero |

**Sobre 3.4 y la copia:** el botón dice "Cancelar cita" y el diálogo confirma
con **"Cancelar cita"**, no con "Aceptar". El nombre de la acción no cambia en
el camino (DESIGN_SYSTEM §8). El botón "Volver" es el que se va, para que no
haya un "Cancelar" que cancele el cancelar.

**Sobre el motivo obligatorio:** el backend lo exige y la UI también, con
mensaje propio. Dejarlo llegar vacío al servidor produciría un 400 genérico
que el usuario no sabría cómo corregir.

---

## Files Reviewed

| File | Findings |
| ---- | -------- |
| `test/features/citas/mis_citas_screen_test.dart` | 1 (HIGH-001) |
| `lib/features/citas/data/citas_repository.dart` | 1 (MEDIUM-001) |
| `test/features/citas/citas_repository_test.dart` | 1 (LOW-001) |
| `lib/features/citas/domain/cita.dart` | 0 |
| `lib/core/data/medico_directorio.dart` | 0 |
| `lib/features/citas/data/` (2) | 0 |
| `lib/features/citas/presentation/` (2) | 0 |
| `lib/core/router/app_router.dart` | 0 |

---

## Estado de VERIFY

```
format      124 archivos, 0 cambios
codegen     build_runner OK
analyze     No issues found!     (--fatal-infos --fatal-warnings)
test        265 pruebas + 20 goldens
cobertura   73.5%  (minimo 70%)
VERIFY OK   exit 0
```

VERDICT: APPROVED
