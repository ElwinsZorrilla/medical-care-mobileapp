import '../../../core/domain/modalidad.dart';

/// Día de la semana como lo numera el backend.
///
/// El servidor lo calcula con `getUTCDay()` de JavaScript, así que
/// **0 es domingo y 1 es lunes** (verificado en F00 con el ejemplo del README
/// del backend, donde `diaSemana: 1` es lunes).
///
/// Es el tipo de detalle que no falla en compilación y produce una agenda
/// corrida un día entero: el médico configura "lunes" y sus pacientes ven
/// turnos el domingo.
enum DiaSemana {
  domingo(0, 'Domingo', 'DOM'),
  lunes(1, 'Lunes', 'LUN'),
  martes(2, 'Martes', 'MAR'),
  miercoles(3, 'Miércoles', 'MIÉ'),
  jueves(4, 'Jueves', 'JUE'),
  viernes(5, 'Viernes', 'VIE'),
  sabado(6, 'Sábado', 'SÁB');

  const DiaSemana(this.apiValue, this.etiqueta, this.abreviatura);

  /// 0 = domingo, como `getUTCDay()`.
  final int apiValue;
  final String etiqueta;
  final String abreviatura;

  static DiaSemana fromApi(int value) {
    for (final d in DiaSemana.values) {
      if (d.apiValue == value) return d;
    }
    throw ArgumentError.value(
      value,
      'value',
      'Día de semana fuera de rango. Esperado 0 (domingo) a 6 (sábado).',
    );
  }

  /// Convierte desde `DateTime.weekday` de Dart, que numera **al revés**:
  /// 1 = lunes … 7 = domingo.
  ///
  /// Pasar un `weekday` de Dart directo al backend es un desfase de un día
  /// para todos los días menos el domingo, que se va a la otra punta.
  static DiaSemana desdeWeekdayDart(int weekday) =>
      fromApi(weekday == DateTime.sunday ? 0 : weekday);
}

/// Hora de pared, sin fecha — `"08:30"`.
///
/// El backend guarda las franjas así: strings `HH:mm` en **hora local de
/// Santo Domingo**, sin zona ni fecha. No son instantes y no pasan por
/// `AppTime`; el servidor las combina con la fecha pedida al calcular turnos.
class HoraDelDia implements Comparable<HoraDelDia> {
  const HoraDelDia(this.hora, this.minuto);

  final int hora;
  final int minuto;

  static HoraDelDia? parse(String? valor) {
    if (valor == null || valor.length < 4) return null;
    final partes = valor.split(':');
    if (partes.length < 2) return null;
    final h = int.tryParse(partes[0]);
    final m = int.tryParse(partes[1]);
    if (h == null || m == null) return null;
    if (h < 0 || h > 23 || m < 0 || m > 59) return null;
    return HoraDelDia(h, m);
  }

  /// `"08:30"` — el formato que espera el backend y el que se pinta.
  String toApi() =>
      '${hora.toString().padLeft(2, '0')}:${minuto.toString().padLeft(2, '0')}';

  int get enMinutos => hora * 60 + minuto;

  @override
  int compareTo(HoraDelDia other) => enMinutos.compareTo(other.enMinutos);

  bool operator <(HoraDelDia other) => enMinutos < other.enMinutos;
  bool operator >(HoraDelDia other) => enMinutos > other.enMinutos;
  bool operator <=(HoraDelDia other) => enMinutos <= other.enMinutos;
  bool operator >=(HoraDelDia other) => enMinutos >= other.enMinutos;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HoraDelDia && other.hora == hora && other.minuto == minuto;

  @override
  int get hashCode => Object.hash(hora, minuto);

  @override
  String toString() => toApi();
}

/// Franja de disponibilidad del médico — RF-16, RF-17.
class Disponibilidad {
  const Disponibilidad({
    required this.id,
    required this.idMedico,
    required this.dia,
    required this.horaInicio,
    required this.horaFin,
    required this.duracionSlotMin,
    required this.modalidad,
    required this.activo,
    this.idCentro,
  });

  final int id;
  final int idMedico;
  final DiaSemana dia;

  /// Hora local de Santo Domingo, no UTC.
  final HoraDelDia horaInicio;
  final HoraDelDia horaFin;

  final int duracionSlotMin;
  final ModalidadFranja modalidad;
  final bool activo;
  final int? idCentro;

  /// `08:00 – 10:00`
  String get rango => '${horaInicio.toApi()} – ${horaFin.toApi()}';

  /// Cuántos turnos genera esta franja.
  ///
  /// Es la misma cuenta que hace el backend: cabe un turno mientras el
  /// siguiente no se pase de `horaFin`. Se calcula acá solo para que el
  /// médico vea el efecto de cambiar la duración antes de guardar; la lista
  /// real de turnos siempre viene del servidor.
  int get turnosPorDia {
    final disponible = horaFin.enMinutos - horaInicio.enMinutos;
    if (disponible <= 0 || duracionSlotMin <= 0) return 0;
    return disponible ~/ duracionSlotMin;
  }

  /// Si dos franjas del mismo día se pisan.
  ///
  /// El backend rechaza el solape con **409**. Comprobarlo antes evita el
  /// viaje y, sobre todo, permite decir *cuál* franja estorba — el servidor
  /// solo dice que hay solape.
  bool seSolapaCon(Disponibilidad otra) =>
      dia == otra.dia &&
      activo &&
      otra.activo &&
      horaInicio < otra.horaFin &&
      otra.horaInicio < horaFin;
}
