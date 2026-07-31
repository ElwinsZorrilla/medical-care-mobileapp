import 'dart:async';

import 'package:dio/dio.dart';

import '../storage/secure_store.dart';

/// Renueva el access token cuando vence, **una sola vez** aunque fallen N
/// peticiones a la vez — RF-04.
///
/// ## Por qué un `Completer` y no un `bool`
///
/// El escenario real: la pantalla de agenda dispara cinco peticiones en
/// paralelo al abrirse. El token venció. Las cinco reciben 401 casi
/// simultáneamente.
///
/// Con un booleano `_refrescando`, entre que la primera lo pone en `true` y
/// termina el refresh, las otras cuatro ya evaluaron el `if` y también
/// disparan. Salen cinco refresh. El booleano no da nada que esperar: solo
/// dice "hay uno en curso", no *cuál*.
///
/// Con un `Completer<String>?` compartido, la primera lo crea y las otras
/// cuatro **esperan ese mismo `Future`** y reintentan con el token que
/// devuelva. Un solo refresh, cuatro reintentos.
///
/// ## Qué cambia con este backend
///
/// F00 verificó que `/auth/refresh` **rota el par pero no revoca el
/// anterior**: es `verifyAsync` sin store. O sea que N refresh concurrentes
/// no expulsarían al usuario como pasa en backends con rotación estricta.
///
/// Aun así el single-flight es obligatorio: sin él, cinco refresh en vuelo
/// escriben el token en `SecureStore` en orden indeterminado, y la app puede
/// terminar guardando un par distinto del que dejó en memoria. Además es
/// gratis y protege si el backend agrega revocación después.
class RefreshInterceptor extends QueuedInterceptor {
  // Dart no permite parametros con nombre privados: `required this._store`
  // no compila. Los campos deben seguir siendo privados, asi que la
  // sugerencia del lint —que solo aplica a posicionales— no es viable aca.
  // ignore_for_file: prefer_initializing_formals
  RefreshInterceptor({
    required SecureStore store,
    required Dio dioRefresh,
    required this.onSesionExpirada,
  }) : _store = store,
       _dioRefresh = dioRefresh;

  /// Ruta que **nunca** se reintenta a sí misma.
  static const rutaRefresh = '/auth/refresh';

  final SecureStore _store;

  /// Cliente aparte, sin este interceptor. Si el refresh usara el mismo Dio
  /// que las peticiones normales, un 401 del propio refresh volvería a
  /// entrar acá y quedaría en recursión.
  final Dio _dioRefresh;

  /// Se llama cuando la sesión ya no se puede recuperar: limpiar y a login.
  final Future<void> Function() onSesionExpirada;

  /// El refresh en vuelo, si lo hay. **Este campo es el mecanismo.**
  Completer<String?>? _enVuelo;

  /// Cuántos refresh se dispararon. Solo para pruebas.
  int get refrescosDisparados => _refrescos;
  int _refrescos = 0;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final esNoAutorizado = err.response?.statusCode == 401;
    final esElRefresh = err.requestOptions.path.contains(rutaRefresh);

    // Un 401 en el refresh significa sesión muerta, punto. Reintentarlo sería
    // pedirle a un token invalido que se valide a sí mismo.
    if (!esNoAutorizado || esElRefresh) {
      return handler.next(err);
    }

    // Ya se reintentó esta petición una vez: si vuelve a dar 401 con un token
    // nuevo, el problema no es el token.
    if (err.requestOptions.extra['reintentado'] == true) {
      await _cerrarSesion();
      return handler.next(err);
    }

    // ¿El token ya lo renovó alguien más mientras esta petición estaba en
    // vuelo? Entonces no hay nada que refrescar: basta reintentar con el que
    // hay guardado.
    //
    // Sin esta comprobación el single-flight no se sostiene. `QueuedInterceptor`
    // serializa los `onError`, así que cuando entra el segundo el `Completer`
    // del primero ya se liberó, y cada petición dispararía su propio refresh:
    // cinco 401 en paralelo daban cinco refresh. El `Completer` cubre las que
    // coinciden en el tiempo; esta comprobación cubre las que llegan después.
    final usado = err.requestOptions.headers['Authorization'] as String?;
    final guardado = await _store.leerAccessToken();
    if (guardado != null &&
        guardado.isNotEmpty &&
        usado != 'Bearer $guardado') {
      try {
        return handler.resolve(await _reintentar(err.requestOptions, guardado));
      } on DioException catch (e) {
        return handler.next(e);
      }
    }

    final tokenNuevo = await _refrescar();
    if (tokenNuevo == null) {
      return handler.next(err);
    }

    try {
      final respuesta = await _reintentar(err.requestOptions, tokenNuevo);
      return handler.resolve(respuesta);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }

  /// Devuelve el access token nuevo, o `null` si la sesión murió.
  ///
  /// Si ya hay uno en vuelo, se cuelga de ese en vez de disparar otro.
  Future<String?> _refrescar() {
    final enCurso = _enVuelo;
    if (enCurso != null) return enCurso.future;

    final completer = Completer<String?>();
    _enVuelo = completer;

    unawaited(
      _hacerRefresh()
          .then(completer.complete)
          .catchError((Object _) => completer.complete(null))
          // Se libera *después* de completar, para que ningún 401 que llegue
          // en el intermedio cree un segundo refresh contra el mismo token.
          .whenComplete(() => _enVuelo = null),
    );

    return completer.future;
  }

  Future<String?> _hacerRefresh() async {
    _refrescos++;

    final refreshToken = await _store.leerRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await _cerrarSesion();
      return null;
    }

    try {
      final res = await _dioRefresh.post<Map<String, dynamic>>(
        rutaRefresh,
        data: {'refreshToken': refreshToken},
      );

      final datos = res.data;
      final access = datos?['accessToken'] as String?;
      final refresh = datos?['refreshToken'] as String?;
      if (access == null || refresh == null) {
        await _cerrarSesion();
        return null;
      }

      await _store.guardarTokens(accessToken: access, refreshToken: refresh);
      return access;
    } on DioException {
      await _cerrarSesion();
      return null;
    }
  }

  Future<Response<dynamic>> _reintentar(RequestOptions original, String token) {
    final opciones = Options(
      method: original.method,
      headers: {...original.headers, 'Authorization': 'Bearer $token'},
      responseType: original.responseType,
      contentType: original.contentType,
      // Marca para no entrar en un bucle de reintentos.
      extra: {...original.extra, 'reintentado': true},
    );

    return _dioRefresh.request<dynamic>(
      original.path,
      data: original.data,
      queryParameters: original.queryParameters,
      options: opciones,
    );
  }

  Future<void> _cerrarSesion() async {
    await _store.limpiar();
    await onSesionExpirada();
  }
}
