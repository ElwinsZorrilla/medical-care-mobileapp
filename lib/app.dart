import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/density_provider.dart';

/// Raíz de la app.
class MedicareApp extends ConsumerWidget {
  const MedicareApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(appRouterProvider);
    final densidad = ref.watch(densidadUiProvider);

    return MaterialApp.router(
      title: 'MediCare',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      // Claro y oscuro salen de los mismos tokens; el oscuro no es una
      // paleta aparte. La densidad la decide el rol del usuario.
      theme: AppTheme.light(density: densidad),
      darkTheme: AppTheme.dark(density: densidad),
      themeMode: ThemeMode.system,
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
