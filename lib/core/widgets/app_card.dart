import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// Superficie con filete, sin sombra.
///
/// La jerarquía se construye con filetes de 1px `ink` @ 12%, no con
/// elevación. *La estructura es información*: un filete dice "esto es un
/// límite"; una sombra difusa no dice nada.
///
/// El padding sale de la densidad activa — 16 para paciente, 12 para médico.
class AppCard extends StatelessWidget {
  const AppCard({required this.child, this.onTap, this.padding, super.key});

  final Widget child;
  final VoidCallback? onTap;

  /// Si se omite, se usa el padding de la densidad. Pasarlo explícito es
  /// para casos donde el contenido ya trae su propio margen (una imagen a
  /// sangre, por ejemplo).
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final density = context.density;

    final contenido = Padding(
      padding: padding ?? EdgeInsets.all(density.paddingTarjeta),
      child: child,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: Radii.card,
        border: Border.all(color: colors.filete, width: Strokes.filete),
      ),
      child: onTap == null
          ? contenido
          : Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                borderRadius: Radii.card,
                // El área táctil cubre la tarjeta entera, que siempre pasa
                // de 48dp; el mínimo se garantiza igual por si el contenido
                // es una sola línea.
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: kTactilMinimo),
                  child: contenido,
                ),
              ),
            ),
    );
  }
}
