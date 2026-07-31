import 'package:flutter/material.dart';

import '../domain/cita_estado.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// El elemento firma del sistema — DESIGN_SYSTEM.md §6.
///
/// Una regla vertical de 4px en el borde izquierdo cuyo color **es** el
/// estado. Encima, el rótulo en versalitas con su glifo.
///
/// Por qué carga con la audacia del sistema:
///
/// 1. El estado de la cita es el dato de mayor frecuencia de consulta de
///    toda la app. Merece el canal visual más fuerte.
/// 2. Escanea vertical: en la agenda del médico, 20 rieles en columna se
///    leen como una sola imagen — dónde está lo ámbar, dónde lo rojo.
/// 3. Es la pestaña del expediente. Cita literal del artefacto físico.
/// 4. Cuesta un `Container` de 4px. Cero imágenes, cero costo de render.
///
/// Todo lo demás en la pantalla se mantiene callado para que el riel cargue.
class StatusRail extends StatelessWidget {
  const StatusRail({
    required this.estado,
    required this.child,
    this.mostrarEtiqueta = true,
    super.key,
  });

  final CitaEstado estado;
  final Widget child;

  /// En listas muy densas el rótulo puede omitirse: el color y el glifo
  /// siguen comunicando, y la etiqueta va en el `Semantics`.
  final bool mostrarEtiqueta;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final density = context.density;
    final colorEstado = estado.color(context.brightness);

    return Semantics(
      label: 'Estado de la cita: ${estado.etiqueta}',
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: Radii.card,
          border: Border.all(color: colors.filete, width: Strokes.filete),
        ),
        child: ClipRRect(
          borderRadius: Radii.card,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // El riel. Anima al cambiar de estado: 240ms easeOutCubic,
                // o 0ms si el usuario pidió menos movimiento.
                AnimatedContainer(
                  duration: Motion.of(context, Motion.riel),
                  curve: Motion.curvaRiel,
                  width: Strokes.riel,
                  color: colorEstado,
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(density.paddingTarjeta),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (mostrarEtiqueta) ...[
                          // El glifo no es adorno: es el respaldo para
                          // daltonismo. El color solo nunca comunica estado.
                          Row(
                            children: [
                              Text(
                                estado.glifo,
                                style: text.label.copyWith(color: colorEstado),
                              ),
                              const SizedBox(width: Space.xs),
                              Flexible(
                                child: Text(
                                  estado.etiqueta,
                                  style: text.label.copyWith(
                                    color: colorEstado,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: density.separacionLista),
                        ],
                        child,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
