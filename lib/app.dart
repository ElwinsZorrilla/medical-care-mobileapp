import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/router/app_router.dart';

/// Raíz de la app.
///
/// El tema entra en F02, desde los tokens del design system. Acá queda el
/// mínimo para que `flutter run` levante y `verify.sh` tenga algo que probar.
class MedicareApp extends ConsumerWidget {
  const MedicareApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'MediCare',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      // RD: es-DO. El formato de fecha y hora del design system depende de
      // este locale (RNF-18).
      locale: const Locale('es', 'DO'),
      supportedLocales: const <Locale>[Locale('es', 'DO')],
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
