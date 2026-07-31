# Arquitectura

## Decisiones y su costo

| Decisión | Por qué | Qué se paga |
|---|---|---|
| **Feature-first**, no layer-first | RNF-11 pide un módulo por dominio. Además, cuando toque F08 (citas) todo lo de citas está en una carpeta. | Algo de duplicación entre features |
| **Riverpod** con generador | Compile-safe, testeable sin `BuildContext`, se burla fácil en pruebas | Curva de `ref` y codegen |
| **freezed + json_serializable** | Modelos inmutables, `copyWith`, unions para estados. Un DTO escrito a mano se desincroniza del back. | `build_runner` en cada cambio |
| **go_router** | Guard por rol declarativo (RF-06), deep links para la sala de video (RF-36) | Config verbosa |
| **dio** | Interceptores reales — el refresh single-flight no se hace decente con `http` | Peso extra |
| **Result/Failure**, no excepciones | El error de red es un valor esperado, no algo excepcional. Obliga a manejarlo. | Más ceremonia |

---

## Estructura

```
lib/
├── main.dart
├── app.dart                      # MaterialApp.router, theme, locale
│
├── core/                         # transversal. NO importa de features/
│   ├── config/env.dart           # String.fromEnvironment, validado al arrancar
│   ├── error/                    # Failure, mapeo DioException → Failure
│   ├── network/
│   │   ├── dio_client.dart
│   │   ├── auth_interceptor.dart # inyecta Bearer
│   │   ├── refresh_interceptor.dart  # single-flight
│   │   └── result.dart
│   ├── router/                   # go_router + redirect por rol
│   ├── storage/secure_store.dart
│   ├── theme/                    # tokens.dart, app_theme.dart
│   ├── time/app_time.dart        # RNF-18 — única frontera UTC↔local
│   ├── widgets/                  # StatusRail, DataField, AppScaffold, estados
│   └── l10n/                     # ARB, es-DO
│
└── features/
    └── <dominio>/
        ├── data/
        │   ├── <x>_api.dart      # solo HTTP
        │   ├── <x>_dto.dart      # freezed + json
        │   └── <x>_repository.dart   # DTO → entidad, Failure
        ├── domain/
        │   ├── <x>.dart          # entidad, sin json ni dio
        │   └── usecases/
        └── presentation/
            ├── providers/
            ├── screens/
            └── widgets/
```

Dominios: `auth` · `perfil` · `especialidades` · `agenda` · `citas` ·
`historial` · `notificaciones` · `chat` · `video`

**Regla de importación, verificada en el gate:**

```
presentation → domain → data          ✅ (dentro del mismo feature)
feature A    → feature B              ❌ lo compartido sube a core/
core         → features/              ❌ nunca
presentation → dio / Response         ❌ nunca
```

---

## Reglas de capa

**`domain/` no conoce el mundo exterior.** Sin `json`, sin `dio`, sin Flutter.
Si una entidad de dominio necesita `fromJson`, está en la capa equivocada.

**`data/` traduce.** El DTO refleja lo que el back manda, con sus nombres
feos y todo. El repositorio lo convierte a entidad limpia. Si el back renombra
un campo, cambia un archivo.

**`presentation/` no decide.** No arma URLs, no parsea, no calcula reglas de
negocio. Pide y pinta.

---

## Autenticación (RF-03, RF-04)

El punto donde más implementaciones se rompen:

```
petición → 401
   ↓
¿ya hay un refresh en vuelo?
   ├── sí  → esperar ese mismo Future, reintentar con el token nuevo
   └── no  → tomar el lock, refrescar, liberar, reintentar
              └── ¿el refresh también dio 401? → limpiar sesión, ir a login
```

Sin el lock, cinco peticiones paralelas disparan cinco refresh; el back invalida
el token anterior en cada uno y el usuario sale expulsado. Se implementa con un
`Completer<String>?` compartido, no con un booleano.

**Nunca** se reintenta el endpoint de refresh. Un 401 ahí significa sesión
muerta, punto.

---

## Manejo de errores

```dart
sealed class Failure {
  const Failure(this.mensaje);
  final String mensaje;   // ya en español, listo para pintar
}

final class SinConexion    extends Failure { ... }
final class NoAutorizado   extends Failure { ... }
final class Conflicto      extends Failure { ... }  // 409 — RF-20
final class Validacion     extends Failure { ... }  // 422, campo a campo
final class ErrorServidor  extends Failure { ... }
```

El mensaje se arma en la capa de datos, en español y desde el lado del usuario.
La UI no traduce códigos HTTP — si un widget tiene un `switch` sobre
`statusCode`, la abstracción se rompió.

---

## Dependencias

**Resueltas en F01** contra Flutter 3.44.5 / Dart 3.12.2. Ver `pubspec.yaml`.

```yaml
dependencies:
  flutter_riverpod: ^3.1.0
  riverpod_annotation: ^4.0.0
  go_router: ^17.3.0
  dio: ^5.11.0
  freezed_annotation: ^3.1.0
  json_annotation: ^4.9.0
  flutter_secure_storage: ^10.3.1
  google_fonts: ^8.2.0
  intl: ^0.20.2                    # lo fija flutter_localizations
  timezone: ^0.11.1                # RNF-18
  cached_network_image: ^3.4.1

dev_dependencies:
  flutter_lints: ^6.0.0
  custom_lint: ^0.8.1
  riverpod_lint: ^3.1.0
  build_runner: ^2.15.1
  freezed: ^3.2.3
  json_serializable: ^6.11.2
  riverpod_generator: ^4.0.0+1
  mocktail: ^1.0.5
  alchemist: ^0.12.1               # goldens (F02)
```

**Las versiones del plan original estaban varios majors atrás y no sirven.**
No es cuestión de preferencia: Riverpod 2.x y Freezed 2.x no soportan Dart
3.12. Lo que cambia para quien escriba código:

- **Freezed 3** — las clases se declaran `abstract class X with _$X`, no
  `@freezed class X with _$X`. Las uniones cambiaron de sintaxis.
- **Riverpod 3** — `Ref` dejó de ser genérico: es `Ref`, no `Ref<T>`.
- **go_router 17** — tres majores desde el 14 que asumía el diseño; revisar
  `redirect` y `refreshListenable` antes de escribir los guards de F04.
- **`golden_toolkit` está descontinuado.** Se reemplaza por `alchemist`.

**Ausentes a propósito:** `socket_io_client`, `firebase_messaging`,
`flutter_local_notifications` y `file_picker`. F00 verificó que el backend no
tiene realtime, push ni video — no son "confirmar en F00", ya se confirmó que
no existen. Ver `BACKEND_ISSUES.md` #5.

---

## Estrategia de pruebas (RNF-14)

| Nivel | Qué cubre | Herramienta |
|---|---|---|
| Unitaria | Casos de uso, mapeo DTO→entidad, `AppTime` | `mocktail` |
| Widget | Cada pantalla con condicionales, los 4 estados | `ProviderScope` con overrides |
| Golden | `StatusRail` en los 5 estados, ambas densidades, claro y oscuro | `golden_toolkit` |
| Integración | Login → buscar médico → reservar → cancelar | `integration_test` |

**La prueba que no se salta:** una que falle si un `DateTime` local se serializa
a un payload. Es la regla más fácil de violar y la más cara de detectar en
producción.
