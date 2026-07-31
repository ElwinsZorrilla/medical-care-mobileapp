# Code Review: F03 — Capa de red

**Verdict:** ✅ APPROVED

| | |
| - | - |
| **Branch** | `main` (staged) |
| **Title** | Dio, interceptores, refresh single-flight, `Result`/`Failure` y almacén seguro |
| **Files Changed** | 11 |
| **Lines Changed** | +1180 |
| **Date** | 2026-07-31 |

---

## Summary

F03 entrega la capa de red completa: cliente Dio con timeouts, inyección de
Bearer, refresh *single-flight*, jerarquía sellada de `Failure` con su mapeo
desde `DioException`, `Result<T>` y `SecureStore` sobre Keystore/Keychain.

**Lo importante de esta fase no es el código que quedó, sino un bug que el
código tenía y la prueba encontró.** La primera implementación del
single-flight disparaba **cinco refresh para cinco 401 concurrentes** — el
escenario exacto que RF-04 existe para evitar. La prueba lo detectó antes del
primer commit.

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

### 🟠 HIGH-001: El single-flight no era single-flight *(corregido)*

**Domains:** [Correctness, Security]
**Location:** `lib/core/network/refresh_interceptor.dart`

`RefreshInterceptor` extiende `QueuedInterceptor`, que **serializa** los
`onError`. Con un `Completer` compartido como único mecanismo, la secuencia
real era:

```
401 #1 → _enVuelo == null → refresca → completa → libera _enVuelo
401 #2 → _enVuelo == null (el #1 ya terminó) → refresca otra vez
401 #3,4,5 → ídem
```

Cinco 401 en paralelo → **cinco refresh**. El `Completer` solo cubre las
peticiones que coinciden *en el tiempo*; con la cola de `QueuedInterceptor`
nunca coinciden.

Por qué importa más de lo que parece: aunque este backend no revoca el token
anterior (F00), cinco refresh en vuelo escriben `SecureStore` en orden
indeterminado y la app puede acabar guardando un par distinto del que tiene en
memoria. Y si el backend agregara revocación —que es lo que
`BACKEND_ISSUES.md` #3 pide— el mismo código expulsaría al usuario en cada
carga de pantalla.

**Corrección aplicada** — comprobar frescura del token antes de refrescar:

```dart
final usado = err.requestOptions.headers['Authorization'] as String?;
final guardado = await _store.leerAccessToken();
if (guardado != null && usado != 'Bearer $guardado') {
  // Alguien ya refrescó: reintentar, no refrescar.
  return handler.resolve(await _reintentar(err.requestOptions, guardado));
}
```

El `Completer` cubre las concurrentes; la comprobación de frescura cubre las
que llegan después. **Verificado: 5 peticiones → 1 refresh.**

---

### 🟢 LOW-001: El fake de las pruebas competía con la cadena real *(corregido)*

**Location:** `test/core/network/refresh_interceptor_test.dart`

El backend simulado estaba montado como `Interceptor` al final de la cadena.
Eso mete al doble *dentro* de lo que se quiere probar: el orden de
interceptores es precisamente lo que estas pruebas verifican, y un fake en esa
posición altera el objeto de estudio.

**Corrección:** el doble pasa a ser un `HttpClientAdapter`. La petición
recorre la cadena de interceptores **real** y solo se finge la salida a la
red. Con ese cambio aparecieron los fallos verdaderos, incluido HIGH-001.

---

### ℹ️ INFO-001: Un `ignore` con justificación

**Location:** `lib/core/network/refresh_interceptor.dart`

Se agregó `ignore_for_file: prefer_initializing_formals`. El lint sugiere
`required this._store`, que **no compila**: Dart no admite parámetros con
nombre privados, y los campos deben seguir siéndolo. La justificación está
escrita junto al `ignore`, como pide el rubro 3.6.

Es el único `ignore` del proyecto.

---

## Rubro aplicado — docs/REVIEW_GATE.md §3.1

Todos los puntos de seguridad son BLOQUEANTE. Estado:

| Punto | Estado |
| --- | --- |
| Sin secretos ni URLs en duro | ✅ todo por `Env` / `--dart-define` |
| Tokens en `flutter_secure_storage`, nunca `SharedPreferences` | ✅ `SecureStore` sobre Keystore/Keychain |
| Refresh single-flight | ✅ **verificado con prueba**, tras corregir HIGH-001 |
| Sin `print`/`debugPrint` con datos sensibles | ✅ `LoggingInterceptor` redacta 22 campos y 3 cabeceras, y solo corre en `kDebugMode` |
| `userId` desde el token | ✅ el front nunca lo manda; sale del JWT del lado servidor |
| Sin `badCertificateCallback` que devuelva `true` | ✅ no existe; `badCertificate` mapea a error explícito |

**Sobre la redacción de logs (RNF-06):** la lista cubre credenciales,
identidad y **campos clínicos** —diagnóstico, tratamiento, recetas, alergias,
tipo de sangre, signos vitales— y recorre el árbol JSON a cualquier
profundidad. Un diagnóstico en logcat es una fuga de historia clínica, no un
detalle de estilo.

### §3.2 Corrección

- ✅ **409 → `Conflicto`**, con `esTurnoTomado` para distinguir "alguien tomó
  el turno" de "modalidad equivocada". Los dos son 409 en este backend y
  piden reacciones opuestas: refrescar la grilla en el primero, corregir la
  selección en el segundo. Refrescar en el segundo haría perder al usuario lo
  que ya eligió sin arreglar nada.
- ✅ **400 tiene dos significados** y se separan: en `POST /appointments`
  significa "turno fuera de franja" (`TurnoInvalido`), en el resto es
  validación. Mapearlos igual pintaría un turno vencido como campo inválido.
- ✅ El parser aguanta `message` como **string y como arreglo**, y no exige la
  clave `error` — el 401 sin token no la trae.

### §3.5 Pruebas

30 pruebas nuevas: 9 de interceptores, 21 de mapeo. Las tres obligatorias de
la fase están cubiertas:

| Requisito del prompt | Prueba |
| --- | --- |
| 5 peticiones concurrentes con 401 → 1 refresh | ✅ con latencia simulada, para que la concurrencia sea real |
| Refresh que falla limpia la sesión | ✅ verifica borrado + callback |
| Cada código HTTP mapea a su `Failure` | ✅ 401/403/404/409/400/422/5xx + 4 tipos de timeout |

---

## Files Reviewed

| File | Findings |
| ---- | -------- |
| `lib/core/network/refresh_interceptor.dart` | 2 (HIGH-001, INFO-001) |
| `test/core/network/refresh_interceptor_test.dart` | 1 (LOW-001) |
| `lib/core/network/auth_interceptor.dart` | 0 |
| `lib/core/network/logging_interceptor.dart` | 0 |
| `lib/core/network/dio_client.dart` | 0 |
| `lib/core/network/result.dart` | 0 |
| `lib/core/error/failure.dart` · `failure_mapper.dart` | 0 |
| `lib/core/storage/secure_store.dart` | 0 |
| `test/core/error/failure_mapper_test.dart` | 0 |

---

## Estado de VERIFY

```
format      41 archivos, 0 cambios
codegen     build_runner OK
analyze     No issues found!     (--fatal-infos --fatal-warnings)
test        68 pruebas + 20 goldens
cobertura   86.1%  (minimo 70%)
VERIFY OK   exit 0
```

VERDICT: APPROVED
