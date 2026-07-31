import 'package:flutter_test/flutter_test.dart';
import 'package:medicare/core/time/app_time.dart';

/// Pruebas de RNF-18 — la regla más fácil de violar del proyecto.
///
/// El caso que fija todo lo demás está verificado contra el backend real en
/// F00: una franja declarada a las 08:00 locales devuelve el slot
/// `2026-08-17T12:00:00.000Z`. Si algún día estas pruebas fallan, o cambió
/// el backend o alguien "corrigió" la zona horaria por su cuenta.
void main() {
  setUpAll(() async => AppTime.init());

  group('conversión UTC ↔ Santo Domingo', () {
    test('el offset es −4 fijo, igual que el backend', () {
      expect(AppTime.offsetSantoDomingo, const Duration(hours: -4));
    });

    test('08:00 local es 12:00Z — el caso verificado en F00', () {
      final utc = DateTime.utc(2026, 8, 17, 12);
      final local = AppTime.aLocal(utc);
      expect(local.hour, 8);
      expect(local.day, 17);
    });

    test('ida y vuelta no pierde el instante', () {
      final original = DateTime.utc(2026, 8, 17, 12, 30);
      expect(AppTime.aUtc(AppTime.aLocal(original)), original);
    });

    test('no aplica horario de verano en ninguna época del año', () {
      // RD no tiene DST desde 2000. Enero y julio deben desplazarse igual:
      // si alguien mete la zona IANA con reglas de DST, esto rompe.
      final invierno = AppTime.aLocal(DateTime.utc(2026, 1, 15, 12));
      final verano = AppTime.aLocal(DateTime.utc(2026, 7, 15, 12));
      expect(invierno.hour, 8);
      expect(verano.hour, 8);
    });
  });

  group('fechaApi — el bug de zona horaria más caro del proyecto', () {
    test('usa el calendario dominicano, no el UTC', () {
      // 01:00Z del martes es todavía lunes 21:00 en Santo Domingo.
      // Mandar la fecha UTC pediría los turnos del día equivocado.
      final utc = DateTime.utc(2026, 8, 18, 1);
      expect(AppTime.fechaApi(utc), '2026-08-17');
    });

    test('dentro del día local coincide con la fecha UTC', () {
      expect(AppTime.fechaApi(DateTime.utc(2026, 8, 17, 12)), '2026-08-17');
    });

    test('la ventana 20:00–23:59 local cae en el día anterior al UTC', () {
      for (var h = 0; h < 4; h++) {
        final utc = DateTime.utc(2026, 8, 18, h);
        expect(
          AppTime.fechaApi(utc),
          '2026-08-17',
          reason: '${h}h UTC sigue siendo el 17 en RD',
        );
      }
      expect(AppTime.fechaApi(DateTime.utc(2026, 8, 18, 4)), '2026-08-18');
    });
  });

  group('formato', () {
    final utc = DateTime.utc(2026, 8, 4, 12, 30);

    test('hora en 24h sobre la hora local', () {
      expect(AppTime.hora(utc), '08:30');
    });

    test('día y mes en versalitas para la tarjeta', () {
      expect(AppTime.diaMes(utc), startsWith('04'));
      expect(AppTime.diaMes(utc), AppTime.diaMes(utc).toUpperCase());
    });

    test('fecha corta dd/MM/y', () {
      expect(AppTime.fechaCorta(utc), '04/08/2026');
    });

    test('rango de horas', () {
      expect(
        AppTime.rangoHoras(utc, utc.add(const Duration(minutes: 30))),
        '08:30 – 09:00',
      );
    });

    test('fecha larga en español', () {
      expect(AppTime.fechaLarga(utc), contains('agosto'));
    });
  });

  group('utilidades de día', () {
    test('mismoDiaLocal compara el calendario dominicano', () {
      // Ambos son el 17 en RD, aunque el segundo ya sea 18 en UTC.
      expect(
        AppTime.mismoDiaLocal(
          DateTime.utc(2026, 8, 17, 13),
          DateTime.utc(2026, 8, 18, 1),
        ),
        isTrue,
      );
    });

    test('días locales distintos', () {
      expect(
        AppTime.mismoDiaLocal(
          DateTime.utc(2026, 8, 17, 12),
          DateTime.utc(2026, 8, 18, 12),
        ),
        isFalse,
      );
    });

    test('inicioDiaLocalEnUtc da la medianoche de RD, o sea 04:00Z', () {
      final inicio = AppTime.inicioDiaLocalEnUtc(DateTime.utc(2026, 8, 17, 18));
      expect(inicio, DateTime.utc(2026, 8, 17, 4));
      expect(inicio.isUtc, isTrue);
    });
  });

  group('ahoraUtc', () {
    test('siempre viene marcado como UTC', () {
      // Es la red que evita que un DateTime local se cuele a un payload.
      expect(AppTime.ahoraUtc().isUtc, isTrue);
    });
  });
}
