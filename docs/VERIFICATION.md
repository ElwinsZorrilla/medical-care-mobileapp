# Puntos a verificar en el primer compilado

El código de `seed/` fue escrito **sin compilador disponible**. La lógica y la
estructura están razonadas, pero hay APIs de Flutter que cambiaron de nombre
entre versiones y no pude confirmar cuál aplica a tu SDK.

Esto no es una lista de "puede que haya bugs". Es la lista **exacta y completa**
de lo que no pude verificar. Lo demás está escrito contra APIs estables.

**Resolvelo en F02, en los primeros 10 minutos.** Corré `flutter analyze` sobre
el seed antes de construir nada encima.

| # | Archivo | Símbolo | Riesgo | Si falla |
|---|---|---|---|---|
| 1 | `app_theme.dart` | `import 'dart:ui' show FontFeature` | `FontFeature` puede estar ya re-exportado por `painting.dart`. Si lo está, el lint `unnecessary_import` dispara y con `--fatal-infos` rompe el build. | Borrá el import |
| 2 | `app_theme.dart` | `CardThemeData` | Se llamaba `CardTheme` antes de Flutter 3.27. | Renombrá a `CardTheme` |
| 3 | `app_theme.dart` | `FadeForwardsPageTransitionsBuilder` | Llegó en Flutter 3.29 con el spec M3 actualizado. | `ZoomPageTransitionsBuilder` |
| 4 | `app_theme.dart` | `ColorScheme.surfaceContainerLowest` | Flutter 3.22+. | `background` (deprecado) o quitalo |
| 5 | `app_theme.dart` | `DividerThemeData(...)` sin `const` | Puede pedir `const`. | Agregá `const` |
| 6 | `tokens.dart` | `MediaQuery.disableAnimationsOf` | Flutter 3.10+. Debería estar. | `MediaQuery.of(context).disableAnimations` |
| 7 | `app_time.dart` | `timezone/data/latest_10y.dart` | El paquete `timezone` también expone `data/latest.dart`. La variante `10y` pesa menos. | Usá `latest.dart` |
| 8 | `app_time.dart` | `DateFormat` con locale `es_DO` | Requiere `initializeDateFormatting('es_DO')` de `intl` en `main()` antes de usarse. | Agregá la llamada en `main()` |

**Punto 8 es el único que no es cosmético.** Si no inicializás el locale, el
formateo de fechas tira excepción en runtime, no en compilación. Va en `main()`
junto a `AppTime.init()`.
