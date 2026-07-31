import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'app_button.dart';

/// Pantalla vacía.
///
/// **El vacío invita.** Cada pantalla vacía lleva una acción, no un dibujo
/// triste. "Aún no tienes citas. Busca un médico para empezar." — no "No hay
/// datos".
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.titulo,
    this.detalle,
    this.icono,
    this.accion,
    this.onAccion,
    super.key,
  });

  final String titulo;
  final String? detalle;
  final IconData? icono;

  /// Etiqueta de la acción. Si va, `onAccion` también.
  final String? accion;
  final VoidCallback? onAccion;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (icono != null) ...[
              Icon(icono, size: Space.xxl, color: colors.steel),
              const SizedBox(height: Space.lg),
            ],
            Text(titulo, style: text.heading, textAlign: TextAlign.center),
            if (detalle != null) ...[
              const SizedBox(height: Space.sm),
              Text(detalle!, style: text.caption, textAlign: TextAlign.center),
            ],
            if (accion != null && onAccion != null) ...[
              const SizedBox(height: Space.xl),
              AppButton(label: accion!, onPressed: onAccion, expandido: false),
            ],
          ],
        ),
      ),
    );
  }
}
