import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicare/core/error/failure.dart';
import 'package:medicare/core/network/politica_reintento.dart';

/// El reintento automático no es una optimización: decide cuánto tiempo el
/// usuario se queda mirando un skeleton en vez de un error que puede accionar.
void main() {
  group('qué se reintenta', () {
    test('un 5xx sí: puede salir distinto sin que el usuario cambie nada', () {
      expect(PoliticaReintento.decidir(0, const ErrorServidor()), isNotNull);
    });

    test('un bache de red también', () {
      expect(PoliticaReintento.decidir(0, const SinConexion()), isNotNull);
    });
  });

  group('qué no se reintenta', () {
    test('el 409 de turno tomado — RF-20', () {
      // Reintentar acá vuelve a pedir un turno que ya se sabe ocupado, y le
      // esconde al usuario los ~1.2 s que podría estar eligiendo otro.
      expect(
        PoliticaReintento.decidir(
          0,
          const Conflicto('Ese turno ya lo tomaron.'),
        ),
        isNull,
      );
    });

    test('un 403: insistir en un recurso ajeno no lo vuelve propio', () {
      expect(PoliticaReintento.decidir(0, const Prohibido()), isNull);
    });

    test('una sesión expirada: la resuelve el refresh, no la repetición', () {
      expect(PoliticaReintento.decidir(0, const SesionExpirada()), isNull);
      expect(PoliticaReintento.decidir(0, const NoAutorizado()), isNull);
    });

    test('validación, 404 y turno inválido tampoco', () {
      expect(PoliticaReintento.decidir(0, const Validacion('x')), isNull);
      expect(PoliticaReintento.decidir(0, const NoEncontrado()), isNull);
      expect(PoliticaReintento.decidir(0, const TurnoInvalido()), isNull);
    });

    test('lo inesperado se muestra, no se repite', () {
      // Un parseo roto se repite igual de roto; esconderlo tres veces solo
      // retrasa el reporte.
      expect(PoliticaReintento.decidir(0, const ErrorInesperado()), isNull);
    });

    test('lo que no es Failure se deja subir', () {
      expect(PoliticaReintento.decidir(0, StateError('bug')), isNull);
      expect(PoliticaReintento.decidir(0, Exception('x')), isNull);
    });
  });

  group('cuánto espera', () {
    test('para a los dos intentos', () {
      expect(PoliticaReintento.decidir(2, const ErrorServidor()), isNull);
      expect(PoliticaReintento.decidir(9, const ErrorServidor()), isNull);
    });

    test('el segundo intento espera más que el primero', () {
      final primero = PoliticaReintento.decidir(0, const ErrorServidor())!;
      final segundo = PoliticaReintento.decidir(1, const ErrorServidor())!;
      expect(segundo, greaterThan(primero));
    });

    test('en el peor caso el error aparece antes de dos segundos', () {
      // El límite de verdad: cuánto aguanta el usuario sin señal de nada.
      var total = Duration.zero;
      for (var i = 0; ; i++) {
        final espera = PoliticaReintento.decidir(i, const ErrorServidor());
        if (espera == null) break;
        total += espera;
      }
      expect(total, lessThan(const Duration(seconds: 2)));
    });
  });

  group('contra el comportamiento por omisión de Riverpod', () {
    test('el default habría tardado más de 30 segundos', () {
      // Este es el número que motiva la política. Si una versión futura de
      // Riverpod cambia su default, esta prueba lo avisa en vez de dejar la
      // justificación escrita apuntando a algo que ya no es cierto.
      var total = Duration.zero;
      for (var i = 0; ; i++) {
        final espera = ProviderContainer.defaultRetry(i, const ErrorServidor());
        if (espera == null) break;
        total += espera;
      }
      expect(total, greaterThan(const Duration(seconds: 30)));
    });

    test('el default habría reintentado hasta un 409', () {
      expect(
        ProviderContainer.defaultRetry(0, const Conflicto('turno tomado')),
        isNotNull,
      );
    });
  });
}
