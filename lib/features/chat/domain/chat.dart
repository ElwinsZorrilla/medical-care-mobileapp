/// Conversacion entre un paciente y un medico — RF-31.
///
/// El backend la crea de forma **idempotente**: pedir dos veces la
/// conversacion con el mismo medico devuelve la misma, no una nueva. Por eso
/// abrir el chat desde dos sitios distintos no duplica hilos.
class Conversacion {
  const Conversacion({
    required this.id,
    required this.idPaciente,
    required this.idMedico,
    required this.noLeidos,
    this.ultimoMensajeUtc,
  });

  final int id;
  final int idPaciente;
  final int idMedico;

  /// Cuantos mensajes de la contraparte estan sin leer — RF-33.
  final int noLeidos;

  /// Instante del ultimo mensaje. Nulo en una conversacion recien abierta.
  final DateTime? ultimoMensajeUtc;

  bool get tieneSinLeer => noLeidos > 0;
}

/// Un mensaje — RF-31, RF-33, RF-34.
class Mensaje {
  const Mensaje({
    required this.id,
    required this.idConversacion,
    required this.idRemitente,
    required this.contenido,
    required this.enviadoUtc,
    required this.leido,
    this.urlAdjunto,
  });

  final int id;
  final int idConversacion;

  /// Id de **usuario**, no de paciente ni de medico. Es con lo que se decide
  /// de que lado de la burbuja va el mensaje.
  final int idRemitente;

  final String contenido;

  /// RF-34 — adjunto.
  ///
  /// Es una **referencia**, no un archivo: el backend acepta el campo pero no
  /// expone ningun endpoint de subida (verificado en F11). Hoy solo se puede
  /// mostrar lo que ya exista del lado servidor.
  final String? urlAdjunto;

  final DateTime enviadoUtc;

  /// RF-33 — si la contraparte ya lo leyo.
  final bool leido;

  bool esMio(int idUsuario) => idRemitente == idUsuario;
}
