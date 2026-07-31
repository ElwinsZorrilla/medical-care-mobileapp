import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Frontera única entre UTC y la hora de Santo Domingo — RNF-18.
///
/// **Toda fecha viaja en UTC.** Se convierte a local solo al pintar, y solo
/// acá. Un `DateTime.now()` suelto en lógica de negocio o un `.toLocal()`
/// fuera de esta clase es un hallazgo del gate.
///
/// ## Por qué offset fijo y no la zona IANA
///
/// El backend calcula los turnos con una constante de −4 horas
/// (`OFFSET_SANTO_DOMINGO_HORAS = 4`, ADR-005), no con la base de datos de
/// zonas horarias. República Dominicana no aplica horario de verano desde
/// 2000, así que hoy `America/Santo_Domingo` y −4 fijo dan lo mismo.
///
/// Si algún día divergen, **manda el servidor**: es quien decide qué turno
/// existe. Un front que "corrigiera" por DST mostraría las 9:00 donde el
/// servidor entiende las 8:00, y el paciente reservaría una hora que no es.
/// Por eso acá hay una constante y no una consulta a `timezone`.
///
/// Ver docs/API_CONTRACT.md §2.
abstract final class AppTime {
  /// Desfase de Santo Domingo respecto de UTC. Negativo: va detrás.
  static const Duration offsetSantoDomingo = Duration(hours: -4);

  static const String locale = 'es_DO';

  static bool _iniciado = false;

  /// Prepara los símbolos de fecha del locale.
  ///
  /// Sin esto, `DateFormat` con `es_DO` lanza en runtime —no en compilación—
  /// la primera vez que se formatea una fecha. Va en `main()` antes de
  /// `runApp`.
  static Future<void> init() async {
    if (_iniciado) return;
    await initializeDateFormatting(locale);
    _iniciado = true;
  }

  /// El único "ahora" del sistema, siempre en UTC.
  ///
  /// La lógica de negocio llama acá y no a `DateTime.now()`, para que las
  /// pruebas puedan razonar sobre instantes fijos y para que nunca se cuele
  /// una hora local en un payload.
  static DateTime ahoraUtc() => DateTime.now().toUtc();

  /// UTC → hora de pared de Santo Domingo. **Solo para pintar.**
  ///
  /// Devuelve un `DateTime` marcado como UTC cuyos campos de calendario ya
  /// son los locales. Eso es deliberado: evita que el sistema operativo del
  /// dispositivo —que puede estar en cualquier zona— vuelva a desplazarlo.
  static DateTime aLocal(DateTime utc) => utc.toUtc().add(offsetSantoDomingo);

  /// Hora de pared de Santo Domingo → UTC. Para armar un payload.
  static DateTime aUtc(DateTime local) => DateTime.utc(
    local.year,
    local.month,
    local.day,
    local.hour,
    local.minute,
    local.second,
    local.millisecond,
  ).subtract(offsetSantoDomingo);

  /// Fecha para el parámetro `?fecha=` de disponibilidad y reserva.
  ///
  /// El backend lo interpreta como **calendario de Santo Domingo**, no UTC.
  /// Mandar la fecha UTC hace que entre las 20:00 y la medianoche local se
  /// pida el día equivocado: a las 21:00 del lunes en RD ya es martes en
  /// UTC, y la grilla mostraría los turnos del día siguiente.
  static String fechaApi(DateTime utc) =>
      DateFormat('yyyy-MM-dd').format(aLocal(utc));

  /// `04 AGO` — encabezado de tarjeta de cita.
  static String diaMes(DateTime utc) =>
      DateFormat('dd MMM', locale).format(aLocal(utc)).toUpperCase();

  /// `08:30` — hora en formato de 24 horas, tabular.
  static String hora(DateTime utc) => DateFormat('HH:mm').format(aLocal(utc));

  /// `lunes, 4 de agosto de 2026`
  static String fechaLarga(DateTime utc) =>
      DateFormat('EEEE, d \'de\' MMMM \'de\' y', locale).format(aLocal(utc));

  /// `04/08/2026`
  static String fechaCorta(DateTime utc) =>
      DateFormat('dd/MM/y').format(aLocal(utc));

  /// `04/08/2026 08:30`
  static String fechaHora(DateTime utc) => '${fechaCorta(utc)} ${hora(utc)}';

  /// Rango dentro del mismo día: `08:30 – 09:00`.
  static String rangoHoras(DateTime inicioUtc, DateTime finUtc) =>
      '${hora(inicioUtc)} – ${hora(finUtc)}';

  /// Si dos instantes caen el mismo día del calendario dominicano.
  static bool mismoDiaLocal(DateTime aUtcValor, DateTime bUtcValor) {
    final a = aLocal(aUtcValor);
    final b = aLocal(bUtcValor);
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Medianoche local del día que contiene [utc], expresada en UTC.
  static DateTime inicioDiaLocalEnUtc(DateTime utc) {
    final local = aLocal(utc);
    return aUtc(DateTime.utc(local.year, local.month, local.day));
  }
}
