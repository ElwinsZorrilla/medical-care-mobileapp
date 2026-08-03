/// Estado de la sesion de video — RF-37.
///
/// Solo avanza: `PROGRAMADA -> EN_CURSO -> FINALIZADA`, con `FALLIDA` como
/// salida desde las dos primeras. El backend rechaza los retrocesos con 409;
/// aca se replica la tabla para no ofrecer un boton que ya se sabe que falla.
enum EstadoVideollamada {
  programada('PROGRAMADA', 'Programada'),
  enCurso('EN_CURSO', 'En curso'),
  finalizada('FINALIZADA', 'Finalizada'),
  fallida('FALLIDA', 'Fallida');

  const EstadoVideollamada(this.api, this.etiqueta);

  final String api;
  final String etiqueta;

  static EstadoVideollamada? desdeApi(String v) {
    for (final e in values) {
      if (e.api == v) return e;
    }
    return null;
  }

  /// A donde se puede mover desde aqui. Misma tabla que `video.service.ts`:
  /// si divergieran, la app ofreceria acciones que dan 409.
  Set<EstadoVideollamada> get siguientes => switch (this) {
    programada => const {enCurso, fallida},
    enCurso => const {finalizada, fallida},
    finalizada || fallida => const {},
  };

  bool puedeIrA(EstadoVideollamada otro) => siguientes.contains(otro);

  /// Si tiene sentido entrar a la sala. Una llamada terminada o fallida ya no
  /// lleva a ningun lado.
  bool get admiteEntrada => this == programada || this == enCurso;

  /// Si ya no se mueve mas.
  bool get esTerminal => siguientes.isEmpty;
}

/// Sala de video de una cita — RF-35, RF-36.
class Videollamada {
  const Videollamada({
    required this.id,
    required this.idCita,
    required this.proveedor,
    required this.urlSala,
    required this.estado,
    this.inicioRealUtc,
    this.finRealUtc,
  });

  final int id;
  final int idCita;

  /// `JITSI`. El backend genera el nombre de sala con 16 bytes aleatorios:
  /// uno predecible dejaria entrar a una consulta ajena probando numeros.
  final String proveedor;

  /// **Es un secreto**: cualquiera con esta URL entra a la consulta. Por eso
  /// `redactor.dart` la clasifica como credencial y no se pinta como texto.
  final String urlSala;

  final EstadoVideollamada estado;

  /// Cuando se marco `EN_CURSO`. Nulo mientras nadie ha entrado.
  final DateTime? inicioRealUtc;

  /// Cuando se marco `FINALIZADA` o `FALLIDA`.
  final DateTime? finRealUtc;

  /// Duracion real de la consulta, si ya empezo y termino.
  Duration? get duracion => inicioRealUtc == null || finRealUtc == null
      ? null
      : finRealUtc!.difference(inicioRealUtc!);
}
