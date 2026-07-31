import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// Campo de formulario con rótulo en versalitas.
///
/// El foco se marca con filete `cielo` de 2px — visible siempre, también
/// con teclado físico. El error va debajo, en lenguaje llano y sin pedir
/// disculpas: dice qué pasó y qué hacer.
class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.label,
    this.controller,
    this.hint,
    this.error,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.autofocus = false,
    this.maxLines = 1,
    this.monoespaciado = false,
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;

  /// Nulo = sin error. El campo no se pinta de rojo mientras el usuario
  /// escribe; el error llega cuando hay algo que corregir.
  final String? error;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final bool autofocus;
  final int maxLines;

  /// Para documento, exequátur, dosis: identificadores y cifras van en mono.
  final bool monoespaciado;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final hayError = error != null;

    OutlineInputBorder borde(Color color, double ancho) => OutlineInputBorder(
      borderRadius: Radii.chip,
      borderSide: BorderSide(color: color, width: ancho),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label.toUpperCase(), style: text.label),
        const SizedBox(height: Space.xs),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          enabled: enabled,
          autofocus: autofocus,
          maxLines: obscure ? 1 : maxLines,
          style: monoespaciado ? text.data : text.body,
          cursorColor: colors.cielo,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: text.body.copyWith(color: colors.steel),
            filled: true,
            fillColor: colors.surface,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: Space.md,
              vertical: Space.md,
            ),
            // 48dp de alto útil aunque el campo sea de una sola línea.
            constraints: const BoxConstraints(minHeight: kTactilMinimo),
            enabledBorder: borde(
              hayError ? colors.granate : colors.filete,
              Strokes.filete,
            ),
            focusedBorder: borde(
              hayError ? colors.granate : colors.cielo,
              Strokes.foco,
            ),
            disabledBorder: borde(colors.filete, Strokes.filete),
            errorBorder: borde(colors.granate, Strokes.filete),
            focusedErrorBorder: borde(colors.granate, Strokes.foco),
          ),
        ),
        if (hayError) ...[
          const SizedBox(height: Space.xs),
          Text(error!, style: text.caption.copyWith(color: colors.granate)),
        ],
      ],
    );
  }
}
