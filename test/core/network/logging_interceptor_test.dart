import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicare/core/network/logging_interceptor.dart';
import 'package:medicare/core/network/redactor.dart';

/// Verifica el **cableado**, no la redacción.
///
/// `Redactor` tiene sus propias pruebas, pero una función pura correcta no
/// protege nada si el interceptor deja de llamarla. Borrar
/// `Redactor.cuerpo(...)` de una de las tres rutas es un cambio de dieciséis
/// caracteres —lo que sale de un merge mal resuelto o de un "lo pongo un
/// momento para depurar"— y sin estas pruebas dejaría diagnósticos y recetas
/// en logcat con la suite entera en verde.
void main() {
  RequestOptions opciones({
    Map<String, dynamic>? headers,
    Object? data,
    Map<String, dynamic>? query,
  }) => RequestOptions(
    path: '/consultations/me',
    method: 'GET',
    headers: headers ?? {},
    data: data,
    queryParameters: query ?? {},
  );

  group('petición', () {
    test('el Authorization no viaja al log', () {
      const jwt = 'eyJhbGciOiJIUzI1NiJ9.cargaUtil.firma';
      final salida = LoggingInterceptor.mensajePeticion(
        opciones(headers: {'Authorization': 'Bearer $jwt'}),
      );

      expect(salida, isNot(contains(jwt)));
      expect(salida, contains(Redactor.marca));
    });

    test('la contraseña del login tampoco', () {
      final salida = LoggingInterceptor.mensajePeticion(
        opciones(
          data: {'correo': 'paciente@correo.com', 'contrasena': 'Passw0rd!23'},
        ),
      );

      expect(salida, isNot(contains('Passw0rd!23')));
      expect(salida, isNot(contains('paciente@correo.com')));
    });

    test('un cuerpo clínico tampoco', () {
      final salida = LoggingInterceptor.mensajePeticion(
        opciones(data: {'idCita': 5, 'diagnostico': 'VIH positivo'}),
      );

      expect(salida, isNot(contains('VIH positivo')));
      // Lo que no es sensible se conserva: un log sin nada útil no sirve.
      expect(salida, contains('idCita'));
    });

    test('sin cuerpo no inventa la sección body', () {
      expect(
        LoggingInterceptor.mensajePeticion(opciones()),
        isNot(contains('body:')),
      );
    });
  });

  group('respuesta', () {
    Response<dynamic> respuesta(Object? data) => Response<dynamic>(
      requestOptions: opciones(),
      statusCode: 200,
      data: data,
    );

    test('el diagnóstico anidado en una página no aparece', () {
      // Así es exactamente como viaja: dentro de `data[]`.
      final salida = LoggingInterceptor.mensajeRespuesta(
        respuesta({
          'data': [
            {
              'idConsulta': 11,
              'diagnostico': 'Cáncer de tiroides',
              'recetas': [
                {'medicamento': 'Levotiroxina', 'dosis': '75mcg'},
              ],
            },
          ],
          'total': 1,
        }),
      );

      expect(salida, isNot(contains('Cáncer de tiroides')));
      expect(salida, isNot(contains('Levotiroxina')));
      expect(salida, contains('total'));
    });

    test('la ficha del paciente no deja identificarlo', () {
      final salida = LoggingInterceptor.mensajeRespuesta(
        respuesta({
          'idPaciente': 3,
          'documentoIdentidad': '00112345678',
          'fechaNacimiento': '1990-05-02',
          'direccion': 'Calle Duarte 45, Santo Domingo',
          'alergias': 'Penicilina',
        }),
      );

      for (final dato in [
        '00112345678',
        '1990-05-02',
        'Calle Duarte 45',
        'Penicilina',
      ]) {
        expect(salida, isNot(contains(dato)), reason: '$dato quedó en el log');
      }
    });
  });

  group('error', () {
    test('el cuerpo del error también se redacta', () {
      final o = opciones();
      final salida = LoggingInterceptor.mensajeError(
        DioException(
          requestOptions: o,
          response: Response<dynamic>(
            requestOptions: o,
            statusCode: 409,
            data: {'message': 'conflicto', 'diagnostico': 'Sospecha de VIH'},
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      expect(salida, isNot(contains('Sospecha de VIH')));
      expect(salida, contains('409'));
    });

    test('sin respuesta usa el tipo y no revienta', () {
      final salida = LoggingInterceptor.mensajeError(
        DioException(
          requestOptions: opciones(),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      expect(salida, contains('connectionTimeout'));
    });
  });

  group('query', () {
    test('los parámetros normales se ven: sirven para depurar', () {
      final salida = LoggingInterceptor.mensajePeticion(
        opciones(query: {'page': 2, 'limit': 10}),
      );

      expect(salida, contains('page=2'));
      expect(salida, contains('limit=10'));
    });

    test('un parámetro sensible no', () {
      // El backend todavía no tiene búsqueda por texto; cuando la tenga, el
      // término natural es una cédula o un nombre.
      final salida = LoggingInterceptor.mensajePeticion(
        opciones(query: {'documentoIdentidad': '00112345678'}),
      );

      expect(salida, isNot(contains('00112345678')));
    });
  });
}
