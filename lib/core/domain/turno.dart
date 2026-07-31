import 'modalidad.dart';

/// Turno libre de un médico — RF-18.
///
/// Vive en `core/` y no en `agenda/` porque lo necesitan los dos lados de la
/// misma moneda: `agenda` lo genera a partir de las franjas del médico y
/// `citas` lo consume para reservar. Un feature no importa de otro (rubro
/// 3.3), así que lo compartido sube acá.
///
/// A diferencia de la franja, esto **sí** es un instante absoluto: el backend
/// lo devuelve en ISO-8601 UTC (`2026-08-17T12:00:00.000Z`). Se pinta con
/// `AppTime.hora` y se manda de vuelta **tal cual vino**, sin reconstruirlo.
class Turno {
  const Turno({
    required this.idDisponibilidad,
    required this.inicioUtc,
    required this.finUtc,
    required this.modalidad,
    required this.inicioApi,
  });

  final int idDisponibilidad;
  final DateTime inicioUtc;
  final DateTime finUtc;
  final ModalidadFranja modalidad;

  /// El string exacto que devolvió el servidor.
  ///
  /// Se conserva a propósito: al reservar hay que mandar **este** valor, no
  /// uno reconstruido desde `inicioUtc`. Un `toIso8601String()` puede diferir
  /// en los milisegundos o en el sufijo y el backend no encontraría el turno.
  final String inicioApi;

  Duration get duracion => finUtc.difference(inicioUtc);
}
