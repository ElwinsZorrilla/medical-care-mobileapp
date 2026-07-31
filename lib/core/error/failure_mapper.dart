import 'package:dio/dio.dart';

import 'failure.dart';

/// Traduce lo que sale de `dio` a un [Failure] de dominio.
///
/// Vive en la capa de datos. **Una `DioException` no debe llegar nunca a un
/// widget**: la presentación habla con repositorios, no con HTTP.
///
/// El mapeo está calibrado contra el backend real, verificado en F00. Ver
/// docs/API_CONTRACT.md §10.
abstract final class FailureMapper {
  /// Rutas donde un `400` significa "turno inválido" y no "campo mal puesto".
  static const _rutasReserva = '/appointments';

  static Failure desdeDio(DioException e) => switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.connectionError => const SinConexion(),
    DioExceptionType.cancel => const ErrorInesperado('Petición cancelada.'),
    // No es falta de red: la respuesta llegó y se tardó demasiado en
    // transformarla. Decirle "sin conexión" al usuario mandaría a revisar el
    // wifi por un problema que no está ahí.
    DioExceptionType.transformTimeout => const ErrorInesperado(
      'La respuesta tardó demasiado en procesarse.',
    ),
    DioExceptionType.badCertificate => const ErrorInesperado(
      'No pudimos verificar la identidad del servidor.',
    ),
    DioExceptionType.badResponse => _desdeRespuesta(e),
    DioExceptionType.unknown =>
      e.error is FormatException
          ? const ErrorInesperado('El servidor respondió algo inesperado.')
          : const SinConexion(),
  };

  static Failure _desdeRespuesta(DioException e) {
    final status = e.response?.statusCode ?? 0;
    final mensajes = _mensajes(e.response?.data);
    final texto = mensajes.join(' ');

    return switch (status) {
      400 => _desde400(e, mensajes, texto),
      401 => const NoAutorizado(),
      403 => Prohibido(
        texto.isEmpty ? 'No tienes permiso para hacer esto.' : texto,
      ),
      404 => NoEncontrado(
        texto.isEmpty ? 'No encontramos lo que buscabas.' : texto,
      ),
      409 => Conflicto(
        texto.isEmpty ? 'Esa acción ya no es posible.' : texto,
        mensajeServidor: texto,
      ),
      422 => Validacion(
        texto.isEmpty ? 'Revisa los datos ingresados.' : texto,
        errores: mensajes,
      ),
      >= 500 => const ErrorServidor(),
      _ => const ErrorInesperado(),
    };
  }

  /// `400` tiene dos significados según de dónde venga.
  ///
  /// En `POST /appointments` quiere decir "ese turno no corresponde a ninguna
  /// franja": la grilla del usuario quedó vieja y hay que refrescarla. En
  /// cualquier otra ruta es validación de formulario. Mapearlos igual haría
  /// que un turno vencido se pintara como campo inválido.
  static Failure _desde400(
    DioException e,
    List<String> mensajes,
    String texto,
  ) {
    final ruta = e.requestOptions.path;
    final esReserva =
        ruta.contains(_rutasReserva) &&
        e.requestOptions.method.toUpperCase() == 'POST';

    if (esReserva && texto.toLowerCase().contains('franja')) {
      return const TurnoInvalido();
    }
    return Validacion(
      texto.isEmpty ? 'Revisa los datos ingresados.' : texto,
      errores: mensajes,
    );
  }

  /// Normaliza el `message` del backend.
  ///
  /// NestJS lo manda como **string o arreglo de strings** según el caso: un
  /// 401 sin token trae `"Unauthorized"`, y una validación trae la lista de
  /// reglas incumplidas. El parser tiene que aguantar las dos formas, y no
  /// puede exigir la clave `error` porque el 401 no la trae.
  static List<String> _mensajes(Object? data) {
    if (data is! Map) return const [];
    final mensaje = data['message'];
    return switch (mensaje) {
      final String s when s.isNotEmpty => [s],
      final List<dynamic> l => l.map((e) => e.toString()).toList(),
      _ => const [],
    };
  }
}
