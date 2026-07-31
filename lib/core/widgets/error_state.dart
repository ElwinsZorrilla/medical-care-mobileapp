import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'app_button.dart';

/// Pantalla de error.
///
/// **El error no pide disculpas y no es vago.** Dice qué pasó y qué hacer.
/// El mensaje llega ya redactado desde la capa de datos —en español, desde
/// el lado del usuario— porque la UI no traduce códigos HTTP.
class ErrorState extends StatelessWidget {
  const ErrorState({
    required this.mensaje,
    this.titulo,
    this.onReintentar,
    this.etiquetaReintentar = 'Reintentar',
    super.key,
  });

  /// Ya viene en lenguaje llano: "Ese turno ya lo tomaron. Elige otra hora."
  final String mensaje;
  final String? titulo;
  final VoidCallback? onReintentar;
  final String etiquetaReintentar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: Space.xxl,
              color: colors.granate,
              semanticLabel: 'Error',
            ),
            const SizedBox(height: Space.lg),
            if (titulo != null) ...[
              Text(titulo!, style: text.heading, textAlign: TextAlign.center),
              const SizedBox(height: Space.sm),
            ],
            Text(mensaje, style: text.body, textAlign: TextAlign.center),
            if (onReintentar != null) ...[
              const SizedBox(height: Space.xl),
              AppButton(
                label: etiquetaReintentar,
                onPressed: onReintentar,
                variant: AppButtonVariant.secundaria,
                expandido: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
