import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:google_fonts/google_fonts.dart';

/// Configuración que envuelve **todas** las pruebas del proyecto.
///
/// Dos cosas, las dos necesarias para que los goldens sean deterministas:
///
/// 1. **`allowRuntimeFetching = false`.** `google_fonts` baja las tipografías
///    por HTTP la primera vez. En un test no hay red, así que cada golden
///    fallaba con "unable to load font Archivo-SemiBold". Apagado, el texto
///    se dibuja con la fuente de respaldo y la prueba deja de depender de
///    una descarga.
///
/// 2. **Solo goldens de CI.** Alchemist genera dos variantes: una por
///    plataforma (Windows, macOS…) y otra "CI" que bloquea el render de
///    texto. Las de plataforma dependen del renderizador de fuentes de cada
///    máquina, así que se desactivan.
///
///    **Eso no alcanzó.** Se creyó que la variante de CI era portable y no lo
///    es: en F14 los goldens hechos en Windows fallaron en el Linux del
///    contenedor por 66 píxeles (0.02%). El texto sí está bloqueado, pero el
///    glifo de estado se dibuja con la fuente de iconos y su borde cae
///    distinto según el motor. Por eso los goldens ahora se saltan fuera de
///    Linux — ver `test/core/widgets/status_rail_golden_test.dart`.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;

  return AlchemistConfig.runWithConfig(
    config: const AlchemistConfig(
      platformGoldensConfig: PlatformGoldensConfig(enabled: false),
    ),
    run: testMain,
  );
}
