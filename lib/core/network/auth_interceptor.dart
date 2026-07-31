import 'package:dio/dio.dart';

import '../storage/secure_store.dart';
import 'refresh_interceptor.dart';

/// Pone el `Authorization: Bearer` en cada petición que lo necesite.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._store);

  final SecureStore _store;

  /// Rutas públicas del backend, verificadas en F00.
  ///
  /// Mandarles un token vencido no rompe nada, pero ensucia: `/auth/login`
  /// con un Bearer muerto es ruido en los logs del servidor y confunde a
  /// quien depura.
  static const _publicas = {
    '/auth/login',
    '/auth/register',
    RefreshInterceptor.rutaRefresh,
  };

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_publicas.any(options.path.contains)) {
      return handler.next(options);
    }

    // Si el reintento del refresh ya puso el header, no se pisa: ese token es
    // más nuevo que el que hay en disco.
    if (options.headers.containsKey('Authorization')) {
      return handler.next(options);
    }

    final token = await _store.leerAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    return handler.next(options);
  }
}
