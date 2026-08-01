import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicare/core/data/notificaciones_api.dart';
import 'package:medicare/core/data/notificaciones_dto.dart';
import 'package:medicare/core/data/notificaciones_provider.dart';
import 'package:medicare/core/data/notificaciones_repository.dart';
import 'package:medicare/core/domain/notificacion.dart';
import 'package:medicare/core/error/failure.dart';
import 'package:medicare/core/network/politica_reintento.dart';
import 'package:medicare/core/time/app_time.dart';
import 'package:medicare/features/notificaciones/presentation/providers/notificaciones_provider.dart';

/// Bandeja de notificaciones — RF-28, RF-29, RF-30.
///
/// Es una bandeja **in-app**, no push: el backend guarda y sirve las
/// notificaciones pero no hay proveedor de push configurado. Prometer una
/// alerta que nunca llega es peor que no prometerla.
class _ApiFalsa extends NotificacionesApi {
  _ApiFalsa({this.total = 2, this.status, this.tipo = 'RECORDATORIO'})
    : super(Dio());

  final int total;

  /// Mutable: hay pruebas que cargan bien y despues rompen el servidor.
  int? status;
  final String tipo;

  int marcarTodas = 0;
  int? ultimaMarcada;

  /// Cuantas veces se pidio la bandeja. Sirve para comprobar que el scroll no
  /// dispara peticiones de mas.
  int peticiones = 0;

  DioException _error(int s) {
    final o = RequestOptions(path: '/notifications');
    return DioException(
      requestOptions: o,
      response: Response<dynamic>(requestOptions: o, statusCode: s),
      type: DioExceptionType.badResponse,
    );
  }

  NotificacionDto _dto(int i, {bool leida = false}) => NotificacionDto(
    idNotificacion: i,
    tipo: tipo,
    titulo: 'Cita confirmada $i',
    cuerpo: 'Tu cita del 17 de agosto a las 08:00.',
    leida: leida,
    fechaEnvio: '2026-08-17T12:00:00.000Z',
    idCita: 5,
  );

  @override
  Future<PaginaNotificacionesDto> bandeja({
    int pagina = 1,
    int limite = 10,
  }) async {
    peticiones++;
    if (status != null) throw _error(status!);
    final desde = (pagina - 1) * limite;
    final restantes = total - desde;
    final cuantas = restantes < limite ? restantes : limite;
    return PaginaNotificacionesDto(
      data: [for (var i = 0; i < cuantas; i++) _dto(desde + i)],
      total: total,
      page: pagina,
      limit: limite,
    );
  }

  @override
  Future<int> sinLeer() async {
    if (status != null) throw _error(status!);
    return 3;
  }

  @override
  Future<NotificacionDto> marcarLeida(int id) async {
    ultimaMarcada = id;
    if (status != null) throw _error(status!);
    return _dto(id, leida: true);
  }

  @override
  Future<void> marcarTodasLeidas() async {
    marcarTodas++;
    if (status != null) throw _error(status!);
  }
}

void main() {
  setUpAll(AppTime.init);

  ProviderContainer contenedor(NotificacionesApi api) {
    final c = ProviderContainer(
      retry: PoliticaReintento.decidir,
      overrides: [
        notificacionesRepositoryProvider.overrideWithValue(
          NotificacionesRepository(api),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('RF-28 — la bandeja', () {
    test('camino feliz: mapea lo que llega', () async {
      final c = contenedor(_ApiFalsa());
      final estado = await c.read(bandejaProvider.future);

      expect(estado.pagina.items, hasLength(2));
      expect(estado.pagina.items.first.titulo, 'Cita confirmada 0');
      expect(estado.pagina.items.first.tipo, TipoNotificacion.recordatorio);
      expect(estado.pagina.items.first.idCita, 5);
    });

    test('la fecha es UTC, no la zona del dispositivo', () async {
      final c = contenedor(_ApiFalsa());
      final estado = await c.read(bandejaProvider.future);

      expect(estado.pagina.items.first.enviadaUtc.isUtc, isTrue);
      expect(
        estado.pagina.items.first.enviadaUtc,
        DateTime.utc(2026, 8, 17, 12),
      );
    });

    test('camino de error: el servidor rechaza', () async {
      // 403 y no 503: `PoliticaReintento` reintenta los 5xx dos veces, asi
      // que un 503 no ha terminado de resolverse cuando la prueba mira.
      final c = contenedor(_ApiFalsa(status: 403));
      await expectLater(
        c.read(bandejaProvider.future),
        throwsA(isA<Prohibido>()),
      );
    });

    test('un tipo desconocido falla ruidoso', () async {
      // Pintar un icono generico donde deberia decir "se cancelo tu cita" es
      // peor que no pintar nada.
      final c = contenedor(_ApiFalsa(tipo: 'TELEPATIA'));
      await expectLater(
        c.read(bandejaProvider.future),
        throwsA(isA<ErrorInesperado>()),
      );
    });
  });

  group('RF-29 — paginacion', () {
    test('cargarMas concatena, no reemplaza', () async {
      final c = contenedor(_ApiFalsa(total: 25));
      await c.read(bandejaProvider.future);

      await c.read(bandejaProvider.notifier).cargarMas();
      final estado = c.read(bandejaProvider).value!;

      expect(estado.pagina.items, hasLength(20));
      expect(estado.pagina.items.first.id, 0);
    });

    test('con una sola pagina no pide mas', () async {
      final c = contenedor(_ApiFalsa());
      await c.read(bandejaProvider.future);

      await c.read(bandejaProvider.notifier).cargarMas();

      expect(c.read(bandejaProvider).value!.pagina.items, hasLength(2));
    });
  });

  group('RF-30 — marcar leidas', () {
    test('marcar una es optimista: la lista cambia al instante', () async {
      final api = _ApiFalsa();
      final c = contenedor(api);
      await c.read(bandejaProvider.future);
      expect(c.read(bandejaProvider).value!.pagina.items.first.leida, isFalse);

      final fallo = await c.read(bandejaProvider.notifier).marcarLeida(0);

      expect(fallo, isNull);
      expect(api.ultimaMarcada, 0);
      expect(c.read(bandejaProvider).value!.pagina.items.first.leida, isTrue);
    });

    test('si el servidor la rechaza, se revierte', () async {
      // Dejar tachado algo que el servidor no acepto le mentiria al usuario
      // sobre lo que ya leyo. El 404 significa "esa no es tuya".
      final api = _ApiFalsa();
      final c = contenedor(api);
      // Se carga bien y **despues** se rompe el servidor: si fallara desde el
      // principio no habria lista que revertir.
      await c.read(bandejaProvider.future);
      api.status = 404;

      final fallo = await c.read(bandejaProvider.notifier).marcarLeida(0);

      expect(fallo, isA<NoEncontrado>());
      expect(
        c.read(bandejaProvider).value!.pagina.items.first.leida,
        isFalse,
        reason: 'la marca optimista debe deshacerse',
      );
    });

    test('marcar todas llama al endpoint de una sola vez', () async {
      final api = _ApiFalsa();
      final c = contenedor(api);
      await c.read(bandejaProvider.future);

      final fallo = await c.read(bandejaProvider.notifier).marcarTodasLeidas();

      expect(fallo, isNull);
      // Una sola peticion, no una por notificacion: con veinte sin leer eso
      // serian veinte viajes.
      expect(api.marcarTodas, 1);
    });
  });

  group('RF-29 — cuando falla la pagina siguiente', () {
    test('conserva lo cargado y anota el error', () async {
      final api = _ApiFalsa(total: 25);
      final c = contenedor(api);
      await c.read(bandejaProvider.future);
      api.status = 403;

      await c.read(bandejaProvider.notifier).cargarMas();
      final estado = c.read(bandejaProvider).value!;

      // Un AsyncError global le borraria al usuario la lista y el scroll.
      expect(estado.pagina.items, hasLength(10));
      expect(estado.errorAlPaginar, isA<Prohibido>());
    });

    test('no vuelve a pedir mientras haya error pendiente', () async {
      // El listener del scroll dispara en cada rebote y el usuario que ve el
      // error esta al final de la lista: sin freno, cada rebote es un viaje.
      final api = _ApiFalsa(total: 25);
      final c = contenedor(api);
      await c.read(bandejaProvider.future);
      api.status = 403;
      await c.read(bandejaProvider.notifier).cargarMas();
      final tras = api.peticiones;

      for (var i = 0; i < 5; i++) {
        await c.read(bandejaProvider.notifier).cargarMas();
      }

      expect(api.peticiones, tras);
    });

    test('reintentarPagina limpia el error y concatena', () async {
      final api = _ApiFalsa(total: 25);
      final c = contenedor(api);
      await c.read(bandejaProvider.future);
      api.status = 403;
      await c.read(bandejaProvider.notifier).cargarMas();
      api.status = null;

      await c.read(bandejaProvider.notifier).reintentarPagina();
      final estado = c.read(bandejaProvider).value!;

      expect(estado.errorAlPaginar, isNull);
      expect(estado.pagina.items, hasLength(20));
    });

    test('marcar leida no borra el error del pie', () async {
      // Antes `copiar()` lo limpiaba siempre: el mensaje y el boton
      // desaparecian solos y quedaba un skeleton que no cargaba nada.
      final api = _ApiFalsa(total: 25);
      final c = contenedor(api);
      await c.read(bandejaProvider.future);
      api.status = 403;
      await c.read(bandejaProvider.notifier).cargarMas();
      api.status = null;

      await c.read(bandejaProvider.notifier).marcarLeida(0);

      expect(c.read(bandejaProvider).value!.errorAlPaginar, isA<Prohibido>());
    });
  });

  group('marcar dos seguidas', () {
    test('si falla la primera, la segunda no se destacha', () async {
      // Se revierte solo la afectada. Restaurar la instantanea entera
      // destachaba tambien la que el servidor si acepto — y con red lenta,
      // que es lo que justifica el optimismo, tocar dos seguidas es normal.
      final api = _ApiFalsa(total: 3);
      final c = contenedor(api);
      await c.read(bandejaProvider.future);

      await c.read(bandejaProvider.notifier).marcarLeida(1);
      api.status = 404;
      final fallo = await c.read(bandejaProvider.notifier).marcarLeida(0);

      final items = c.read(bandejaProvider).value!.pagina.items;
      expect(fallo, isA<NoEncontrado>());
      expect(items.firstWhere((n) => n.id == 0).leida, isFalse);
      expect(
        items.firstWhere((n) => n.id == 1).leida,
        isTrue,
        reason: 'el servidor la acepto: no puede destacharse',
      );
    });
  });

  group('marcar todas — camino de error', () {
    test('devuelve el fallo sin recargar la bandeja', () async {
      final api = _ApiFalsa();
      final c = contenedor(api);
      await c.read(bandejaProvider.future);
      api.status = 403;

      final fallo = await c.read(bandejaProvider.notifier).marcarTodasLeidas();

      expect(fallo, isA<Prohibido>());
    });
  });

  group('el contador del badge', () {
    test('devuelve lo que dice el servidor', () async {
      final c = contenedor(_ApiFalsa());
      expect(await c.read(sinLeerProvider.future), 3);
    });

    test('si falla, propaga el error y el widget lo absorbe', () async {
      // Tragarlo dentro del provider lo dejaba fuera de estado de error, y
      // con eso `PoliticaReintento` nunca se activaba: un 503 transitorio que
      // la politica habria recuperado dejaba el badge clavado en cero.
      // La campana ya hace `.value ?? 0`, que es donde corresponde absorberlo.
      final c = contenedor(_ApiFalsa(status: 403));
      await expectLater(
        c.read(sinLeerProvider.future),
        throwsA(isA<Prohibido>()),
      );
    });
  });

  group('antiguedad en lenguaje llano', () {
    Notificacion n(DateTime enviada) => Notificacion(
      id: 1,
      tipo: TipoNotificacion.sistema,
      titulo: 't',
      cuerpo: 'c',
      leida: false,
      enviadaUtc: enviada,
    );

    final ahora = DateTime.utc(2026, 8, 17, 12);

    test('minutos, horas y dias', () {
      // Una bandeja con veinte fechas absolutas obliga a hacer la resta
      // mental; "hace 5 min" se lee de un vistazo.
      expect(
        n(ahora.subtract(const Duration(seconds: 20))).antiguedadDesde(ahora),
        'ahora',
      );
      expect(
        n(ahora.subtract(const Duration(minutes: 5))).antiguedadDesde(ahora),
        'hace 5 min',
      );
      expect(
        n(ahora.subtract(const Duration(hours: 3))).antiguedadDesde(ahora),
        'hace 3 h',
      );
      expect(
        n(ahora.subtract(const Duration(days: 2))).antiguedadDesde(ahora),
        'hace 2 d',
      );
    });

    test('mas de una semana pasa a fecha absoluta', () {
      final texto = n(
        ahora.subtract(const Duration(days: 30)),
      ).antiguedadDesde(ahora);
      expect(texto, isNot(contains('hace')));
    });
  });
}
