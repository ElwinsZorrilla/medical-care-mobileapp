import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicare/core/data/medico_directorio.dart';
import 'package:medicare/core/domain/modalidad.dart';
import 'package:medicare/core/domain/tipo_usuario.dart';
import 'package:medicare/core/error/failure.dart';
import 'package:medicare/core/network/politica_reintento.dart';
import 'package:medicare/core/time/app_time.dart';
import 'package:medicare/features/auth/domain/usuario.dart';
import 'package:medicare/features/auth/presentation/providers/auth_provider.dart';
import 'package:medicare/features/citas/data/citas_api.dart';
import 'package:medicare/features/citas/data/citas_dto.dart';
import 'package:medicare/features/citas/data/citas_repository.dart';
import 'package:medicare/features/citas/domain/cita.dart';
import 'package:medicare/features/citas/presentation/providers/citas_provider.dart';
import 'package:medicare/features/historial/data/historial_api.dart';
import 'package:medicare/features/historial/data/historial_dto.dart';
import 'package:medicare/features/historial/data/historial_repository.dart';
import 'package:medicare/features/historial/domain/consulta.dart';
import 'package:medicare/features/historial/presentation/providers/historial_provider.dart';

/// El **efecto secundario** de reservar y de registrar una consulta.
///
/// Las pruebas de widget de `ReservaScreen` y `RegistroConsultaScreen`
/// sobrescriben el notifier, así que el cuerpo de `Reserva.reservar` y de
/// `RegistroConsulta.registrar` —donde vive el `ref.invalidate`— no lo ejercía
/// ninguna prueba. Quedó declarado como brecha al cerrar F15; esto la cierra.
///
/// Lo que se verifica no es que la petición salga (eso ya lo cubre el
/// repositorio) sino que **los listados que quedaron viejos se refresquen**.
/// Sin eso el usuario vuelve a una pantalla que le miente: su cita nueva no
/// aparece, o la cita que acaba de completar sigue ofreciendo el botón de
/// registrar y admite una segunda consulta.
class _CitasApiFalsa extends CitasApi {
  _CitasApiFalsa({this.fallo}) : super(Dio());

  final DioException? fallo;
  int listados = 0;

  static const _cita = CitaDto(
    idCita: 5,
    idPaciente: 3,
    idMedico: 7,
    fechaHoraInicio: '2026-08-17T12:00:00.000Z',
    fechaHoraFin: '2026-08-17T12:30:00.000Z',
    modalidad: 'PRESENCIAL',
    estado: 'PENDIENTE',
    fechaCreacion: '2026-08-01T10:00:00.000Z',
  );

  @override
  Future<CitaDto> reservar(CrearCitaDto body) async {
    if (fallo != null) throw fallo!;
    return _cita;
  }

  @override
  Future<PaginaCitasDto> misCitas({int pagina = 1, int limite = 10}) async {
    listados++;
    return const PaginaCitasDto(data: [_cita], total: 1, page: 1, limit: 10);
  }
}

class _HistorialApiFalsa extends HistorialApi {
  _HistorialApiFalsa({this.fallo}) : super(Dio());

  final DioException? fallo;
  int listados = 0;

  static const _consulta = ConsultaDto(
    idConsulta: 11,
    idCita: 5,
    idPaciente: 3,
    idMedico: 7,
    diagnostico: 'Faringitis',
    fechaRegistro: '2026-08-17T14:00:00.000Z',
  );

  @override
  Future<ConsultaDto> registrar(CrearConsultaDto body) async {
    if (fallo != null) throw fallo!;
    return _consulta;
  }

  @override
  Future<PaginaConsultasDto> miHistorial({
    int pagina = 1,
    int limite = 10,
  }) async {
    listados++;
    return const PaginaConsultasDto(data: [], total: 0, page: 1, limit: 10);
  }
}

/// `MedicoDirectorio` sale a la red para resolver el nombre del médico. Aquí
/// devuelve 404 y la tarjeta se pinta igual, que es lo que ya prueba
/// `mis_citas_screen_test`.
class _SinDirectorio implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(jsonEncode({}), 404);

  @override
  void close({bool force = false}) {}
}

class _SesionFalsa extends SesionActual {
  _SesionFalsa(this.usuario);

  final Usuario usuario;

  @override
  Sesion build() => Sesion.autenticada(usuario);
}

void main() {
  setUpAll(AppTime.init);

  DioException http(int status) {
    final o = RequestOptions(path: '/appointments');
    return DioException(
      requestOptions: o,
      response: Response<dynamic>(requestOptions: o, statusCode: status),
      type: DioExceptionType.badResponse,
    );
  }

  const solicitud = SolicitudReserva(
    idMedico: 7,
    fecha: '2026-08-17',
    horaInicioApi: '2026-08-17T12:00:00.000Z',
    modalidad: ModalidadCita.presencial,
  );

  group('Reserva.reservar — RF-19', () {
    Future<(ProviderContainer, _CitasApiFalsa)> preparar({
      DioException? fallo,
    }) async {
      final api = _CitasApiFalsa(fallo: fallo);
      final c = ProviderContainer(
        retry: PoliticaReintento.decidir,
        overrides: [
          citasRepositoryProvider.overrideWithValue(CitasRepository(api)),
          medicoDirectorioProvider.overrideWithValue(
            MedicoDirectorio(Dio()..httpClientAdapter = _SinDirectorio()),
          ),
        ],
      );
      addTearDown(c.dispose);
      // Se mantiene vivo para que la invalidación produzca una recarga real.
      c.listen(listadoCitasProvider(), (_, _) {});
      await c.read(listadoCitasProvider().future);
      return (c, api);
    }

    test('al reservar bien, el listado se refresca', () async {
      final (c, api) = await preparar();
      final antes = api.listados;

      final fallo = await c.read(reservaProvider.notifier).reservar(solicitud);
      await c.read(listadoCitasProvider().future);

      expect(fallo, isNull);
      // Sin esto la cita recién creada no aparece hasta que el usuario
      // refresque a mano.
      expect(api.listados, greaterThan(antes));
    });

    test('si falla, NO se refresca', () async {
      // Invalidar tras un fallo gastaría una petición para volver a pintar
      // exactamente lo mismo.
      final (c, api) = await preparar(fallo: http(409));
      final antes = api.listados;

      final fallo = await c.read(reservaProvider.notifier).reservar(solicitud);

      expect(fallo, isA<Conflicto>());
      expect(api.listados, antes);
    });

    test('devuelve el fallo en vez de lanzarlo', () async {
      // El 409 de turno tomado es un resultado esperado del flujo (RF-20), no
      // una excepción: quien llama decide con `ReaccionAConflicto`.
      final (c, _) = await preparar(fallo: http(409));

      await expectLater(
        c.read(reservaProvider.notifier).reservar(solicitud),
        completion(isA<Failure>()),
      );
    });
  });

  group('RegistroConsulta.registrar — RF-25', () {
    Future<(ProviderContainer, _HistorialApiFalsa)> preparar({
      DioException? fallo,
    }) async {
      final api = _HistorialApiFalsa(fallo: fallo);
      final c = ProviderContainer(
        retry: PoliticaReintento.decidir,
        overrides: [
          sesionActualProvider.overrideWith(
            () => _SesionFalsa(
              const Usuario(
                id: 3,
                correo: 'a@b.com',
                tipo: TipoUsuario.paciente,
              ),
            ),
          ),
          historialRepositoryProvider.overrideWithValue(
            HistorialRepository(api),
          ),
        ],
      );
      addTearDown(c.dispose);
      c.listen(historialProvider, (_, _) {});
      await c.read(historialProvider.future);
      return (c, api);
    }

    const consulta = SolicitudConsulta(idCita: 5, diagnostico: 'Faringitis');

    test('al registrar bien, el historial se refresca', () async {
      final (c, api) = await preparar();
      final antes = api.listados;

      final fallo = await c
          .read(registroConsultaProvider.notifier)
          .registrar(consulta);
      await c.read(historialProvider.future);

      expect(fallo, isNull);
      expect(api.listados, greaterThan(antes));
    });

    test('si falla, NO se refresca', () async {
      final (c, api) = await preparar(fallo: http(403));
      final antes = api.listados;

      final fallo = await c
          .read(registroConsultaProvider.notifier)
          .registrar(consulta);

      expect(fallo, isA<Prohibido>());
      expect(api.listados, antes);
    });
  });
}
