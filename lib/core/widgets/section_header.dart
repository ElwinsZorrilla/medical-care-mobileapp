import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// Encabezado de sección, con el filete estructural a la izquierda.
///
/// Es la traducción del margen reglado de la hoja clínica: una línea que
/// ancla el bloque y dice dónde empieza. Barato y más informativo que una
/// sombra.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.titulo,
    this.accion,
    this.onAccion,
    this.conFilete = true,
    super.key,
  });

  final String titulo;
  final String? accion;
  final VoidCallback? onAccion;
  final bool conFilete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;

    return Semantics(
      header: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (conFilete) ...[
            Container(width: Strokes.riel, height: Space.xl, color: colors.ink),
            const SizedBox(width: Space.md),
          ],
          Expanded(child: Text(titulo, style: text.heading)),
          if (accion != null && onAccion != null)
            InkWell(
              onTap: onAccion,
              borderRadius: Radii.chip,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: kTactilMinimo,
                  minHeight: kTactilMinimo,
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.sm),
                    child: Text(
                      accion!,
                      style: text.caption.copyWith(
                        color: colors.cielo,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
