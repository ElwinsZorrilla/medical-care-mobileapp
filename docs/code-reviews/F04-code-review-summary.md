# Code Review: F04 — Autenticación

**Verdict:** ✅ APPROVED

| | |
| - | - |
| **Branch** | `main` (staged) |
| **Title** | Registro, login, guard por rol y los tres estados de sesión |
| **Files Changed** | 16 |
| **Lines Changed** | +1560 |
| **Date** | 2026-07-31 |

---

## Summary

F04 cierra RF-01, RF-02, RF-03 y RF-06, y deja RF-05 parcial por un hueco del
backend ya declarado. Es el **primer módulo con las tres capas separadas** —
`domain/` sin JSON ni Dio, `data/` traduciendo, `presentation/` solo pintando—
y por tanto la primera prueba real de que la arquitectura de `ARCHITECTURE.md`
se sostiene.

La decisión que carga la fase es el **estado de sesión con tres valores** en
vez de dos.

---

## Findings Overview

| Severity | In Scope | Out of Scope |
| -------- | -------- | ------------ |
| 🔴 CRITICAL | 0 | 0 |
| 🟠 HIGH | 0 | 0 |
| 🟡 MEDIUM | 1 | 0 |
| 🟢 LOW | 2 | 0 |
| ℹ️ INFO | 1 | 0 |

---

## In Scope Findings

### 🟡 MEDIUM-001: F04 rompió las pruebas de F01 *(corregido)*

**Domains:** [Test Quality]
**Location:** `test/app_test.dart`

Al conectar el guard, arrancar la app pasó a leer `SecureStore`, que habla por
canal nativo. En un test de widget no hay plataforma que responda, así que las
dos pruebas de F01 —que llevaban dos fases en verde— empezaron a fallar.

Vale anotarlo porque es el modo de falla típico de una suite que envejece mal:
una fase nueva rompe pruebas viejas, alguien las marca como `skip` "por
ahora", y la red deja de existir sin que nadie lo decida.

**Corrección:** `secureStoreProvider` se sobreescribe con un doble en memoria
vía `ProviderScope.overrides`. De paso se agregó una tercera prueba que
verifica el comportamiento nuevo: sin sesión guardada, el guard lleva al login.

---

### 🟢 LOW-001: El fake de la API no ejercitaba nada *(corregido)*

**Location:** `test/features/auth/auth_repository_test.dart`

La primera versión declaraba campos para simular respuestas y **no
sobreescribía ningún método**: `login`, `registrar` y `yo` seguían siendo los
reales. El analizador lo delató con cinco `unused_element_parameter`.

El efecto era peor que el warning: los casos de uso de RF-01 y RF-03 se
quedaban **sin prueba de camino feliz**, que el rubro 3.5 marca como
BLOQUEANTE.

**Corrección:** el doble extiende `AuthApi` y sobreescribe los tres métodos.
Con eso entraron 10 pruebas nuevas, incluidas las de camino feliz que
faltaban.

---

### 🟢 LOW-002: Finder ambiguo por una decisión de copia correcta *(corregido)*

**Location:** `test/features/auth/pantallas_auth_test.dart`

`find.text('Entrar')` encontraba dos widgets: el título de la pantalla y la
etiqueta del botón. No es un error de la UI — es §8 del design system
funcionando: *el nombre de la acción no cambia en el camino*. Cambiar el
título a "Iniciar sesión" para desambiguar habría empeorado el producto para
simplificar la prueba.

**Corrección:** el test apunta a `find.widgetWithText(AppButton, 'Entrar')`.
Se arregla la prueba, no el diseño.

---

### ℹ️ INFO-001: RF-05 queda parcial, y está declarado

**Location:** `AuthRepository.cerrarSesion`, `docs/TRACEABILITY.md`

Cerrar sesión solo borra los tokens del dispositivo. El backend no expone
`/auth/logout` ni revoca refresh tokens, así que el token sigue siendo válido
en el servidor **7 días**. No hay nada que el front pueda hacer.

La fila de RF-05 dice ⚠️ con el enlace al hallazgo. Un requisito faltante
declarado vale más que uno escondido.

---

## Lo que sostiene la fase: tres estados de sesión

`Sesion` es `desconocida | autenticada | anónima`. Con dos habría bastado para
compilar, y la app parpadearía:

```
arranque → estado "anónimo" (aún no se leyó SecureStore, que es asíncrono)
         → el guard redirige a /login
         → llega el token
         → el guard redirige a la agenda
```

El usuario ve un flash del login **cada vez que abre la app**. Con el tercer
estado el guard distingue "todavía no sé" de "no hay sesión" y se queda en el
splash hasta saberlo. Hay prueba explícita de que
`desconocida.estaResuelta != anonima.estaResuelta`.

---

## Rubro aplicado — docs/REVIEW_GATE.md

| Sección | Resultado |
| --- | --- |
| 3.1 Seguridad | ✅ tokens solo en `SecureStore`; el 401 de login no revela si el correo existe —el backend responde igual en los dos casos y el mensaje del front respeta esa ambigüedad—; ningún `userId` sale de un formulario |
| 3.2 Corrección | ✅ `TipoUsuario.fromApi` falla ruidoso; un rol no mapeado devuelve `ErrorInesperado` en vez de dejar entrar con la interfaz equivocada |
| 3.3 Arquitectura | ✅ `domain/` sin `json`/`dio`/Flutter · `presentation/` no toca `Response` · `DioException` muere en el repositorio |
| 3.4 UI y diseño | ✅ cero literales; error anclado y no toast; `liveRegion` para lectores de pantalla |
| 3.5 Pruebas | ✅ camino feliz **y** de error por caso de uso · 10 pruebas de pantalla · cobertura 81.6% |
| 3.6 Higiene | ✅ analyze en cero, cero atribución |

**Sobre 3.1 y la validación local:** el formulario valida antes de salir a la
red, con prueba de que `api.intentos == 0` cuando los datos están mal. No
reemplaza la validación del backend —que es la autoridad— pero evita hacer
esperar al usuario en datos móviles lentos por algo que se sabe al instante.

**Sobre `forbidNonWhitelisted`:** hay una prueba que verifica que el cuerpo del
login tiene **exactamente** dos claves. El backend devuelve 400 ante un campo
de más, así que un DTO que crezca sin querer rompería el login en producción
sin fallar en compilación.

---

## Files Reviewed

| File | Findings |
| ---- | -------- |
| `test/app_test.dart` | 1 (MEDIUM-001) |
| `test/features/auth/auth_repository_test.dart` | 1 (LOW-001) |
| `test/features/auth/pantallas_auth_test.dart` | 1 (LOW-002) |
| `lib/features/auth/data/auth_repository.dart` | 1 (INFO-001) |
| `lib/features/auth/domain/usuario.dart` | 0 |
| `lib/features/auth/data/auth_dto.dart` · `auth_api.dart` | 0 |
| `lib/features/auth/presentation/providers/auth_provider.dart` | 0 |
| `lib/features/auth/presentation/screens/` (3) | 0 |
| `lib/core/router/app_router.dart` | 0 |
| `lib/core/domain/tipo_usuario.dart` | 0 |

---

## Estado de VERIFY

```
format      58 archivos, 0 cambios
codegen     build_runner OK
analyze     No issues found!     (--fatal-infos --fatal-warnings)
test        102 pruebas + 20 goldens
cobertura   81.6%  (minimo 70%)
VERIFY OK   exit 0
```

VERDICT: APPROVED
