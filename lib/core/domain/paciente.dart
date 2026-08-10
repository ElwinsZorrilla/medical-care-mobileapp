/// Lo mínimo de un paciente para pintar su nombre — RF-24.
///
/// No es `PerfilPaciente` (en `features/perfil/domain/perfil.dart`): ese
/// trae los datos clínicos del perfil propio y el backend no los expone por
/// esta ruta. Este vive en `core/` porque lo necesita `citas` (agenda del
/// médico) — igual que `PerfilMedico` está en `core/` porque lo necesitan
/// `perfil`, `busqueda` y `citas`.
class PacienteBasico {
  const PacienteBasico({
    required this.idPaciente,
    required this.idUsuario,
    required this.nombres,
    required this.apellidos,
  });

  final int idPaciente;
  final int idUsuario;
  final String nombres;
  final String apellidos;

  String get nombreCompleto => '$nombres $apellidos';
}
