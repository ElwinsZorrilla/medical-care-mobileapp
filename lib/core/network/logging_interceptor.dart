import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Log de red **con redacción**, solo en debug.
///
/// Un log con datos clínicos es una fuga (RNF-06). En esta app pasan por la
/// red diagnósticos, recetas, alergias, tipo de sangre y cédulas: nada de eso
/// puede terminar en logcat, donde cualquier app con permiso de lectura de
/// logs —o cualquiera con el teléfono en la mano y `adb`— lo ve.
///
/// La lista de campos sensibles es **allowlist invertida a propósito**: se
/// redacta por nombre de campo conocido y, ante la duda, se prefiere redactar
/// de más. Un log menos útil es barato; una historia clínica en claro no.
class LoggingInterceptor extends Interceptor {
  const LoggingInterceptor();

  static const _redactado = '«redactado»';

  /// Cabeceras que nunca se imprimen.
  static const _cabecerasSensibles = {'authorization', 'cookie', 'set-cookie'};

  /// Campos que nunca se imprimen, ni en petición ni en respuesta.
  static const _camposSensibles = {
    // Credenciales y sesión
    'contrasena', 'password', 'accessToken', 'refreshToken', 'token',
    // Identidad
    'documentoIdentidad', 'cedula', 'correo', 'telefono',
    // Clínicos — RNF-06
    'diagnostico', 'tratamiento', 'observaciones', 'signosVitales',
    'alergias', 'tipoSangre', 'medicamento', 'dosis', 'frecuencia',
    'indicaciones', 'motivoConsulta', 'recetas', 'seguroMedico',
  };

  bool get _activo => kDebugMode;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_activo) {
      _log(
        '→ ${options.method} ${options.path}'
        '${_query(options.queryParameters)}'
        '\n  headers: ${_limpiarCabeceras(options.headers)}'
        '${options.data != null ? '\n  body: ${_limpiar(options.data)}' : ''}',
      );
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (_activo) {
      _log(
        '← ${response.statusCode} ${response.requestOptions.path}'
        '\n  body: ${_limpiar(response.data)}',
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (_activo) {
      _log(
        '✕ ${err.response?.statusCode ?? err.type.name} '
        '${err.requestOptions.path}'
        '\n  body: ${_limpiar(err.response?.data)}',
      );
    }
    handler.next(err);
  }

  void _log(String mensaje) => developer.log(mensaje, name: 'red');

  String _query(Map<String, dynamic> q) => q.isEmpty
      ? ''
      : '?${q.entries.map((e) => '${e.key}=${e.value}').join('&')}';

  Map<String, dynamic> _limpiarCabeceras(Map<String, dynamic> headers) => {
    for (final e in headers.entries)
      e.key: _cabecerasSensibles.contains(e.key.toLowerCase())
          ? _redactado
          : e.value,
  };

  /// Recorre el árbol y reemplaza los campos sensibles a cualquier profundidad.
  Object? _limpiar(Object? dato) => switch (dato) {
    final Map<dynamic, dynamic> m => {
      for (final e in m.entries)
        e.key: _camposSensibles.contains(e.key.toString())
            ? _redactado
            : _limpiar(e.value),
    },
    final List<dynamic> l => l.map(_limpiar).toList(),
    _ => dato,
  };
}
