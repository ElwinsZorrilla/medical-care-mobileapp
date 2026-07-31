import 'package:flutter_test/flutter_test.dart';
import 'package:medicare/core/domain/fecha_calendario.dart';
import 'package:medicare/core/time/app_time.dart';

/// La variante silenciosa del bug de zona horaria — RNF-18.
///
/// Una fecha de nacimiento no es un instante: es un día del calendario, igual
/// en Santo Domingo que en Tokio. Pasarla por el offset de −4 la corre un día
/// hacia atrás y no rompe nada visiblemente: solo muestra la fecha equivocada.
void main() {
  group('parse', () {
    test('lee YYYY-MM-DD', () {
      final f = FechaCalendario.parse('1990-05-20');
      expect(f, const FechaCalendario(1990, 5, 20));
    });

    test('tolera el sufijo de hora que a veces manda el backend', () {
      final f = FechaCalendario.parse('1990-05-20T00:00:00.000Z');
      expect(f, const FechaCalendario(1990, 5, 20));
    });

    test('devuelve null ante basura, no lanza', () {
      // Una fecha con forma rara no debe tumbar la pantalla de perfil.
      expect(FechaCalendario.parse(null), isNull);
      expect(FechaCalendario.parse(''), isNull);
      expect(FechaCalendario.parse('20/05/1990'), isNull);
      expect(FechaCalendario.parse('1990-13-01'), isNull);
      expect(FechaCalendario.parse('1990-05-99'), isNull);
    });
  });

  group('no se corre por zona horaria', () {
    test('el día sobrevive la ida y vuelta a la API', () {
      const nacimiento = FechaCalendario(1990, 8, 1);
      expect(FechaCalendario.parse(nacimiento.toApi()), nacimiento);
    });

    test('convertirla como instante SÍ la correría: por eso no se hace', () {
      // Esta prueba documenta el bug que el tipo evita. Si alguien tratara
      // el 1 de agosto como un instante UTC y lo pasara a hora local de RD,
      // el usuario vería 31 de julio.
      final comoInstante = DateTime.utc(1990, 8, 1);
      final malConvertida = AppTime.aLocal(comoInstante);
      expect(malConvertida.day, 31);
      expect(malConvertida.month, 7);

      // El tipo correcto no toca la zona horaria.
      const correcta = FechaCalendario(1990, 8, 1);
      expect(correcta.dia, 1);
      expect(correcta.mes, 8);
    });
  });

  group('formato', () {
    test('toApi rellena con ceros', () {
      expect(const FechaCalendario(1990, 5, 2).toApi(), '1990-05-02');
    });

    test('formateada es dd/MM/yyyy', () {
      expect(const FechaCalendario(1990, 5, 2).formateada, '02/05/1990');
    });
  });

  group('edad', () {
    const nacimiento = FechaCalendario(1990, 8, 15);

    test('ya cumplió este año', () {
      expect(nacimiento.edadA(const FechaCalendario(2026, 9, 1)), 36);
    });

    test('todavía no cumple', () {
      expect(nacimiento.edadA(const FechaCalendario(2026, 7, 1)), 35);
    });

    test('justo el día del cumpleaños ya cuenta', () {
      expect(nacimiento.edadA(const FechaCalendario(2026, 8, 15)), 36);
    });

    test('el día anterior todavía no', () {
      expect(nacimiento.edadA(const FechaCalendario(2026, 8, 14)), 35);
    });
  });

  group('orden e igualdad', () {
    test('compara cronológicamente', () {
      final fechas = [
        const FechaCalendario(1990, 5, 20),
        const FechaCalendario(1985, 12, 1),
        const FechaCalendario(1990, 1, 3),
      ]..sort();
      expect(fechas.first, const FechaCalendario(1985, 12, 1));
      expect(fechas.last, const FechaCalendario(1990, 5, 20));
    });

    test('igualdad por valor', () {
      expect(
        const FechaCalendario(1990, 5, 20),
        const FechaCalendario(1990, 5, 20),
      );
      expect(
        const FechaCalendario(1990, 5, 20),
        isNot(const FechaCalendario(1990, 5, 21)),
      );
    });
  });
}
