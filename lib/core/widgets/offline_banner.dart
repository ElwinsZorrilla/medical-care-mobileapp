import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// Aviso de que no hay conexión.
///
/// Va anclado arriba, no como toast: el estado "sin conexión" dura, y un
/// mensaje que se desvanece obliga al usuario a recordarlo. Usa `ambar`
/// —atención— y no `granate`: perder señal no es un error del usuario ni
/// una operación destruida.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({
    this.mensaje = 'Sin conexión. Estás viendo lo último que se cargó.',
    this.onReintentar,
    super.key,
  });

  final String mensaje;
  final VoidCallback? onReintentar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;

    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: Space.lg,
          vertical: Space.md,
        ),
        color: colors.ambar.withValues(alpha: 0.12),
        child: Row(
          children: [
            Icon(
              Icons.cloud_off,
              size: Space.xl,
              color: colors.ambar,
              semanticLabel: 'Sin conexión',
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Text(
                mensaje,
                style: text.caption.copyWith(color: colors.ink),
              ),
            ),
            if (onReintentar != null) ...[
              const SizedBox(width: Space.sm),
              // 48dp de área táctil aunque el texto sea corto.
              InkWell(
                onTap: onReintentar,
                borderRadius: Radii.chip,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: kTactilMinimo,
                    minHeight: kTactilMinimo,
                  ),
                  child: Center(
                    child: Text(
                      'Reintentar',
                      style: text.caption.copyWith(
                        color: colors.cielo,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
