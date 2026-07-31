import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// Bloque de carga.
///
/// El skeleton sí, porque **comunica estado**: dice "acá va a haber algo, de
/// este tamaño". Lo que no va es el shimmer decorativo — el exceso de
/// animación es de las señales más fuertes de interfaz hecha sin criterio.
///
/// La pulsación es sobria y se apaga sola si el usuario pidió menos
/// movimiento: en ese caso queda un bloque quieto, que sigue comunicando.
class LoadingSkeleton extends StatefulWidget {
  const LoadingSkeleton({
    this.width,
    this.height = Space.lg,
    this.radius = Radii.chip,
    super.key,
  });

  /// Nulo ocupa el ancho disponible.
  final double? width;
  final double height;
  final BorderRadius radius;

  /// Varias líneas apiladas, la última más corta — como un párrafo real.
  static Widget lineas(
    BuildContext context, {
    int cantidad = 3,
    double alto = Space.md,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < cantidad; i++) ...[
        if (i > 0) const SizedBox(height: Space.sm),
        FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: i == cantidad - 1 ? 0.6 : 1.0,
          child: LoadingSkeleton(height: alto),
        ),
      ],
    ],
  );

  @override
  State<LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Motion.skeleton,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Si el sistema pide menos movimiento, el bloque se queda quieto.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 0.5;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: colors.steel.withValues(
              alpha: 0.12 + (_controller.value * 0.10),
            ),
            borderRadius: widget.radius,
          ),
        ),
      ),
    );
  }
}
