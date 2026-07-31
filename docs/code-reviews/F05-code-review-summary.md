# Code Review: F05 — Perfiles

**Verdict:** ✅ APPROVED

| | |
| - | - |
| **Branch** | `main` (staged) |
| **Title** | Perfil de paciente y médico, estado de verificación y fecha de calendario |
| **Files Changed** | 14 |
| **Lines Changed** | +1720 |
| **Date** | 2026-07-31 |

---

## Summary

F05 cierra RF-07 a RF-11 y, con `perfil` como segundo módulo independiente,
deja RNF-11 demostrado de verdad: dos features con las tres capas, ninguno
importando del otro, y lo compartido subido a `core/domain/`.

Aparecieron dos cosas que valen más que el código de pantalla: **un error en el
contrato que yo mismo escribí en F00**, y una variante del bug de zona horaria
que no rompe nada visiblemente.

---

## Findings Overview

| Severity | In Scope | Out of Scope |
| -------- | -------- | ------------ |
| 🔴 CRITICAL | 0 | 0 |
| 🟠 HIGH | 1 | 0 |
| 🟡 MEDIUM | 1 | 0 |
| 🟢 LOW | 1 | 0 |
| ℹ️ INFO | 0 | 0 |

---

## In Scope Findings

### 🟠 HIGH-001: El contrato de F00 tenía el campo al revés *(corregido)*

**Domains:** [Correctness, Documentation]
**Location:** `docs/API_CONTRACT.md` §4

`API_CONTRACT.md` documentaba el cuerpo de
`PUT /doctors/{id}/especialidades` como `{ idsEspecialidades: number[] }`. El
spec real dice **`especialidadIds`**.

Es un hallazgo serio por dónde estaba, no por su tamaño: el contrato es el
documento que F06 a F09 van a leer sin volver a verificar. Un DTO construido
sobre ese nombre habría fallado con `400 property idsEspecialidades should not
exist` —por `forbidNonWhitelisted`— y el error habría aparecido en runtime,
lejos de su causa.

Confirma el argumento de F00: *verificar el contra el spec, no contra la
memoria*. Yo mismo lo escribí mal cuando lo transcribí.

**Corrección:** campo corregido en el contrato y en el DTO, con prueba que
verifica el nombre que llega a la API.

---

### 🟡 MEDIUM-001: La fecha de nacimiento se corría un día *(evitado por diseño)*

**Domains:** [Correctness]
**Location:** `lib/core/domain/fecha_calendario.dart`

Una fecha de nacimiento **no es un instante**. Si se trata como `DateTime` UTC
y se pinta con `AppTime.aLocal` —que es lo que hace el resto de la app y lo
correcto para citas— el offset de −4 la corre un día:

```dart
AppTime.aLocal(DateTime.utc(1990, 8, 1))  // → 31 de julio
```

Alguien nacido el 1 de agosto aparecería como del 31 de julio. **No rompe
nada**: no hay excepción, no hay pantalla en blanco, solo el día equivocado
para todos los nacidos en los primeros días del mes. Es la variante más
silenciosa del bug de RNF-18 y la más difícil de notar en una demo.

**Solución:** tipo propio `FechaCalendario`, que no comparte camino con los
`DateTime` en UTC y no tiene ninguna operación de zona horaria. Hay una prueba
que **documenta el bug** convirtiendo mal a propósito y verificando que da 31
de julio, junto a la conversión correcta.

---

### 🟢 LOW-001: El fake del provider dejaba el test en carga permanente *(corregido)*

**Location:** `test/features/perfil/perfil_screen_test.dart`

La primera versión sobreescribía `miPerfilPacienteProvider` con
`Future.error(...)`. El estado nunca llegaba a `AsyncError` en los turnos que
el test daba, así que la pantalla se quedaba en carga y la aserción fallaba
por la razón equivocada: parecía un bug de la UI y era del andamiaje.

**Corrección:** se falsea el **repositorio**, no el provider. El test recorre
el código real del provider —incluido el mapeo `Result` → `AsyncValue`— y deja
de depender de cuántos microtasks hacen falta. Se agregó latencia simulada al
doble para que exista un frame de carga observable.

---

## Rubro aplicado — docs/REVIEW_GATE.md

| Sección | Resultado |
| --- | --- |
| 3.1 Seguridad | ✅ **RF-09 estructural**: ninguna ruta del `PerfilApi` recibe id de usuario. `/patients/me` y `/doctors/me` lo sacan del token, así que el cliente no tiene dónde poner uno ajeno |
| 3.2 Corrección | ✅ `EstadoVerificacion.fromApi` falla ruidoso; el PATCH descarta nulos para no borrar campos que el usuario no tocó |
| 3.3 Arquitectura | ✅ `perfil` no importa de `auth`; lo común subió a `core/domain/` |
| 3.4 UI y diseño | ✅ cero literales · datos clínicos en `data` (mono) · estado con color + glifo + etiqueta |
| 3.5 Pruebas | ✅ camino feliz y de error por caso de uso · 25 pruebas de perfil · los 4 estados de pantalla con prueba propia |
| 3.6 Higiene | ✅ analyze en cero, cero atribución |

**Sobre RF-10 y los campos no editables:** `UpdatePatientDto` del backend no
incluye `documentoIdentidad`, y `UpdateDoctorDto` no incluye `numExequatur`.
Hay dos pruebas que verifican que el PATCH **no los manda**: con
`forbidNonWhitelisted`, incluirlos devolvería 400 y rompería el guardado
entero por un campo que ni siquiera cambió. La UI los muestra como dato de
solo lectura, no como campo deshabilitado —que sugeriría que podría
habilitarse.

**Sobre RF-11 y "explicado":** el requisito pide el estado *visible y
explicado*. Un badge que diga "PENDIENTE" es visible y no explica nada: el
médico no sabe si debe hacer algo ni si puede trabajar mientras tanto. Cada
estado lleva su explicación al lado, y hay una prueba que exige que ninguna
baje de 40 caracteres — una forma barata de impedir que alguien la vacíe.

---

## Files Reviewed

| File | Findings |
| ---- | -------- |
| `docs/API_CONTRACT.md` | 1 (HIGH-001) |
| `lib/core/domain/fecha_calendario.dart` | 1 (MEDIUM-001) |
| `test/features/perfil/perfil_screen_test.dart` | 1 (LOW-001) |
| `lib/features/perfil/domain/perfil.dart` | 0 |
| `lib/features/perfil/data/` (3) | 0 |
| `lib/features/perfil/presentation/` (3) | 0 |
| `lib/core/domain/especialidad.dart` | 0 |
| `lib/core/router/app_router.dart` | 0 |
| `test/core/domain/fecha_calendario_test.dart` | 0 |
| `test/features/perfil/perfil_repository_test.dart` | 0 |

---

## Estado de VERIFY

```
format      79 archivos, 0 cambios
codegen     build_runner OK
analyze     No issues found!     (--fatal-infos --fatal-warnings)
test        146 pruebas + 20 goldens
cobertura   79.7%  (minimo 70%)
VERIFY OK   exit 0
```

VERDICT: APPROVED
