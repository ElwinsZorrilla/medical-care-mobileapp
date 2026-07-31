import '../../../core/domain/fecha_calendario.dart';

// `PerfilMedico` y `EstadoVerificacion` viven en `core/domain/medico.dart`:
// los comparten `perfil`, `busqueda` y `citas`, y un feature no puede
// importar de otro. Se re-exportan acá para que quien trabaje en perfiles no
// tenga que saber dónde acabaron.
export '../../../core/domain/medico.dart' show EstadoVerificacion, PerfilMedico;

/// Perfil de paciente — RF-07.
///
/// A diferencia del médico, este no sube a `core/`: solo lo usa este feature.
/// Lo compartido se comparte cuando hace falta, no por si acaso.
class PerfilPaciente {
  const PerfilPaciente({
    required this.idPaciente,
    required this.idUsuario,
    required this.nombres,
    required this.apellidos,
    required this.documentoIdentidad,
    required this.fechaNacimiento,
    this.sexo,
    this.direccion,
    this.tipoSangre,
    this.alergias,
    this.seguroMedico,
  });

  final int idPaciente;
  final int idUsuario;
  final String nombres;
  final String apellidos;

  /// Identificador legal. El backend lo fija al crear el perfil y
  /// `UpdatePatientDto` no lo incluye: **no es editable**.
  final String documentoIdentidad;

  /// Fecha de calendario, no un instante. Ver [FechaCalendario].
  final FechaCalendario fechaNacimiento;

  final String? sexo;
  final String? direccion;
  final String? tipoSangre;

  /// El backend la guarda como **texto libre**, no como lista.
  final String? alergias;

  final String? seguroMedico;

  String get nombreCompleto => '$nombres $apellidos';
}
