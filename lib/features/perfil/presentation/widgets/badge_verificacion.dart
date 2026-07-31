import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/tokens.dart';
import '../../domain/perfil.dart';

/// Estado de verificación del médico — RF-11.
///
/// El requisito pide que sea **visible y explicado**. Un badge suelto que
/// diga "PENDIENTE" es visible pero no explica nada: el médico no sabe si
/// tiene que hacer algo, ni si puede trabajar mientras tanto. Por eso el
/// bloque lleva la explicación al lado, no escondida detrás de un ícono de
/// ayuda.
class BadgeVerificacion extends StatelessWidget {
  const BadgeVerificacion({required this.estado, super.key});

  final EstadoVerificacion estado;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final color = estado.color(context.brightness);

    return Semantics(
      container: true,
      label: 'Verificación: ${estado.etiqueta}. ${estado.explicacion}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: Radii.card,
          border: Border.all(color: color, width: Strokes.filete),
        ),
        child: Padding(
          padding: EdgeInsets.all(context.density.paddingTarjeta),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  // Color + glifo + etiqueta: el estado nunca se comunica
                  // solo por color.
                  Text(estado.glifo, style: text.label.copyWith(color: color)),
                  const SizedBox(width: Space.xs),
                  Text(
                    estado.etiqueta,
                    style: text.label.copyWith(color: color),
                  ),
                ],
              ),
              const SizedBox(height: Space.sm),
              Text(
                estado.explicacion,
                style: text.caption.copyWith(color: colors.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
