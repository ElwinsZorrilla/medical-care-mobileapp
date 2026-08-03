import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicare/core/error/failure.dart';
import 'package:medicare/core/network/politica_reintento.dart';
import 'package:medicare/core/time/app_time.dart';
import 'package:medicare/features/video/data/lanzador_sala.dart';
import 'package:medicare/features/video/data/video_api.dart';
import 'package:medicare/features/video/data/video_dto.dart';
import 'package:medicare/features/video/data/video_repository.dart';
import 'package:medicare/features/video/domain/videollamada.dart';
import 'package:medicare/features/video/presentation/providers/video_provider.dart';

/// Videollamada — RF-35, RF-36, RF-37.
///
/// El backend usa Jitsi publico: no hay SDK que empotrar, la sala se abre
/// fuera de la app. Lo que se prueba aca es que se abra **la URL correcta** y
/// que el estado no retroceda nunca.
class _ApiFalsa extends VideoApi {
  _ApiFalsa({this.estado = 'PROGRAMADA', this.status}) : super(Dio());

  String estado;
  int? status;

  /// Separado de [status]: hay pruebas donde crear la sala funciona y mover
  /// el estado no. Se asigna despues de construir, ya cargada la pantalla.
  int? statusPatch;

  String? mensajeServidor;

  /// El telefono sin datos: `dio` no llega a tener respuesta.
  bool redCaida = false;

  int creadas = 0;
  final List<String> estadosPedidos = [];

  String? _inicio;
  String? _fin;

  DioException _error(int s) {
    final o = RequestOptions(path: '/appointments/7/videollamada');
    return DioException(
      requestOptions: o,
      response: Response<dynamic>(
        requestOptions: o,
        statusCode: s,
        data: mensajeServidor == null ? null : {'message': mensajeServidor},
      ),
      type: DioExceptionType.badResponse,
    );
  }

  VideollamadaDto _dto() => VideollamadaDto(
    idVideollamada: 1,
    idCita: 7,
    proveedor: 'JITSI',
    urlSala: 'https://meet.jit.si/medicare-3f1a',
    estado: estado,
    horaInicioReal: _inicio,
    horaFinReal: _fin,
  );

  @override
  Future<VideollamadaDto> crearOObtener(int idCita) async {
    creadas++;
    if (status != null) throw _error(status!);
    return _dto();
  }

  @override
  Future<VideollamadaDto> porCita(int idCita) async {
    if (status != null) throw _error(status!);
    return _dto();
  }

  @override
  Future<VideollamadaDto> cambiarEstado(int idCita, String nuevo) async {
    estadosPedidos.add(nuevo);
    if (redCaida) {
      throw DioException(
        requestOptions: RequestOptions(path: '/appointments/7/videollamada'),
        type: DioExceptionType.connectionError,
      );
    }
    if (statusPatch != null) throw _error(statusPatch!);
    if (status != null) throw _error(status!);

    estado = nuevo;
    // El backend estampa las horas al mover el estado.
    if (nuevo == 'EN_CURSO') _inicio = '2026-08-17T12:02:00.000Z';
    if (nuevo == 'FINALIZADA' || nuevo == 'FALLIDA') {
      _fin = '2026-08-17T12:28:00.000Z';
    }
    return _dto();
  }
}

/// Anota lo que se le pidio abrir en vez de tocar el canal de plataforma,
/// que en un `flutter test` no existe.
class _LanzadorFalso implements LanzadorSala {
  _LanzadorFalso({this.puede = true});

  final bool puede;
  final List<String> abiertas = [];

  @override
  Future<bool> abrir(String url) async {
    abiertas.add(url);
    return puede;
  }
}

void main() {
  setUpAll(AppTime.init);

  ProviderContainer contenedor(_ApiFalsa api, {_LanzadorFalso? lanzador}) {
    final c = ProviderContainer(
      retry: PoliticaReintento.decidir,
      overrides: [
        videoRepositoryProvider.overrideWithValue(VideoRepository(api)),
        lanzadorSalaProvider.overrideWithValue(lanzador ?? _LanzadorFalso()),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  /// Carga la sala de la cita 7 y la deja viva: sin un oyente, `autoDispose`
  /// la destruye en cuanto el test cede el turno.
  Future<void> abrirSala(ProviderContainer c) async {
    c.listen(salaProvider(7), (_, _) {});
    await c.read(salaProvider(7).future);
  }

  group('RF-37 — la tabla de transiciones', () {
    test('solo avanza; nunca retrocede', () {
      expect(EstadoVideollamada.programada.siguientes, {
        EstadoVideollamada.enCurso,
        EstadoVideollamada.fallida,
      });
      expect(EstadoVideollamada.enCurso.siguientes, {
        EstadoVideollamada.finalizada,
        EstadoVideollamada.fallida,
      });
      // Una llamada terminada volviendo a "en curso" dejaria el registro de
      // horas sin significado.
      expect(EstadoVideollamada.finalizada.siguientes, isEmpty);
      expect(EstadoVideollamada.fallida.siguientes, isEmpty);
    });

    test('solo se entra a lo que todavia puede ocurrir', () {
      expect(EstadoVideollamada.programada.admiteEntrada, isTrue);
      expect(EstadoVideollamada.enCurso.admiteEntrada, isTrue);
      expect(EstadoVideollamada.finalizada.admiteEntrada, isFalse);
      expect(EstadoVideollamada.fallida.admiteEntrada, isFalse);
    });

    test('los cuatro valores del enum del backend se reconocen', () {
      for (final v in const [
        'PROGRAMADA',
        'EN_CURSO',
        'FINALIZADA',
        'FALLIDA',
      ]) {
        expect(EstadoVideollamada.desdeApi(v), isNotNull, reason: v);
      }
      expect(EstadoVideollamada.desdeApi('EN_PAUSA'), isNull);
    });
  });

  group('RF-35, RF-36 — abrir la sala', () {
    test('camino feliz: mapea lo que llega', () async {
      final c = contenedor(_ApiFalsa());
      final sala = await c.read(salaProvider(7).future);

      expect(sala.id, 1);
      expect(sala.idCita, 7);
      expect(sala.proveedor, 'JITSI');
      expect(sala.estado, EstadoVideollamada.programada);
      expect(sala.inicioRealUtc, isNull);
    });

    test('se pide con POST, que es idempotente', () async {
      // Consultar primero para crear despues seria una ida y vuelta de mas,
      // con una ventana en la que los dos participantes crean dos salas.
      final api = _ApiFalsa();
      final c = contenedor(api);
      await c.read(salaProvider(7).future);

      expect(api.creadas, 1);
    });

    test('una cita presencial da 409 con el motivo del servidor', () async {
      final api = _ApiFalsa(status: 409)
        ..mensajeServidor = 'Esa cita es presencial: no tiene sala de video';
      final c = contenedor(api);

      await expectLater(
        c.read(salaProvider(7).future),
        throwsA(
          isA<Conflicto>().having(
            (e) => e.mensaje,
            'mensaje',
            contains('presencial'),
          ),
        ),
      );
    });

    test('403 si la cita es de otros', () async {
      final c = contenedor(_ApiFalsa(status: 403));
      await expectLater(
        c.read(salaProvider(7).future),
        throwsA(isA<Prohibido>()),
      );
    });

    test('un estado desconocido falla ruidoso', () async {
      // Pintar "Programada" donde el servidor dijo otra cosa llevaria a tocar
      // "Entrar" en una consulta que ya termino.
      final c = contenedor(_ApiFalsa(estado: 'EN_PAUSA'));
      await expectLater(
        c.read(salaProvider(7).future),
        throwsA(isA<ErrorInesperado>()),
      );
    });
  });

  group('RF-35 — entrar a la consulta', () {
    test('abre la URL de la sala, no otra cosa', () async {
      final lanzador = _LanzadorFalso();
      final c = contenedor(_ApiFalsa(), lanzador: lanzador);
      await abrirSala(c);

      final fallo = await c.read(salaProvider(7).notifier).entrar();

      expect(fallo, isNull);
      expect(lanzador.abiertas, ['https://meet.jit.si/medicare-3f1a']);
    });

    test('marca EN_CURSO antes de abrir', () async {
      // Si se abriera primero, la app pasa a segundo plano y el cambio de
      // estado se queda a medias.
      final api = _ApiFalsa();
      final c = contenedor(api);
      await abrirSala(c);

      await c.read(salaProvider(7).notifier).entrar();

      expect(api.estadosPedidos, ['EN_CURSO']);
      final sala = c.read(salaProvider(7)).value!;
      expect(sala.estado, EstadoVideollamada.enCurso);
      expect(sala.inicioRealUtc, DateTime.utc(2026, 8, 17, 12, 2));
      expect(sala.inicioRealUtc!.isUtc, isTrue);
    });

    test('entrar dos veces no vuelve a mover el estado', () async {
      final api = _ApiFalsa();
      final lanzador = _LanzadorFalso();
      final c = contenedor(api, lanzador: lanzador);
      await abrirSala(c);

      await c.read(salaProvider(7).notifier).entrar();
      await c.read(salaProvider(7).notifier).entrar();

      // Ya esta EN_CURSO: pedir el mismo salto daria 409.
      expect(api.estadosPedidos, ['EN_CURSO']);
      expect(lanzador.abiertas, hasLength(2));
    });

    test('si el sistema no puede abrirla, lo dice', () async {
      final lanzador = _LanzadorFalso(puede: false);
      final c = contenedor(_ApiFalsa(), lanzador: lanzador);
      await abrirSala(c);

      final fallo = await c.read(salaProvider(7).notifier).entrar();

      expect(fallo, isA<ErrorInesperado>());
      expect(fallo!.mensaje, contains('navegador'));
    });

    test('una consulta terminada no se abre', () async {
      final lanzador = _LanzadorFalso();
      final c = contenedor(_ApiFalsa(estado: 'FINALIZADA'), lanzador: lanzador);
      await abrirSala(c);

      final fallo = await c.read(salaProvider(7).notifier).entrar();

      expect(fallo, isA<Conflicto>());
      expect(lanzador.abiertas, isEmpty);
    });

    test('sin red no se abre la sala a ciegas', () async {
      // Entrar sin poder marcar EN_CURSO por falta de conexion significa que
      // tampoco hay red para sostener la videollamada. Abrir Jitsi ahi manda
      // al usuario a una sala que no va a cargar.
      final api = _ApiFalsa();
      final lanzador = _LanzadorFalso();
      final c = contenedor(api, lanzador: lanzador);
      await abrirSala(c);

      api.redCaida = true;
      final fallo = await c.read(salaProvider(7).notifier).entrar();

      expect(fallo, isA<SinConexion>());
      expect(lanzador.abiertas, isEmpty);
    });

    test('un 409 al marcar EN_CURSO no impide entrar', () async {
      // El estado es contabilidad; entrar a la consulta es lo que el usuario
      // vino a hacer. Un salto rechazado no puede dejarlo fuera.
      final api = _ApiFalsa()..statusPatch = 409;
      final lanzador = _LanzadorFalso();
      final c = contenedor(api, lanzador: lanzador);
      await abrirSala(c);

      final fallo = await c.read(salaProvider(7).notifier).entrar();

      expect(fallo, isNull);
      expect(lanzador.abiertas, hasLength(1));
    });
  });

  group('RF-37 — mover el estado', () {
    test('el medico finaliza y quedan las dos horas', () async {
      final api = _ApiFalsa();
      final c = contenedor(api);
      await abrirSala(c);

      await c.read(salaProvider(7).notifier).entrar();
      final fallo = await c
          .read(salaProvider(7).notifier)
          .cambiarEstado(EstadoVideollamada.finalizada);

      expect(fallo, isNull);
      final sala = c.read(salaProvider(7)).value!;
      expect(sala.estado, EstadoVideollamada.finalizada);
      expect(sala.finRealUtc, DateTime.utc(2026, 8, 17, 12, 28));
      expect(sala.duracion, const Duration(minutes: 26));
    });

    test('un salto imposible ni siquiera se pide', () async {
      final api = _ApiFalsa();
      final c = contenedor(api);
      await abrirSala(c);

      // PROGRAMADA -> FINALIZADA no existe: hay que pasar por EN_CURSO.
      final fallo = await c
          .read(salaProvider(7).notifier)
          .cambiarEstado(EstadoVideollamada.finalizada);

      expect(fallo, isA<Conflicto>());
      // La guarda del cliente evita el 409 conocido.
      expect(api.estadosPedidos, isEmpty);
    });

    test('desde PROGRAMADA se puede marcar fallida', () async {
      final api = _ApiFalsa();
      final c = contenedor(api);
      await abrirSala(c);

      final fallo = await c
          .read(salaProvider(7).notifier)
          .cambiarEstado(EstadoVideollamada.fallida);

      expect(fallo, isNull);
      expect(api.estadosPedidos, ['FALLIDA']);
      expect(c.read(salaProvider(7)).value!.estado, EstadoVideollamada.fallida);
    });

    test('un 409 del servidor no tumba la pantalla', () async {
      final api = _ApiFalsa()
        ..statusPatch = 409
        ..mensajeServidor = 'Esa videollamada ya finalizo';
      final c = contenedor(api);
      await abrirSala(c);

      final fallo = await c
          .read(salaProvider(7).notifier)
          .cambiarEstado(EstadoVideollamada.enCurso);

      expect(fallo, isA<Conflicto>());
      // Lo que se estaba mostrando sigue siendo cierto.
      expect(
        c.read(salaProvider(7)).value!.estado,
        EstadoVideollamada.programada,
      );
    });
  });

  group('El repositorio traduce', () {
    test('404: la cita todavia no tiene sala', () async {
      final api = _ApiFalsa(status: 404)
        ..mensajeServidor = 'Esa cita todavia no tiene sala de video';
      final r = await VideoRepository(api).porCita(7);

      expect(r.failureONull, isA<NoEncontrado>());
      expect(r.failureONull!.mensaje, contains('sala de video'));
    });

    test('una fecha invalida no revienta la pantalla', () async {
      final r = await VideoRepository(_FechaRota()).porCita(7);

      expect(r.failureONull, isA<ErrorInesperado>());
    });

    test(
      'el estado sale del enum del backend, no de un string libre',
      () async {
        final api = _ApiFalsa();
        await VideoRepository(api).cambiarEstado(7, EstadoVideollamada.enCurso);

        expect(api.estadosPedidos, ['EN_CURSO']);
      },
    );
  });
}

/// El backend devolviendo algo que no es una fecha.
class _FechaRota extends VideoApi {
  _FechaRota() : super(Dio());

  @override
  Future<VideollamadaDto> porCita(int idCita) async => const VideollamadaDto(
    idVideollamada: 1,
    idCita: 7,
    proveedor: 'JITSI',
    urlSala: 'https://meet.jit.si/medicare-3f1a',
    estado: 'PROGRAMADA',
    horaInicioReal: 'hace un rato',
  );
}
