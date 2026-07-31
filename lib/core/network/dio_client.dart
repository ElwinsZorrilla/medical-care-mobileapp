import 'package:dio/dio.dart';

import '../config/env.dart';
import '../storage/secure_store.dart';
import 'auth_interceptor.dart';
import 'logging_interceptor.dart';
import 'refresh_interceptor.dart';

/// Arma el cliente HTTP del proyecto.
abstract final class DioClient {
  /// 15s. Suficiente para una red móvil lenta de RD, corto como para que el
  /// usuario no se quede mirando un spinner sin saber si pasó algo.
  static const timeout = Duration(seconds: 15);

  static Dio crear({
    required SecureStore store,
    required Future<void> Function() onSesionExpirada,
    String? baseUrl,
  }) {
    final url = baseUrl ?? Env.apiBaseUrl;

    // Cliente aparte para el refresh y los reintentos. Comparte baseUrl y
    // timeouts pero **no** los interceptores de auth: si el refresh pasara
    // por RefreshInterceptor, un 401 suyo volvería a entrar ahí y quedaría
    // en recursión.
    final dioRefresh = Dio(_opciones(url));

    final dio = Dio(_opciones(url))
      ..interceptors.addAll([
        AuthInterceptor(store),
        RefreshInterceptor(
          store: store,
          dioRefresh: dioRefresh,
          onSesionExpirada: onSesionExpirada,
        ),
        const LoggingInterceptor(),
      ]);

    return dio;
  }

  static BaseOptions _opciones(String baseUrl) => BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: timeout,
    receiveTimeout: timeout,
    sendTimeout: timeout,
    contentType: Headers.jsonContentType,
    responseType: ResponseType.json,
    // El backend responde 201 en login y refresh, no 200 (F00). Cualquier
    // 2xx es éxito; el resto lo clasifica FailureMapper.
    validateStatus: (status) => status != null && status >= 200 && status < 300,
  );
}
