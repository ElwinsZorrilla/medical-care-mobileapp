import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// Intención de un botón. Decide color, no forma.
enum AppButtonVariant {
  /// Acción principal de la pantalla. Una sola por pantalla.
  primaria,

  /// Acción secundaria: filete, sin relleno.
  secundaria,

  /// Cancelar, eliminar. Usa `granate`, que es sagrado: si aparece rojo,
  /// algo pasó.
  destructiva,
}

/// Botón del sistema.
///
/// Alto mínimo 48dp, presión que escala a 0.98 en 90ms, y etiqueta que **no
/// cambia de nombre en el camino**: si dice "Reservar cita", la confirmación
/// dice "Cita reservada" — nunca "Solicitud procesada".
class AppButton extends StatefulWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primaria,
    this.icon,
    this.cargando = false,
    this.expandido = true,
    super.key,
  });

  final String label;

  /// Nulo deshabilita el botón.
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;

  /// Muestra progreso y bloquea la pulsación, sin cambiar el ancho: el
  /// botón no debe saltar de tamaño al enviarse.
  final bool cargando;
  final bool expandido;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _presionado = false;

  bool get _habilitado => widget.onPressed != null && !widget.cargando;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;

    final colorAccion = switch (widget.variant) {
      AppButtonVariant.primaria => colors.verde,
      AppButtonVariant.secundaria => colors.ink,
      AppButtonVariant.destructiva => colors.granate,
    };
    final relleno = widget.variant == AppButtonVariant.secundaria
        ? Colors.transparent
        : colorAccion;
    final colorTexto = widget.variant == AppButtonVariant.secundaria
        ? colors.ink
        : colors.surface;

    final opacidad = _habilitado ? 1.0 : 0.4;

    return Semantics(
      button: true,
      enabled: _habilitado,
      label: widget.label,
      child: GestureDetector(
        onTapDown: _habilitado
            ? (_) => setState(() => _presionado = true)
            : null,
        onTapUp: _habilitado
            ? (_) => setState(() => _presionado = false)
            : null,
        onTapCancel: _habilitado
            ? () => setState(() => _presionado = false)
            : null,
        onTap: _habilitado ? widget.onPressed : null,
        child: AnimatedScale(
          scale: _presionado ? Motion.escalaPresion : 1.0,
          duration: Motion.of(context, Motion.presion),
          curve: Motion.curvaPresion,
          child: Opacity(
            opacity: opacidad,
            child: Container(
              width: widget.expandido ? double.infinity : null,
              constraints: const BoxConstraints(minHeight: kTactilMinimo),
              padding: const EdgeInsets.symmetric(
                horizontal: Space.lg,
                vertical: Space.md,
              ),
              decoration: BoxDecoration(
                color: relleno,
                borderRadius: Radii.chip,
                border: Border.all(
                  color: widget.variant == AppButtonVariant.secundaria
                      ? colors.filete
                      : colorAccion,
                  width: Strokes.filete,
                ),
              ),
              child: Row(
                mainAxisSize: widget.expandido
                    ? MainAxisSize.max
                    : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.cargando) ...[
                    SizedBox(
                      width: Space.lg,
                      height: Space.lg,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(colorTexto),
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                  ] else if (widget.icon != null) ...[
                    Icon(widget.icon, size: Space.xl, color: colorTexto),
                    const SizedBox(width: Space.sm),
                  ],
                  Flexible(
                    child: Text(
                      widget.label,
                      style: text.bodyStrong.copyWith(color: colorTexto),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
