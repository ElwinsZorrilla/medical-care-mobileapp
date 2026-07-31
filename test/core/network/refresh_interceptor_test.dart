import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicare/core/network/auth_interceptor.dart';
import 'package:medicare/core/network/refresh_interceptor.dart';
import 'package:medicare/core/storage/secure_store.dart';

/// Doble en memoria del almacén seguro.
class _StoreFalso implements SecureStore {
  String? access = 'access-viejo';
  String? refresh = 'refresh-ok';

  int limpiezas = 0;

  @override
  Future<String?> leerAccessToken() async => access;

  @override
  Future<String?> leerRefreshToken() async => refresh;

  @override
  Future<void> guardarTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    access = accessToken;
    refresh = refreshToken;
  }

  @override
  Future<void> limpiar() async {
    access = null;
    refresh = null;
    limpiezas++;
  }
}

/// Backend simulado a nivel de **transporte**.
///
/// Se reemplaza el `HttpClientAdapter` en vez de meter un interceptor falso:
/// así la petición recorre la cadena de interceptores real —que es
/// justamente lo que estas pruebas verifican— y solo se finge la salida a la
/// red. Un fake puesto como interceptor competiría con el orden de la cadena
/// y probaría otra cosa.
class _TransporteFalso implements HttpClientAdapter {
  _TransporteFalso({
    this.refreshFalla = false,
    this.demoraRefresh = Duration.zero,
  });

  final bool refreshFalla;

  /// Simula latencia. Sin demora, las peticiones "concurrentes" se
  /// resolverían una tras otra y la prueba de single-flight pasaría aunque
  /// el código estuviera mal.
  final Duration demoraRefresh;

  int refreshRecibidos = 0;
  final List<String?> tokensVistos = [];

  ResponseBody _json(Map<String, dynamic> cuerpo, int status) =>
      ResponseBody.fromString(
        jsonEncode(cuerpo),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final auth = options.headers['Authorization'] as String?;

    if (options.path.contains('/auth/refresh')) {
      refreshRecibidos++;
      if (demoraRefresh > Duration.zero) {
        await Future<void>.delayed(demoraRefresh);
      }
      if (refreshFalla) {
        return _json({'message': 'Refresh token inválido o expirado'}, 401);
      }
      // El backend responde 201, no 200 (verificado en F00).
      return _json({
        'accessToken': 'access-nuevo',
        'refreshToken': 'refresh-nuevo',
      }, 201);
    }

    // Rutas públicas: no requieren token.
    if (options.path.contains('/auth/login') ||
        options.path.contains('/auth/register')) {
      tokensVistos.add(auth);
      return _json({
        'accessToken': 'access-viejo',
        'refreshToken': 'refresh-ok',
      }, 201);
    }

    tokensVistos.add(auth);
    if (auth == 'Bearer access-nuevo') {
      return _json({'ok': true}, 200);
    }
    return _json({'message': 'Unauthorized', 'statusCode': 401}, 401);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _StoreFalso store;
  late _TransporteFalso transporte;
  late Dio dio;
  late RefreshInterceptor refresco;
  late int sesionesExpiradas;

  void armar({bool refreshFalla = false, Duration demora = Duration.zero}) {
    store = _StoreFalso();
    transporte = _TransporteFalso(
      refreshFalla: refreshFalla,
      demoraRefresh: demora,
    );
    sesionesExpiradas = 0;

    final opciones = BaseOptions(baseUrl: 'http://test');

    final dioRefresh = Dio(opciones)..httpClientAdapter = transporte;

    refresco = RefreshInterceptor(
      store: store,
      dioRefresh: dioRefresh,
      onSesionExpirada: () async => sesionesExpiradas++,
    );

    dio = Dio(opciones)
      ..httpClientAdapter = transporte
      ..interceptors.addAll([AuthInterceptor(store), refresco]);
  }

  group('single-flight — RF-04', () {
    test('5 peticiones con 401 en paralelo disparan UN solo refresh', () async {
      // La prueba que justifica todo el diseño del interceptor.
      armar(demora: const Duration(milliseconds: 50));

      final respuestas = await Future.wait([
        for (var i = 0; i < 5; i++) dio.get<dynamic>('/appointments/me'),
      ]);

      expect(transporte.refreshRecibidos, 1, reason: 'un solo refresh');
      expect(refresco.refrescosDisparados, 1);
      expect(respuestas.every((r) => r.statusCode == 200), isTrue);
    });

    test('las 5 reintentan con el token nuevo', () async {
      armar(demora: const Duration(milliseconds: 50));

      await Future.wait([
        for (var i = 0; i < 5; i++) dio.get<dynamic>('/appointments/me'),
      ]);

      final conTokenNuevo = transporte.tokensVistos
          .where((t) => t == 'Bearer access-nuevo')
          .length;
      expect(conTokenNuevo, 5);
    });

    test('el token nuevo queda guardado', () async {
      armar();
      await dio.get<dynamic>('/appointments/me');
      expect(store.access, 'access-nuevo');
      expect(store.refresh, 'refresh-nuevo');
    });

    test('un refresh posterior vuelve a dispararse', () async {
      armar();
      await dio.get<dynamic>('/appointments/me');
      expect(refresco.refrescosDisparados, 1);

      // Se vence otra vez: debe poder refrescar de nuevo, no quedar trabado
      // por un flag que nunca se libera.
      store.access = 'access-viejo';
      await dio.get<dynamic>('/appointments/me');
      expect(refresco.refrescosDisparados, 2);
    });
  });

  group('refresh fallido', () {
    test('limpia la sesión y avisa', () async {
      armar(refreshFalla: true);

      await expectLater(
        dio.get<dynamic>('/appointments/me'),
        throwsA(isA<DioException>()),
      );

      expect(store.limpiezas, greaterThanOrEqualTo(1));
      expect(store.access, isNull);
      expect(store.refresh, isNull);
      expect(sesionesExpiradas, greaterThanOrEqualTo(1));
    });

    test('sin refresh token guardado no llama al backend', () async {
      armar();
      store.refresh = null;

      await expectLater(
        dio.get<dynamic>('/appointments/me'),
        throwsA(isA<DioException>()),
      );

      expect(
        transporte.refreshRecibidos,
        0,
        reason: 'no hay nada que refrescar',
      );
      expect(sesionesExpiradas, 1);
    });
  });

  group('el refresh nunca se reintenta a sí mismo', () {
    test('un 401 en /auth/refresh no dispara otro refresh', () async {
      armar(refreshFalla: true);

      await expectLater(
        dio.post<dynamic>('/auth/refresh', data: {'refreshToken': 'x'}),
        throwsA(isA<DioException>()),
      );

      // Exactamente uno: el que se pidió. Si se reintentara habría dos o
      // más, y con recursión no terminaría nunca.
      expect(transporte.refreshRecibidos, 1);
    });
  });

  group('AuthInterceptor', () {
    test('no manda Authorization a las rutas públicas', () async {
      armar();
      await dio.post<dynamic>('/auth/login', data: {'correo': 'a@b.com'});
      expect(transporte.tokensVistos.last, isNull);
    });

    test('inyecta el Bearer en las rutas protegidas', () async {
      armar();
      await dio.get<dynamic>('/appointments/me');
      expect(transporte.tokensVistos.first, 'Bearer access-viejo');
    });
  });
}
