import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// Rótulo en versalitas sobre un valor en monoespaciada.
///
/// La traducción digital del campo rotulado del formulario clínico:
///
/// ```
/// TIPO DE SANGRE
/// O+
/// ```
///
/// El valor va en `data` (IBM Plex Mono, tabular) porque en esta app los
/// números **son** el contenido. Con mono se alinean en columna y se
/// comparan de un vistazo: `120/80`, `08:30`, `500mg c/8h`.
class DataField extends StatelessWidget {
  const DataField({
    required this.label,
    required this.value,
    this.destacado = false,
    this.color,
    super.key,
  });

  /// Se pinta en versalitas. Se pasa en lenguaje normal: el widget lo
  /// convierte, para que quien lo use no tenga que gritar en el código.
  final String label;
  final String value;

  /// Usa la escala `dataLg` — para la cifra que manda en la pantalla.
  final bool destacado;

  /// Solo para valores con semántica de estado. En un dato clínico normal
  /// se deja nulo: el color no decora.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final estiloValor = destacado ? text.dataLg : text.data;

    return Semantics(
      label: label,
      value: value,
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: text.label,
            // Con textScale 2.0 un rótulo largo debe envolver, no recortarse.
            softWrap: true,
          ),
          const SizedBox(height: Space.xs),
          Text(
            value,
            style: color == null
                ? estiloValor
                : estiloValor.copyWith(color: color),
            softWrap: true,
          ),
        ],
      ),
    );
  }
}
