import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicare/core/error/failure.dart';
import 'package:medicare/core/error/failure_mapper.dart';

/// Cada código HTTP tiene que caer en su `Failure`.
///
/// Las formas de respuesta están copiadas de lo que devolvió el backend real
/// durante F00, no inventadas. Ver docs/API_CONTRACT.md §10.
void main() {
  DioException conRespuesta(
    int status,
    Object? data, {
    String path = '/specialties',
    String metodo = 'GET',
  }) {
    final options = RequestOptions(path: path, method: metodo);
    return DioException(
      requestOptions: options,
      response: Response<dynamic>(
        requestOptions: options,
        statusCode: status,
        data: data,
      ),
      type: DioExceptionType.badResponse,
    );
  }

  group('códigos HTTP', () {
    test(
      '401 → NoAutorizado (sin la clave "error", como manda el backend)',
      () {
        final f = FailureMapper.desdeDio(
          conRespuesta(401, {'message': 'Unauthorized', 'statusCode': 401}),
        );
        expect(f, isA<NoAutorizado>());
      },
    );

    test('403 → Prohibido, con el mensaje del servidor', () {
      final f = FailureMapper.desdeDio(
        conRespuesta(403, {
          'message': 'No tienes permisos para acceder a este recurso',
        }),
      );
      expect(f, isA<Prohibido>());
      expect(f.mensaje, contains('permisos'));
    });

    test('404 → NoEncontrado', () {
      final f = FailureMapper.desdeDio(
        conRespuesta(404, {'message': 'Cita no encontrada'}),
      );
      expect(f, isA<NoEncontrado>());
    });

    test('500 → ErrorServidor', () {
      expect(
        FailureMapper.desdeDio(conRespuesta(500, null)),
        isA<ErrorServidor>(),
      );
    });

    test('503 → ErrorServidor', () {
      expect(
        FailureMapper.desdeDio(conRespuesta(503, null)),
        isA<ErrorServidor>(),
      );
    });
  });

  group('409 — RF-20, el caso central', () {
    test('turno tomado → Conflicto que pide refrescar la grilla', () {
      final f = FailureMapper.desdeDio(
        conRespuesta(409, {'message': 'Ese turno ya fue reservado'}),
      );
      expect(f, isA<Conflicto>());
      expect((f as Conflicto).esTurnoTomado, isTrue);
    });

    test('perder la carrera también cuenta como turno tomado', () {
      final f =
          FailureMapper.desdeDio(
                conRespuesta(409, {
                  'message': 'Ese turno ya fue reservado por otro paciente',
                }),
              )
              as Conflicto;
      expect(f.esTurnoTomado, isTrue);
    });

    test('modalidad equivocada NO pide refrescar', () {
      // Mismo 409, otra causa. Refrescar la grilla acá haría perder al
      // usuario la selección sin arreglar nada: lo que falla es la modalidad.
      final f =
          FailureMapper.desdeDio(
                conRespuesta(409, {
                  'message': 'Ese turno solo admite modalidad PRESENCIAL',
                }),
              )
              as Conflicto;
      expect(f.esTurnoTomado, isFalse);
    });

    test('correo repetido en registro también es 409', () {
      final f = FailureMapper.desdeDio(
        conRespuesta(409, {'message': 'El correo ya está registrado'}),
      );
      expect(f, isA<Conflicto>());
      expect((f as Conflicto).esTurnoTomado, isFalse);
    });
  });

  group('400 — dos significados distintos', () {
    test('validación → Validacion con la lista de reglas', () {
      final f =
          FailureMapper.desdeDio(
                conRespuesta(400, {
                  'message': [
                    'correo must be an email',
                    'contrasena must be longer than or equal to 8 characters',
                  ],
                  'error': 'Bad Request',
                  'statusCode': 400,
                }),
                // path por defecto, no es reserva
              )
              as Validacion;
      expect(f.errores, hasLength(2));
    });

    test('campo de más también es 400 (forbidNonWhitelisted)', () {
      final f = FailureMapper.desdeDio(
        conRespuesta(400, {
          'message': ['property campoExtra should not exist'],
        }),
      );
      expect(f, isA<Validacion>());
    });

    test('turno fuera de franja → TurnoInvalido, no Validacion', () {
      // El hallazgo de F00: en POST /appointments el 400 no es un error de
      // formulario. Mapearlo a Validacion pintaría un campo en rojo cuando
      // lo que hay que hacer es refrescar los turnos.
      final f = FailureMapper.desdeDio(
        conRespuesta(
          400,
          {
            'message':
                'Ese turno no corresponde a ninguna franja de disponibilidad del médico',
          },
          path: '/appointments',
          metodo: 'POST',
        ),
      );
      expect(f, isA<TurnoInvalido>());
    });

    test('un 400 de validación en /appointments sigue siendo Validacion', () {
      final f = FailureMapper.desdeDio(
        conRespuesta(
          400,
          {
            'message': ['idMedico must be an integer'],
          },
          path: '/appointments',
          metodo: 'POST',
        ),
      );
      expect(f, isA<Validacion>());
    });
  });

  group('problemas de red', () {
    for (final tipo in [
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.connectionError,
    ]) {
      test('$tipo → SinConexion', () {
        final f = FailureMapper.desdeDio(
          DioException(
            requestOptions: RequestOptions(path: '/x'),
            type: tipo,
          ),
        );
        expect(f, isA<SinConexion>());
      });
    }

    test('certificado inválido no se traga en silencio', () {
      final f = FailureMapper.desdeDio(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.badCertificate,
        ),
      );
      expect(f, isA<ErrorInesperado>());
    });
  });

  group('mensajes', () {
    test('todos vienen en español y listos para pintar', () {
      final fallos = <Failure>[
        const SinConexion(),
        const SesionExpirada(),
        const Prohibido(),
        const NoEncontrado(),
        const TurnoInvalido(),
        const ErrorServidor(),
        const ErrorInesperado(),
      ];
      for (final f in fallos) {
        expect(f.mensaje, isNotEmpty);
        // Nada de códigos crudos filtrándose al usuario.
        expect(f.mensaje, isNot(contains('Exception')));
        expect(f.mensaje, isNot(matches(RegExp(r'\b[45]\d\d\b'))));
      }
    });

    test('respuesta sin cuerpo no deja el mensaje vacío', () {
      final f = FailureMapper.desdeDio(conRespuesta(409, null));
      expect(f.mensaje, isNotEmpty);
    });
  });
}
