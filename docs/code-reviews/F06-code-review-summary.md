# Code Review: F06 — Especialidades y búsqueda

**Verdict:** ✅ APPROVED

| | |
| - | - |
| **Branch** | `main` (staged) |
| **Title** | Catálogo de especialidades, filtro y listado paginado con scroll infinito |
| **Files Changed** | 15 |
| **Lines Changed** | +1490 |
| **Date** | 2026-07-31 |

---

## Summary

F06 cierra RF-12, RF-13 y RF-15, y deja RF-14 parcial por el hueco del
backend ya declarado. La pieza que carga la fase es `Pagina<T>`: el backend
responde `{data, total, page, limit}` **sin `lastPage`**, así que saber si
quedan páginas es cuenta del cliente — y hacerla mal produce un scroll que
nunca para de pedir, o una lista que se corta antes de mostrar todo.

Durante la fase aparecieron **dos violaciones de la regla de dependencias
entre features**, las dos cometidas por mí, y una prueba que verificaba el
andamiaje en vez del código.

---

## Findings Overview

| Severity | In Scope | Out of Scope |
| -------- | -------- | ------------ |
| 🔴 CRITICAL | 0 | 0 |
| 🟠 HIGH | 2 | 0 |
| 🟡 MEDIUM | 1 | 0 |
| 🟢 LOW | 0 | 0 |
| ℹ️ INFO | 1 | 0 |

---

## In Scope Findings

### 🟠 HIGH-001: `busqueda` importaba de `perfil` — dos veces *(corregido)*

**Domains:** [Architecture]
**Location:** `lib/features/busqueda/domain/`, `lib/features/busqueda/data/busqueda_dto.dart`

El rubro 3.3 lo marca como **BLOQUEANTE**: "Sin dependencias de importación
entre features. Si `citas` importa de `chat`, lo compartido sube a `core`."

Ocurrió en dos capas seguidas:

1. **Dominio.** El listado necesita `PerfilMedico`, que estaba en
   `features/perfil/domain/`.
2. **Datos.** Después de mover la entidad, el DTO seguía importando
   `perfil/data/perfil_dto.dart` para `MedicoDto`.

La segunda es la interesante: arreglé la capa de dominio y **volví a cometer
el mismo error una capa más abajo**, en el mismo archivo que estaba
escribiendo. Es exactamente el modo en que una arquitectura se erosiona — no
por una decisión mala, sino por resolver la parte visible del problema.

**Corrección:** `PerfilMedico` y `EstadoVerificacion` a `core/domain/medico.dart`;
`MedicoDto` y `EspecialidadDto` a `core/data/medico_dto.dart`. `perfil` los
re-exporta para que quien trabaje en perfiles no tenga que saber dónde
acabaron. `PerfilPaciente` **no** subió: solo lo usa un feature, y lo
compartido se comparte cuando hace falta, no por si acaso.

Vale para F08: `citas` va a necesitar `PerfilMedico` para resolver el nombre
del médico a partir del `idMedico` que devuelve la API. Ya está donde tiene
que estar.

---

### 🟠 HIGH-002: `copyWithPrevious` es API interna de Riverpod *(corregido)*

**Domains:** [Correctness]
**Location:** `lib/features/busqueda/presentation/providers/busqueda_provider.dart`

Para conservar la lista cuando falla la página siguiente usé
`AsyncError(...).copyWithPrevious(state)`. El analizador lo rechazó:
`invalid_use_of_internal_member`. Apoyarse en API interna de un paquete es
deuda que estalla en una actualización menor.

Pero el problema real era de modelo, no de API. Un `AsyncError` global
significa "todo falló", y acá **no todo falló**: las páginas 1 y 2 están
cargadas y el usuario las está leyendo. Cambiar la pantalla entera por un
mensaje de error le borraría la lista y el scroll por un fallo en la página 3.

**Corrección:** tipo `ListadoState` con la página cargada **y** un
`errorAlPaginar` opcional. La lista sigue en pantalla y el pie muestra el
mensaje con un botón "Cargar más". `reintentarPagina()` reintenta solo lo que
falló, sin recargar todo.

---

### 🟡 MEDIUM-001: Una prueba que verificaba el doble, no el código *(corregido)*

**Location:** `test/features/busqueda/busqueda_repository_test.dart`

La prueba "no deja pedir más de lo que el backend acepta" fallaba con
`Expected: 50, Actual: 999`. El recorte estaba en `BusquedaApi` — la clase que
el doble **reemplaza por completo**. La prueba nunca tocó esa línea.

Podría haberse ajustado la aserción para que pasara. Eso habría dejado la
regla sin cobertura y la prueba mintiendo.

**Corrección:** el recorte sube al repositorio, que es la superficie que usa
la app. Ahora la regla se aplica sin importar qué cliente HTTP haya debajo, y
la prueba verifica código real.

---

### ℹ️ INFO-001: RF-14 se cumple a medias, y está declarado

El backend expone `GET /doctors` con `page`, `limit` y `especialidadId`
únicamente. **No hay parámetro de texto** (F00, BACKEND_ISSUES.md #8).

Filtrar por nombre en el cliente sobre la página actual sería peor que no
ofrecerlo: daría resultados que dependen de en qué página está parado el
usuario. Se implementó el filtro por especialidad, que sí existe, y la matriz
dice ⚠️ con el enlace al hallazgo.

---

## Lo que sostiene la fase: `hayMas`

La heurística ingenua es "la página vino llena, entonces hay más". Falla en un
caso concreto y frecuente: **una última página exactamente llena**. Con 30
médicos y `limit=10`, la página 3 trae 10 elementos y la heurística pediría la
4 — recibiría vacío, y volvería a intentar en el siguiente scroll.

`hayMas` compara `pagina < totalPaginas`, con `totalPaginas` calculado desde
`total`. Hay una prueba dedicada a ese caso, que verifica primero que la
página está llena (`items.length == limite`) y después que `hayMas` es falso.

---

## Rubro aplicado — docs/REVIEW_GATE.md

| Sección | Resultado |
| --- | --- |
| 3.1 Seguridad | ✅ sin secretos; las tres rutas son públicas y no mandan token de más |
| 3.2 Corrección | ✅ **paginación real** (RF-15), nada de `limit: 1000` — el repositorio recorta a 50; `EstadoVerificacion.fromApi` falla ruidoso aunque sea un solo médico de la lista |
| 3.3 Arquitectura | ✅ tras corregir HIGH-001: ningún feature importa de otro |
| 3.4 UI y diseño | ✅ cero literales · chips de 48dp · `Semantics(selected:)` en el filtro |
| 3.5 Pruebas | ✅ 27 nuevas · camino feliz y de error por caso de uso |
| 3.6 Higiene | ✅ analyze en cero |

**Sobre la precarga:** el scroll pide la página siguiente a 400px del final,
no al tocar fondo. Con datos móviles lentos —el usuario que describe
`DESIGN_SYSTEM.md` §1— esperar al fondo deja mirando un spinner; adelantarse
una pantalla hace que la carga ocurra mientras todavía está leyendo.

**Sobre el catálogo con `keepAlive`:** son 10 registros que no cambian durante
la sesión. Volver a pedirlos cada vez que se abre el filtro es gastar datos en
algo que ya se tiene.

---

## Files Reviewed

| File | Findings |
| ---- | -------- |
| `lib/core/domain/medico.dart` · `lib/core/data/medico_dto.dart` | 1 (HIGH-001) |
| `lib/features/busqueda/presentation/providers/busqueda_provider.dart` | 1 (HIGH-002) |
| `test/features/busqueda/busqueda_repository_test.dart` | 1 (MEDIUM-001) |
| `lib/core/domain/pagina.dart` | 0 |
| `lib/features/busqueda/data/` (3) | 0 |
| `lib/features/busqueda/presentation/screens/busqueda_screen.dart` | 0 |
| `lib/features/perfil/` (ajuste de imports) | 0 |
| `test/core/domain/pagina_test.dart` | 0 |

---

## Estado de VERIFY

```
format      93 archivos, 0 cambios
codegen     build_runner OK
analyze     No issues found!     (--fatal-infos --fatal-warnings)
test        173 pruebas + 20 goldens
cobertura   79.6%  (minimo 70%)
VERIFY OK   exit 0
```

VERDICT: APPROVED
