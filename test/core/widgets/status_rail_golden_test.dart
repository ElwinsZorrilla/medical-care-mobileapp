import 'dart:io';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicare/core/domain/cita_estado.dart';
import 'package:medicare/core/theme/app_theme.dart';
import 'package:medicare/core/theme/tokens.dart';
import 'package:medicare/core/widgets/widgets.dart';

/// Goldens del riel de estado — el elemento firma del sistema.
///
/// 5 estados × 2 densidades × 2 temas = **20 combinaciones**, repartidas en
/// 4 archivos de golden (uno por densidad y tema, con los 5 estados dentro).
///
/// Es el componente que más carga visual soporta y el que más fácil se
/// rompe sin que nadie lo note: cambiar un padding o el color de un estado
/// no dispara ninguna prueba de lógica. Estos goldens son la única red.
void main() {
  Widget contenido() => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('Dra. Alejandra Peña'),
      SizedBox(height: Space.xs),
      Text('Cardiología · Presencial'),
      SizedBox(height: Space.md),
      Row(
        children: [
          Expanded(
            child: DataField(label: 'Fecha', value: '04 AGO'),
          ),
          Expanded(
            child: DataField(label: 'Hora', value: '08:30'),
          ),
        ],
      ),
    ],
  );

  /// Alchemist 0.14 no recibe el tema por parámetro: se inyecta en el árbol.
  /// Envolver acá deja cada golden autocontenido, sin depender de una
  /// configuración global que otra prueba podría cambiar.
  Widget conTema(ThemeData tema, Widget child) => Theme(
    data: tema,
    child: ColoredBox(
      color: tema.extension<AppPalette>()!.paper,
      child: Padding(padding: const EdgeInsets.all(Space.md), child: child),
    ),
  );

  // Linux es la plataforma canónica de los goldens.
  //
  // Un golden es un rasterizado, y rasterizar no es identico bit a bit entre
  // sistemas: los generados en Windows fallan en el Linux del contenedor por
  // 66 pixeles (0.02%) de antialiasing, sin que nada este roto. Comprobado en
  // el primer build de F14, y es el motivo por el que el propio repo de
  // Flutter corre sus goldens en una sola plataforma.
  //
  // Antes se intentaba resolver desactivando los goldens de plataforma en
  // `flutter_test_config.dart` y confiando en que los de CI fueran portables.
  // No lo son: el glifo de estado se dibuja con la fuente de iconos y su borde
  // cae distinto segun el motor.
  //
  // La alternativa —tolerar un porcentaje de diferencia— haria pasar tambien
  // los cambios chicos de verdad: mover un padding 2px o cambiar el color de
  // un estado entra dentro del mismo margen. Se prefiere que el golden sea
  // exacto y corra en un solo sitio, que es ademas donde corre el CI.
  //
  //   Regenerar:  docker build --target goldens -o test/core/widgets/goldens \
  //                 -f docker/Dockerfile .
  group(
    'goldens del riel de estado',
    () {
      for (final densidad in AppDensity.values) {
        for (final brillo in Brightness.values) {
          final nombreTema = brillo == Brightness.light ? 'claro' : 'oscuro';

          goldenTest(
            'StatusRail · ${densidad.name} · $nombreTema',
            fileName: 'status_rail_${densidad.name}_$nombreTema',
            // El tema se construye acá dentro y no en `main()`: `google_fonts`
            // consulta el asset bundle, y en el cuerpo de main todavía no hay
            // binding de pruebas inicializado.
            builder: () {
              final tema = brillo == Brightness.light
                  ? AppTheme.light(density: densidad)
                  : AppTheme.dark(density: densidad);

              return GoldenTestGroup(
                columns: 1,
                children: [
                  for (final estado in CitaEstado.values)
                    GoldenTestScenario(
                      name: estado.apiValue,
                      child: conTema(
                        tema,
                        SizedBox(
                          width: 360,
                          child: StatusRail(estado: estado, child: contenido()),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        }
      }
    },
    skip: Platform.isLinux
        ? null
        : 'Los goldens son canonicos en Linux; '
              'regenerarlos con: docker build --target goldens '
              '-o test/core/widgets/goldens -f docker/Dockerfile .',
  );
}
