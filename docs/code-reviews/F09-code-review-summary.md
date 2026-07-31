# Code Review: F09 — Historial clínico

**Verdict:** ✅ APPROVED

| | |
| - | - |
| **Branch** | `main` (staged) |
| **Title** | Consultas, recetas y signos vitales con forma canónica |
| **Files Changed** | 10 |
| **Lines Changed** | +1690 |
| **Date** | 2026-07-31 |

---

## Summary

F09 cierra RF-25, RF-26, RF-27 y RNF-06. Con esto **el frontend construible
está completo**: los 27 requisitos que tienen backend están cubiertos.

El hallazgo de la fase no es un bug: es que el backend guarda los signos
vitales en un **`jsonb` sin esquema**, y eso hace que el historial clínico se
degrade solo con el tiempo si nadie impone forma.

---

## Findings Overview

| Severity | In Scope | Out of Scope |
| -------- | -------- | ------------ |
| 🔴 CRITICAL | 0 | 0 |
| 🟠 HIGH | 1 | 0 |
| 🟡 MEDIUM | 0 | 0 |
| 🟢 LOW | 1 | 0 |
| ℹ️ INFO | 1 | 0 |

---

## In Scope Findings

### 🟠 HIGH-001: `signosVitales` es un `jsonb` sin validación

**Domains:** [Data Integrity]
**Location:** backend `consulta.entity.ts:30`, `create-consultation.dto.ts:40`

```ts
@Column({ name: 'signos_vitales', type: 'jsonb', nullable: true })
signosVitales: Record<string, unknown> | null;
```

El DTO solo valida `@IsObject()`. **Cualquier forma se acepta.** Un cliente
puede escribir `{"presion": "120/80"}` y otro `{"presionArterial": "120/80"}`,
y los dos quedan guardados.

Por qué importa más de lo que parece: el valor de un historial clínico está en
**comparar en el tiempo**. Si la presión de marzo está bajo una clave y la de
agosto bajo otra, no hay forma de ponerlas una al lado de la otra —ni en la
app, ni en una consulta SQL, ni en un informe. Y no falla nunca: se degrada en
silencio, y cuando alguien lo nota ya hay meses de datos inconsistentes.

**No es un bug del backend que se pueda "arreglar" desde acá**, y tampoco
justifica un issue: `jsonb` libre es una decisión defendible para un campo que
varía por especialidad.

**Lo que hace el front:** como el servidor no impone forma, **la impone la
app**. `SignosVitales` fija las claves canónicas —las del ejemplo del propio
spec— y las serializa siempre igual. Tres decisiones alrededor:

1. **Solo viajan las claves con valor.** Mandar `temperatura: null` dejaría
   basura permanente en el `jsonb`.
2. **Los números que llegan como texto se convierten.** Nada impide que otro
   cliente escriba `"78"`; leerlo como `null` perdería el dato.
3. **Las claves desconocidas se conservan y se muestran.** Si otra versión
   escribió `glicemia`, esconderla sería **ocultar un dato clínico que un
   médico anotó**. Se pinta con su clave cruda antes que desaparecer.

También corrige el contrato inferido: la clave es **`pulso`**, no
`frecuenciaCardiaca`.

---

### 🟢 LOW-001: Un parámetro de `DataField` que no existía *(corregido)*

**Location:** `lib/features/historial/presentation/screens/historial_screen.dart`

Escribí `DataField(etiquetaCorta: true, ...)` pensando en una variante
compacta para la grilla de vitales. Ese parámetro no existe.

Lo anoto porque el compilador lo atrapó de inmediato: es el tipo de error que
un componente bien tipado convierte en fallo de build en vez de en un widget
que ignora una propiedad en silencio.

---

### ℹ️ INFO-001: Registrar una consulta **completa la cita**

`POST /consultations` mueve la cita a `COMPLETADA` como efecto secundario.
Es la **única forma de alcanzar ese estado**: no hay endpoint de transición
(BACKEND_ISSUES.md #4).

O sea que "registrar la consulta" y "dar la cita por atendida" son la misma
acción, aunque la UI las presente como una sola cosa. El proveedor invalida el
historial al registrar, porque los listados que muestran esa cita quedaron
viejos.

Consecuencia para el médico: **no puede registrar la consulta antes de
atender** sin cerrar la cita, y no puede corregirla después —una consulta por
cita, repetir da 409—. Está documentado en el contrato.

---

## RNF-06 — cómo se cumple sin confiar en el backend

El rubro 3.1 lo marca BLOQUEANTE: *"Cada pantalla de historial clínico
verifica que el usuario sea el paciente titular o el médico tratante. La UI no
confía en que el back lo filtre."*

La forma más fuerte de cumplirlo no es verificar: es **hacer que el acceso
cruzado no se pueda expresar**.

```dart
final r = tipo == TipoUsuario.medico
    ? await repo.atendidas(pagina: pagina)
    : await repo.miHistorial(pagina: pagina);
```

Ninguna de las dos rutas acepta un id de paciente. No hay parámetro que
manipular, ni deep link que falsificar, ni bug de programación que pueda pedir
el historial de otro — porque no existe la llamada que lo pediría. El backend
además filtra por token, así que son dos capas independientes.

Hay dos pruebas que verifican **qué ruta se pidió** según el rol.

---

## Rubro aplicado — docs/REVIEW_GATE.md

| Sección | Resultado |
| --- | --- |
| 3.1 Seguridad | ✅ RNF-06 por construcción · el interceptor de logs ya redacta `diagnostico`, `tratamiento`, `recetas` y `signosVitales` desde F03 |
| 3.2 Corrección | ✅ fechas en UTC, pintadas con `AppTime` · 409 conserva el motivo del servidor |
| 3.3 Arquitectura | ✅ `historial` no importa de ningún feature |
| 3.4 UI y diseño | ✅ datos clínicos en `data` (mono tabular) · cero literales · vitales en `Wrap` que sobrevive texto ampliado |
| 3.5 Pruebas | ✅ 32 nuevas · camino feliz y de error por caso de uso |
| 3.6 Higiene | ✅ analyze en cero |

**Sobre la monoespaciada:** este es el bloque que más la justifica de toda la
app. `120/80`, `37.2 °C`, `78 lpm`, `500mg c/8h` — en columna y tabular se
comparan de un vistazo entre consultas, que es exactamente lo que un médico
hace al abrir un historial. Es el argumento de `DESIGN_SYSTEM.md` §4 llevado a
su caso de uso.

**Sobre las recetas en la misma llamada:** `CreateConsultationDto` acepta
`recetas[]`. Emitirlas después con `POST /consultations/:id/recetas` dejaría
una ventana —corta pero real— en la que la consulta existe **sin su receta**.
Si la segunda llamada falla, el paciente ve un diagnóstico sin tratamiento.

---

## Files Reviewed

| File | Findings |
| ---- | -------- |
| `lib/features/historial/domain/consulta.dart` | 1 (HIGH-001) |
| `lib/features/historial/presentation/screens/historial_screen.dart` | 1 (LOW-001) |
| `lib/features/historial/data/historial_api.dart` | 1 (INFO-001) |
| `lib/features/historial/data/historial_dto.dart` · `historial_repository.dart` | 0 |
| `lib/features/historial/presentation/providers/historial_provider.dart` | 0 |
| `test/features/historial/` (2) | 0 |
| `lib/core/router/app_router.dart` | 0 |

---

## Estado de VERIFY

```
format      142 archivos, 0 cambios
codegen     build_runner OK
analyze     No issues found!     (--fatal-infos --fatal-warnings)
test        318 pruebas + 20 goldens
cobertura   73.7%  (minimo 70%)
VERIFY OK   exit 0
```

VERDICT: APPROVED
