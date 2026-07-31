import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';

/// Estados de una cita — RF-23.
///
/// Los strings son los que devuelve el backend, verificados en F00 contra el
/// enum real de `cita.entity.ts`. Ver docs/API_CONTRACT.md §7.
///
/// **`CONFIRMADA` y `NO_ASISTIO` existen en la base pero hoy son
/// inalcanzables:** el backend no expone endpoint de transición de estado
/// (BACKEND_ISSUES.md #4). Se mapean igual porque están en el enum y en la
/// BD, y porque el día que exista el endpoint la app no debe romperse.
enum CitaEstado {
  pendiente('PENDIENTE'),
  confirmada('CONFIRMADA'),
  cancelada('CANCELADA'),
  completada('COMPLETADA'),
  noAsistio('NO_ASISTIO');

  const CitaEstado(this.apiValue);

  /// Valor exacto tal cual viaja en el JSON.
  final String apiValue;

  /// Convierte el string del backend al enum.
  ///
  /// Falla ruidoso a propósito. Un estado nuevo del lado servidor tiene que
  /// romper acá, en el mapeo, y no colarse como un default silencioso que
  /// pinta la cita con el color equivocado. Una cita "cancelada" mostrada
  /// como "pendiente" hace que alguien se presente a una consulta que no
  /// existe.
  static CitaEstado fromApi(String value) {
    for (final estado in CitaEstado.values) {
      if (estado.apiValue == value) return estado;
    }
    throw ArgumentError.value(
      value,
      'value',
      'Estado de cita desconocido. Valores esperados: '
          '${CitaEstado.values.map((e) => e.apiValue).join(', ')}',
    );
  }

  /// Etiqueta para el usuario, en versalitas dentro del riel.
  String get etiqueta => switch (this) {
    CitaEstado.pendiente => 'PENDIENTE',
    CitaEstado.confirmada => 'CONFIRMADA',
    CitaEstado.cancelada => 'CANCELADA',
    CitaEstado.completada => 'COMPLETADA',
    CitaEstado.noAsistio => 'NO ASISTIÓ',
  };

  /// Glifo de respaldo para daltonismo.
  ///
  /// No es adorno. El color solo nunca comunica estado: siempre color +
  /// glifo + etiqueta.
  String get glifo => switch (this) {
    CitaEstado.pendiente => '○',
    CitaEstado.confirmada => '●',
    CitaEstado.completada => '✓',
    CitaEstado.cancelada => '╱',
    CitaEstado.noAsistio => '✕',
  };

  /// Color del riel según el brillo del tema.
  Color color(Brightness brightness) {
    final oscuro = brightness == Brightness.dark;
    return switch (this) {
      CitaEstado.pendiente => oscuro ? AppColors.ambarDark : AppColors.ambar,
      CitaEstado.confirmada => oscuro ? AppColors.verdeDark : AppColors.verde,
      CitaEstado.completada => oscuro ? AppColors.steelDark : AppColors.steel,
      CitaEstado.cancelada =>
        oscuro ? AppColors.granateDark : AppColors.granate,
      // No asistió: el mismo granate al 60%, un grado por debajo de cancelada.
      CitaEstado.noAsistio =>
        (oscuro ? AppColors.granateDark : AppColors.granate).withValues(
          alpha: 0.6,
        ),
    };
  }

  /// Si el estado da la cita por terminada, sin acciones posibles.
  bool get esTerminal =>
      this == CitaEstado.cancelada ||
      this == CitaEstado.completada ||
      this == CitaEstado.noAsistio;
}
