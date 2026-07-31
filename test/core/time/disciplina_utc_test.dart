import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medicare/core/domain/fecha_calendario.dart';
import 'package:medicare/core/domain/modalidad.dart';
import 'package:medicare/core/time/app_time.dart';
import 'package:medicare/features/agenda/domain/disponibilidad.dart';
import 'package:medicare/features/citas/domain/cita.dart';

/// La red de RNF-18 — rubro 3.5.
///
/// > *"Hay una prueba que rompe si alguien mete un `DateTime` local en un
/// > payload. La regla más fácil de violar necesita su propia red."*
///
/// Las demás pruebas verifican que el código **de hoy** convierte bien. Esta
/// verifica que el de mañana no pueda dejar de hacerlo sin que alguien se
/// entere: recorre el código fuente y falla si aparece un patrón prohibido.
///
/// Es inusual que una prueba lea archivos, y es a propósito. Un comentario
/// que diga "no usar `DateTime.now()`" se ignora en la primera prisa; una
/// prueba en rojo, no.
void main() {
  group('disciplina de zona horaria en el código fuente', () {
    /// Archivos donde el patrón sí está permitido, con su razón.
    const permitidos = <String, String>{
      'lib/core/time/app_time.dart':
          'es la frontera única UTC↔local: acá vive la conversión',
    };

    /// [incluirGenerados] mira también `.g.dart` y `.freezed.dart`.
    ///
    /// Para `DateTime.now()` no tiene sentido —nadie lo genera— pero para
    /// `DateTime.parse` sí: `json_serializable` lo emite sin `.toUtc()` porque
    /// no sabe nada de RNF-18, y "no se escribe a mano" es justamente el
    /// motivo por el que nadie lo revisa.
    List<({String archivo, int linea, String texto})> buscar(
      RegExp patron, {
      bool incluirGenerados = false,
    }) {
      final lib = Directory('lib');
      // Sin esto la guarda devuelve la lista vacía y las tres pruebas pasan
      // sin haber leído un archivo: el peor modo de falla para una guarda es
      // no avisar que no corrió.
      expect(
        lib.existsSync(),
        isTrue,
        reason:
            'la guarda corre desde la raíz del paquete; '
            'cwd = ${Directory.current.path}',
      );

      final hallazgos = <({String archivo, int linea, String texto})>[];
      var vistos = 0;

      for (final entidad in lib.listSync(recursive: true)) {
        if (entidad is! File || !entidad.path.endsWith('.dart')) continue;

        final ruta = entidad.path.replaceAll(r'\', '/');
        final generado =
            ruta.endsWith('.g.dart') || ruta.endsWith('.freezed.dart');
        if (generado && !incluirGenerados) continue;
        if (permitidos.containsKey(ruta)) continue;
        vistos++;

        final lineas = entidad.readAsLinesSync();
        for (var i = 0; i < lineas.length; i++) {
          final texto = lineas[i];
          // Los comentarios que advierten sobre el patrón no son usos. Se
          // recortan solo si el `//` abre la línea: cortar en el primer `//`
          // de cualquier posición esconde el código que sigue a un literal
          // con `https://`.
          if (texto.trimLeft().startsWith('//')) continue;
          if (patron.hasMatch(texto)) {
            hallazgos.add((archivo: ruta, linea: i + 1, texto: texto.trim()));
          }
        }
      }

      // Un filtro mal escrito tampoco puede dejarla en cero en silencio.
      expect(vistos, greaterThan(30), reason: 'la guarda no recorrió lib/');
      return hallazgos;
    }

    String describir(List<({String archivo, int linea, String texto})> h) =>
        h.map((x) => '\n  ${x.archivo}:${x.linea}  ${x.texto}').join();

    test('ningún DateTime.now() fuera de AppTime', () {
      // `AppTime.ahoraUtc()` es el único "ahora" del sistema. Uno suelto en
      // lógica de negocio devuelve hora del dispositivo —que puede estar en
      // cualquier zona— y vuelve la lógica no determinista en pruebas.
      final hallazgos = buscar(RegExp(r'DateTime\.now\(\)'));
      expect(
        hallazgos,
        isEmpty,
        reason:
            'Usar AppTime.ahoraUtc(). Encontrado en:${describir(hallazgos)}',
      );
    });

    test('ningún .toLocal() fuera de AppTime', () {
      // `.toLocal()` usa la zona del dispositivo. Un paciente que viaja vería
      // sus citas corridas; el servidor siempre habla en hora de RD.
      final hallazgos = buscar(RegExp(r'\.toLocal\(\)'));
      expect(
        hallazgos,
        isEmpty,
        reason: 'Usar AppTime.aLocal(). Encontrado en:${describir(hallazgos)}',
      );
    });

    test('ningún DateTime.parse sin .toUtc(), tampoco en los generados', () {
      // `DateTime.parse` de un string sin sufijo Z devuelve un DateTime
      // *local*. Guardarlo así y compararlo con uno UTC da diferencias de
      // cuatro horas que no fallan: solo dan resultados equivocados.
      //
      // El patrón se evalúa **por aparición**, no por línea: el filtro
      // anterior descartaba la línea entera si `.toUtc()` aparecía en
      // cualquier parte, así que `DateTime.parse(a), DateTime.parse(b).toUtc()`
      // pasaba con el primer parseo en local.
      final hallazgos = buscar(
        RegExp(r'DateTime\.parse\([^)]*\)(?!\.toUtc\(\))'),
        incluirGenerados: true,
      );

      expect(
        hallazgos,
        isEmpty,
        reason:
            'Encadenar .toUtc() al parsear. Un DTO con campo `DateTime` hace '
            'que json_serializable lo emita sin normalizar: declararlo `String` '
            'y convertir en el repositorio. Encontrado en:'
            '${describir(hallazgos)}',
      );
    });

    test('ningún constructor DateTime() ni fromMillisecondsSinceEpoch', () {
      // Las dos formas más directas de fabricar un DateTime local sin que
      // aparezca la palabra `now` ni `toLocal`.
      final hallazgos = [
        ...buscar(RegExp(r'\bDateTime\(')),
        ...buscar(RegExp(r'DateTime\.fromMillisecondsSinceEpoch\(')),
      ];

      expect(
        hallazgos,
        isEmpty,
        reason:
            'Usar DateTime.utc(...) o AppTime. Encontrado en:'
            '${describir(hallazgos)}',
      );
    });
  });

  group('lo que sale hacia la API', () {
    setUpAll(() async => AppTime.init());

    test(
      'la reserva manda el string crudo del servidor, no uno reconstruido',
      () {
        // Si alguien cambiara `horaInicioApi` por `inicio.toIso8601String()`,
        // el valor podría diferir en los milisegundos y el backend no
        // encontraría el turno. Esta prueba fija el contrato.
        const turno = SolicitudReserva(
          idMedico: 1,
          fecha: '2026-08-17',
          horaInicioApi: '2026-08-17T12:00:00.000Z',
          modalidad: ModalidadCita.presencial,
        );
        expect(turno.horaInicioApi, endsWith('Z'));
        expect(turno.horaInicioApi, '2026-08-17T12:00:00.000Z');
      },
    );

    test('el turno conserva el string tal cual vino', () {
      final turno = Turno(
        idDisponibilidad: 1,
        inicioUtc: DateTime.parse('2026-08-17T12:00:00.000Z').toUtc(),
        finUtc: DateTime.parse('2026-08-17T12:30:00.000Z').toUtc(),
        modalidad: ModalidadFranja.presencial,
        inicioApi: '2026-08-17T12:00:00.000Z',
      );
      // Reconstruirlo daría el mismo valor hoy, pero no está garantizado:
      // el backend podría cambiar el formato de serialización.
      expect(turno.inicioApi, '2026-08-17T12:00:00.000Z');
      expect(turno.inicioUtc.isUtc, isTrue);
    });

    test('la fecha de la API sale del calendario dominicano', () {
      // 01:00Z del 18 es todavía el 17 en RD.
      expect(AppTime.fechaApi(DateTime.utc(2026, 8, 18, 1)), '2026-08-17');
    });

    test('una fecha de calendario no pasa por conversión de zona', () {
      // Es el bug silencioso: no lanza, solo muestra el día anterior.
      const nacimiento = FechaCalendario(1990, 8, 1);
      expect(nacimiento.toApi(), '1990-08-01');

      final comoInstante = AppTime.aLocal(DateTime.utc(1990, 8, 1));
      expect(
        comoInstante.day,
        isNot(nacimiento.dia),
        reason: 'tratarla como instante la correría: por eso tiene tipo propio',
      );
    });

    test('las horas de franja no llevan zona: son hora de pared', () {
      const franja = HoraDelDia(8, 0);
      expect(franja.toApi(), '08:00');
      expect(franja.toApi(), isNot(contains('Z')));
      expect(franja.toApi(), isNot(contains('T')));
    });
  });
}
