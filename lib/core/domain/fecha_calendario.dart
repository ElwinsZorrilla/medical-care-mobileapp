/// Una fecha del calendario, sin hora ni zona horaria.
///
/// **No es un instante y no debe pasar por `AppTime`.** Una fecha de
/// nacimiento no ocurre "a las 00:00 UTC": es un día del calendario, igual en
/// Santo Domingo que en Tokio. Convertirla con el offset de −4 correría el
/// día hacia atrás y alguien nacido el 1 de agosto aparecería como del 31 de
/// julio.
///
/// Esa confusión es la variante más silenciosa del bug de zona horaria:
/// no rompe nada, solo muestra el día equivocado para la mitad de los
/// usuarios. Por eso las fechas de calendario tienen su propio tipo y no
/// comparten camino con los `DateTime` en UTC.
class FechaCalendario implements Comparable<FechaCalendario> {
  const FechaCalendario(this.anio, this.mes, this.dia);

  final int anio;
  final int mes;
  final int dia;

  /// Parsea `YYYY-MM-DD`, que es como viaja en la API.
  ///
  /// Tolera un sufijo de hora —el backend serializa algunas fechas como
  /// `1990-05-20T00:00:00.000Z`— quedándose solo con la parte de calendario.
  static FechaCalendario? parse(String? valor) {
    if (valor == null || valor.length < 10) return null;
    final partes = valor.substring(0, 10).split('-');
    if (partes.length != 3) return null;
    final anio = int.tryParse(partes[0]);
    final mes = int.tryParse(partes[1]);
    final dia = int.tryParse(partes[2]);
    if (anio == null || mes == null || dia == null) return null;
    if (mes < 1 || mes > 12 || dia < 1 || dia > 31) return null;
    return FechaCalendario(anio, mes, dia);
  }

  /// `YYYY-MM-DD` para mandar a la API.
  String toApi() =>
      '${anio.toString().padLeft(4, '0')}-'
      '${mes.toString().padLeft(2, '0')}-'
      '${dia.toString().padLeft(2, '0')}';

  /// `20/05/1990` para pintar.
  String get formateada =>
      '${dia.toString().padLeft(2, '0')}/'
      '${mes.toString().padLeft(2, '0')}/'
      '$anio';

  /// Edad cumplida al día indicado.
  ///
  /// Recibe el "hoy" en vez de leerlo del reloj para que sea determinista en
  /// pruebas y para no colar un `DateTime.now()` en lógica de negocio.
  int edadA(FechaCalendario hoy) {
    var edad = hoy.anio - anio;
    final cumplioEsteAnio = hoy.mes > mes || (hoy.mes == mes && hoy.dia >= dia);
    if (!cumplioEsteAnio) edad--;
    return edad;
  }

  @override
  int compareTo(FechaCalendario other) {
    final porAnio = anio.compareTo(other.anio);
    if (porAnio != 0) return porAnio;
    final porMes = mes.compareTo(other.mes);
    if (porMes != 0) return porMes;
    return dia.compareTo(other.dia);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FechaCalendario &&
          other.anio == anio &&
          other.mes == mes &&
          other.dia == dia;

  @override
  int get hashCode => Object.hash(anio, mes, dia);

  @override
  String toString() => toApi();
}
