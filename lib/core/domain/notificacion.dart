import '../time/app_time.dart';

/// Por que llego una notificacion — RF-28.
///
/// El backend emite estos cinco valores. `fromApi` **falla ruidoso** ante uno
/// desconocido en vez de caer a un default: pintar un icono generico donde
/// deberia decir "tu cita se cancelo" es peor que no pintar nada.
enum TipoNotificacion {
  recordatorio('RECORDATORIO'),
  confirmacion('CONFIRMACION'),
  cancelacion('CANCELACION'),
  mensaje('MENSAJE'),
  sistema('SISTEMA');

  const TipoNotificacion(this.apiValue);

  final String apiValue;

  static TipoNotificacion fromApi(String valor) => values.firstWhere(
    (t) => t.apiValue == valor,
    orElse: () =>
        throw ArgumentError('Tipo de notificacion desconocido: $valor'),
  );
}

/// Una notificacion de la bandeja — RF-28, RF-29, RF-30.
class Notificacion {
  const Notificacion({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.cuerpo,
    required this.leida,
    required this.enviadaUtc,
    this.idCita,
  });

  final int id;
  final TipoNotificacion tipo;
  final String titulo;
  final String cuerpo;
  final bool leida;

  /// Instante absoluto. Se pinta con `AppTime`, nunca con la zona del
  /// dispositivo (RNF-18).
  final DateTime enviadaUtc;

  /// La cita que la origino, si la hubo. Es lo que permite tocar la
  /// notificacion y llegar a la cita.
  final int? idCita;

  /// Cuanto hace que llego, en lenguaje llano.
  ///
  /// Una bandeja con veinte fechas absolutas obliga a hacer la resta mental.
  /// "hace 5 min" se lee de un vistazo, que es como se mira una bandeja.
  String antiguedadDesde(DateTime ahoraUtc) {
    final d = ahoraUtc.difference(enviadaUtc);
    if (d.inMinutes < 1) return 'ahora';
    if (d.inMinutes < 60) return 'hace ${d.inMinutes} min';
    if (d.inHours < 24) return 'hace ${d.inHours} h';
    if (d.inDays < 7) return 'hace ${d.inDays} d';
    return AppTime.fechaCorta(enviadaUtc);
  }
}
