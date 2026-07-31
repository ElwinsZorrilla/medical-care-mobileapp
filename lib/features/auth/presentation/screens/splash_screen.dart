import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/tokens.dart';

/// Pantalla de arranque.
///
/// Solo se ve mientras se resuelve si hay sesión guardada. Es corta a
/// propósito: no es una marca ni una animación de bienvenida, es el estado
/// "todavía no sé" hecho visible para que el guard no tenga que adivinar.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;

    return Scaffold(
      backgroundColor: colors.paper,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('MediCare', style: text.display),
            const SizedBox(height: Space.xl),
            SizedBox(
              width: Space.xl,
              height: Space.xl,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(colors.verde),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
