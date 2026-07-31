import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/time/app_time.dart';
import 'gallery.dart';

/// Punto de entrada solo para revisión visual del sistema de diseño.
///
///     flutter run -t lib/dev/gallery_main.dart
///
/// No pasa por `Env.validar()` a propósito: la galería no habla con el
/// backend, y exigirle `API_BASE_URL` para mirar un botón sería fricción sin
/// beneficio.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Mismo ajuste que en `main.dart`: la galería es la herramienta con la que
  // se aprueba el diseño, así que tiene que renderizar con las tipografías
  // empaquetadas y no con lo que se baje por red. Si divergiera de
  // producción, la revisión visual estaría aprobando otra cosa.
  GoogleFonts.config.allowRuntimeFetching = false;
  await AppTime.init();
  runApp(const GalleryApp());
}
