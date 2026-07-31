import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/time/app_time.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Las tipografías van empaquetadas en el APK (google_fonts/NOTICE.md). Sin
  // esto, google_fonts las bajaría por HTTP en el primer arranque: en datos
  // móviles lentos la app se vería con la fuente de respaldo, y sin conexión
  // no llegaría nunca. En false, además, un peso que falte falla ruidoso en
  // vez de irse a la red en silencio.
  GoogleFonts.config.allowRuntimeFetching = false;

  // Falla acá y no en la primera petición: un error de configuración tiene
  // que verse como error de configuración (RNF-04).
  Env.validar();

  // Prepara los símbolos del locale es_DO. Sin esto, formatear una fecha
  // lanza en runtime y no en compilación — punto 8 de docs/VERIFICATION.md,
  // el único no cosmético de esa lista.
  await AppTime.init();

  runApp(const ProviderScope(child: MedicareApp()));
}
