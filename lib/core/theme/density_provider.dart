import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'tokens.dart';

part 'density_provider.g.dart';

/// Densidad activa de la interfaz.
///
/// Se resuelve por el rol del usuario: paciente → [AppDensity.patient],
/// médico → [AppDensity.clinician]. Son dos audiencias con necesidades
/// opuestas — el paciente usa la app 3–4 veces al mes y necesita aire; el
/// médico abre la agenda 20 veces al día entre consultas y necesita ver más
/// filas por pantalla.
///
/// Mientras no exista sesión (F04 trae el rol), queda en `patient`: es la
/// densidad de las pantallas públicas —login y registro—, donde el aire
/// ayuda y nadie está escaneando una agenda.
@Riverpod(keepAlive: true)
class DensidadUi extends _$DensidadUi {
  @override
  AppDensity build() => AppDensity.patient;

  /// La llama el guard de sesión cuando se conoce el rol (F04).
  void establecer(AppDensity densidad) => state = densidad;
}
