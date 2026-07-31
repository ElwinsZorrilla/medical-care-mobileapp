import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/config/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Falla acá y no en la primera petición: un error de configuración tiene
  // que verse como error de configuración (RNF-04).
  Env.validar();

  // Sin esto, formatear una fecha con locale es_DO lanza en runtime, no en
  // compilación. Es el punto 8 de docs/VERIFICATION.md, el único no
  // cosmético de esa lista.
  await initializeDateFormatting('es_DO');

  runApp(const ProviderScope(child: MedicareApp()));
}
