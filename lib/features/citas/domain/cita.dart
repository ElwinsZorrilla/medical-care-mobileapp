import '../../../core/domain/cita_estado.dart';
import '../../../core/domain/modalidad.dart';
import '../../../core/error/failure.dart';

/// Una cita — RF-19 a RF-24.
///
/// Los ids son planos porque así los devuelve el backend: no hay médico ni
/// paciente anidado. El nombre se resuelve aparte, con `MedicoDirectorio`.
class Cita {
  const Cita({
    required this.id,
    required this.idPaciente,
    required this.idMedico,
    required this.inicioUtc,
    required this.finUtc,
    required this.modalidad,
    required this.estado,
    required this.creadaUtc,
    this.idCentro,
    this.idDisponibilidad,
    this.motivoConsulta,
  });

  final int id;
  final int idPaciente;
  final int idMedico;

  /// Instante absoluto. Se pinta con `AppTime`, nunca con `.toLocal()`.
  final DateTime inicioUtc;
  final DateTime finUtc;

  final ModalidadCita modalidad;
  final CitaEstado estado;
  final DateTime creadaUtc;
  final int? idCentro;
  final int? idDisponibilidad;
  final String? motivoConsulta;

  Duration get duracion => finUtc.difference(inicioUtc);

  /// Si todavía admite acciones del usuario.
  bool get esCancelable => !estado.esTerminal;

  /// Si ya pasó, comparado contra el instante que se le pase.
  ///
  /// Recibe el "ahora" en vez de leerlo del reloj: así la lógica es
  /// determinista en pruebas y no se cuela un `DateTime.now()` suelto.
  bool yaPaso(DateTime ahoraUtc) => finUtc.isBefore(ahoraUtc);
}

/// Qué pedirle al servidor al reservar — RF-19, RF-21.
///
/// `fecha` y `horaInicio` van los dos aunque sea redundante: así lo exige
/// `CreateAppointmentDto` del backend.
class SolicitudReserva {
  const SolicitudReserva({
    required this.idMedico,
    required this.fecha,
    required this.horaInicioApi,
    required this.modalidad,
    this.motivoConsulta,
  });

  final int idMedico;

  /// `YYYY-MM-DD` en calendario de Santo Domingo.
  final String fecha;

  /// El string ISO **exacto** que devolvió el endpoint de turnos.
  ///
  /// Se manda tal cual vino. Reconstruirlo desde un `DateTime` puede diferir
  /// en los milisegundos y el backend no encontraría el turno.
  final String horaInicioApi;

  final ModalidadCita modalidad;
  final String? motivoConsulta;
}

/// Qué hacer cuando la reserva falla — RF-20, RNF-10.
///
/// El backend usa **409 para tres cosas distintas** y no expone un código de
/// error propio, así que la única forma de distinguirlas es el texto.
///
/// La clasificación vive acá y no en `core/error/failure.dart` porque
/// `Failure` es una jerarquía **sellada**: agregarle una variante desde este
/// feature no compila, y forzarla a `core` metería conocimiento de reservas
/// en un lugar que el resto de la app comparte. `reaccionA` traduce un
/// `Failure` genérico a la decisión, una sola vez.
enum ReaccionAConflicto {
  /// "Ese turno ya fue reservado" — alguien ganó la carrera.
  ///
  /// **Se refresca la grilla y se avisa.** Nunca se reintenta en silencio:
  /// el turno ya no existe, reintentar solo produciría el mismo 409 y el
  /// usuario vería la app pensando sin entender por qué.
  refrescarTurnos,

  /// "Ese turno solo admite modalidad X" — la selección es corregible.
  ///
  /// Refrescar acá sería contraproducente: le borraría al usuario el turno
  /// que eligió sin arreglar nada. Lo que falla es la modalidad.
  corregirModalidad,

  /// Cualquier otro conflicto: se muestra el mensaje del servidor.
  mostrarMensaje;

  /// Decide qué hacer ante un fallo de reserva.
  ///
  /// Se resuelve en un solo lugar para que ninguna pantalla vuelva a
  /// interpretar el texto del servidor por su cuenta.
  static ReaccionAConflicto para(Failure fallo) => switch (fallo) {
    // 400 en la ruta de reserva significa "ese turno no existe en ninguna
    // franja": la grilla que ve el usuario quedo vieja.
    TurnoInvalido() => ReaccionAConflicto.refrescarTurnos,
    Conflicto(:final esTurnoTomado) when esTurnoTomado =>
      ReaccionAConflicto.refrescarTurnos,
    Conflicto(:final mensajeServidor)
        when mensajeServidor.toLowerCase().contains('modalidad') =>
      ReaccionAConflicto.corregirModalidad,
    _ => ReaccionAConflicto.mostrarMensaje,
  };
}
