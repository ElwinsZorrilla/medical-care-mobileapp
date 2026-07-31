import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicare/core/data/turnos_repository.dart';
import 'package:medicare/core/error/failure.dart';
import 'package:medicare/core/time/app_time.dart';

/// Turnos libres — RF-18, y el punto crítico de RNF-18.
///
/// Estas pruebas vivían en `agenda_repository_test.dart`. Se mudaron con el
/// código: el endpoint de turnos lo consumen `agenda` (el médico ve lo que
/// genera su configuración) y `citas` (el paciente reserva), y un feature no
/// importa de otro, así que subió a `core/` (rubro 3.3).
///
/// Corren sobre un `HttpClientAdapter` falso y no sobre un doble de la API:
/// así se ejecuta la construcción real de la URL y del query, que es lo único
/// que de verdad falla contra el servidor.
class _Espia implements HttpClientAdapter {
  _Espia({this.cuerpo = const [], this.error});

  final List<Map<String, dynamic>> cuerpo;
  final DioException? error;

  late RequestOptions pedido;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    pedido = options;
    if (error != null) throw error!;
    return ResponseBody.fromString(
      jsonEncode(cuerpo),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  const unTurno = {
    'idDisponibilidad': 2,
    'horaInicio': '2026-08-17T12:00:00.000Z',
    'horaFin': '2026-08-17T12:30:00.000Z',
    'modalidad': 'PRESENCIAL',
  };

  TurnosRepository repo(_Espia espia) => TurnosRepository(
    Dio(BaseOptions(baseUrl: 'https://ejemplo.test/api'))
      ..httpClientAdapter = espia,
  );

  setUpAll(AppTime.init);

  group('la fecha va en calendario dominicano, no en UTC', () {
    test('01:00Z del 18 pide el 17', () async {
      // A las 21:00 del lunes en RD ya es martes en UTC. Mandar la fecha UTC
      // mostraría los turnos del día equivocado.
      final espia = _Espia(cuerpo: const [unTurno]);
      await repo(
        espia,
      ).turnos(idMedico: 5, diaUtc: DateTime.utc(2026, 8, 18, 1));

      expect(espia.pedido.uri.queryParameters['fecha'], '2026-08-17');
    });

    test('dentro del día local coincide', () async {
      final espia = _Espia(cuerpo: const [unTurno]);
      await repo(
        espia,
      ).turnos(idMedico: 5, diaUtc: DateTime.utc(2026, 8, 17, 15));

      expect(espia.pedido.uri.queryParameters['fecha'], '2026-08-17');
    });

    test('la ruta lleva el id del médico y el prefijo /api', () async {
      final espia = _Espia(cuerpo: const [unTurno]);
      await repo(espia).turnos(idMedico: 5, diaUtc: DateTime.utc(2026, 8, 17));

      expect(espia.pedido.uri.path, '/api/availability/doctors/5/slots');
    });
  });

  group('mapeo', () {
    test('el turno es un instante UTC y se pinta como hora local', () async {
      final r = await repo(
        _Espia(cuerpo: const [unTurno]),
      ).turnos(idMedico: 5, diaUtc: DateTime.utc(2026, 8, 17, 12));

      final t = r.valorONull!.single;
      expect(t.inicioUtc.isUtc, isTrue);
      // 12:00Z es 08:00 en Santo Domingo.
      expect(AppTime.hora(t.inicioUtc), '08:00');
      expect(t.duracion, const Duration(minutes: 30));
    });

    test('conserva el string crudo para reservar', () async {
      // Al reservar hay que mandar exactamente este valor. Reconstruirlo con
      // toIso8601String() puede diferir en milisegundos y el backend no
      // encontraría el turno.
      final r = await repo(
        _Espia(cuerpo: const [unTurno]),
      ).turnos(idMedico: 5, diaUtc: DateTime.utc(2026, 8, 17, 12));

      expect(r.valorONull!.single.inicioApi, '2026-08-17T12:00:00.000Z');
    });

    test('sin turnos devuelve lista vacía, no error', () async {
      final r = await repo(
        _Espia(),
      ).turnos(idMedico: 5, diaUtc: DateTime.utc(2026, 8, 17));

      expect(r.valorONull, isEmpty);
    });
  });

  group('caminos de error', () {
    test('sin conexión', () async {
      final r = await repo(
        _Espia(
          error: DioException(
            requestOptions: RequestOptions(path: '/availability'),
            type: DioExceptionType.connectionError,
          ),
        ),
      ).turnos(idMedico: 5, diaUtc: DateTime.utc(2026, 8, 17));

      expect(r.failureONull, isA<SinConexion>());
    });

    test('una modalidad desconocida falla ruidoso', () async {
      // Caer a un valor por defecto le mentiría al paciente sobre si la
      // consulta es presencial o virtual.
      final r = await repo(
        _Espia(
          cuerpo: const [
            {
              'idDisponibilidad': 2,
              'horaInicio': '2026-08-17T12:00:00.000Z',
              'horaFin': '2026-08-17T12:30:00.000Z',
              'modalidad': 'HOLOGRAMA',
            },
          ],
        ),
      ).turnos(idMedico: 5, diaUtc: DateTime.utc(2026, 8, 17));

      expect(r.failureONull, isA<ErrorInesperado>());
    });
  });
}
