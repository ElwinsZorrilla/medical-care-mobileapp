import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'redactor.dart';

/// Log de red **con redacción**, solo en debug.
///
/// Un log con datos clínicos es una fuga (RNF-06). En esta app pasan por la
/// red diagnósticos, recetas, alergias, tipo de sangre y cédulas: nada de eso
/// puede terminar en logcat, donde cualquier app con permiso de lectura de
/// logs —o cualquiera con el teléfono en la mano y `adb`— lo ve.
///
/// La redacción vive en [Redactor]. Acá lo que hay que poder verificar es el
/// **cableado**: que las tres rutas de verdad lo llamen. Por eso el mensaje se
/// arma en funciones puras ([mensajePeticion], [mensajeRespuesta],
/// [mensajeError]) y `_log` solo lo emite. Sin esa costura, borrar un
/// `Redactor.cuerpo(...)` mandaría diagnósticos a logcat sin poner una sola
/// prueba en rojo: `developer.log` no es interceptable de forma portable.
class LoggingInterceptor extends Interceptor {
  const LoggingInterceptor();

  bool get _activo => kDebugMode;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_activo) _log(mensajePeticion(options));
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (_activo) _log(mensajeRespuesta(response));
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (_activo) _log(mensajeError(err));
    handler.next(err);
  }

  @visibleForTesting
  static String mensajePeticion(RequestOptions options) =>
      '→ ${options.method} ${options.path}'
      '${_query(options.queryParameters)}'
      '\n  headers: ${Redactor.cabeceras(options.headers)}'
      '${options.data != null ? '\n  body: ${Redactor.cuerpo(options.data)}' : ''}';

  @visibleForTesting
  static String mensajeRespuesta(Response<dynamic> response) =>
      '← ${response.statusCode} ${response.requestOptions.path}'
      '\n  body: ${Redactor.cuerpo(response.data)}';

  @visibleForTesting
  static String mensajeError(DioException err) =>
      '✕ ${err.response?.statusCode ?? err.type.name} '
      '${err.requestOptions.path}'
      '\n  body: ${Redactor.cuerpo(err.response?.data)}';

  void _log(String mensaje) => developer.log(mensaje, name: 'red');

  /// El query también pasa por el redactor.
  ///
  /// Hoy los únicos parámetros son `page`, `limit`, `fecha` y
  /// `especialidadId`, ninguno sensible. Pero el backend todavía no tiene
  /// búsqueda por texto (BACKEND_ISSUES.md #8), y el día que la tenga el
  /// término natural es un nombre o una cédula. Sin esto, ese valor se
  /// imprimiría en claro mientras el mismo dato en el cuerpo sí se taparía.
  static String _query(Map<String, dynamic> q) => q.isEmpty
      ? ''
      : '?${q.entries.map((e) => '${e.key}='
            '${Redactor.esSensible(e.key) ? Redactor.marca : e.value}').join('&')}';
}
