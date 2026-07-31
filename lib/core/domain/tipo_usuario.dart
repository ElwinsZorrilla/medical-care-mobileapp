import '../theme/tokens.dart';

/// Rol del usuario — RF-01, RF-06.
///
/// Los strings son los del enum real del backend (`usuario.entity.ts`),
/// verificados en F00.
///
/// `ADMIN` existe en la base pero el registro público lo rechaza: solo se
/// admite `PACIENTE` o `MEDICO`. Se mapea igual porque un usuario admin
/// podría iniciar sesión y la app no debe romperse al leer su token.
enum TipoUsuario {
  paciente('PACIENTE'),
  medico('MEDICO'),
  admin('ADMIN');

  const TipoUsuario(this.apiValue);

  final String apiValue;

  /// Falla ruidoso ante un rol desconocido.
  ///
  /// Un rol no mapeado que cayera a `paciente` por defecto le daría a un
  /// médico la interfaz equivocada —o peor, le abriría a alguien pantallas
  /// que no le tocan. El guard de rutas depende de que esto sea exacto.
  static TipoUsuario fromApi(String value) {
    for (final tipo in TipoUsuario.values) {
      if (tipo.apiValue == value) return tipo;
    }
    throw ArgumentError.value(
      value,
      'value',
      'Rol desconocido. Esperados: '
          '${TipoUsuario.values.map((t) => t.apiValue).join(', ')}',
    );
  }

  /// Los dos que admite `POST /auth/register`.
  static const registrables = [TipoUsuario.paciente, TipoUsuario.medico];

  String get etiqueta => switch (this) {
    TipoUsuario.paciente => 'Paciente',
    TipoUsuario.medico => 'Médico',
    TipoUsuario.admin => 'Administrador',
  };

  /// Densidad de interfaz que le corresponde.
  ///
  /// El médico abre la agenda 20 veces al día y necesita ver más filas por
  /// pantalla; el paciente entra 3–4 veces al mes y necesita aire.
  AppDensity get densidad => switch (this) {
    TipoUsuario.medico => AppDensity.clinician,
    TipoUsuario.paciente || TipoUsuario.admin => AppDensity.patient,
  };
}
