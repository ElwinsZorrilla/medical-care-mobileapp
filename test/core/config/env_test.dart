import 'package:flutter_test/flutter_test.dart';
import 'package:medicare/core/config/env.dart';

void main() {
  group('Env.validarBaseUrl', () {
    test('acepta una URL http absoluta', () {
      expect(
        () => Env.validarBaseUrl('http://10.0.2.2:3000/api'),
        returnsNormally,
      );
    });

    test('acepta https', () {
      expect(
        () => Env.validarBaseUrl('https://api.medicare.do/api'),
        returnsNormally,
      );
    });

    test('rechaza vacio: es el caso real de olvidar el --dart-define', () {
      expect(
        () => Env.validarBaseUrl(''),
        throwsA(
          isA<ConfiguracionInvalida>().having(
            (ConfiguracionInvalida e) => e.variable,
            'variable',
            'API_BASE_URL',
          ),
        ),
      );
    });

    test(
      'rechaza una URL relativa: sin esquema no se puede armar la peticion',
      () {
        expect(
          () => Env.validarBaseUrl('10.0.2.2:3000/api'),
          throwsA(isA<ConfiguracionInvalida>()),
        );
      },
    );

    test('rechaza un esquema que no sea http/https', () {
      expect(
        () => Env.validarBaseUrl('ftp://host/api'),
        throwsA(isA<ConfiguracionInvalida>()),
      );
    });

    test('el mensaje de error dice que variable falta', () {
      try {
        Env.validarBaseUrl('');
        fail('tenia que lanzar');
      } on ConfiguracionInvalida catch (e) {
        expect(e.toString(), contains('API_BASE_URL'));
        expect(e.toString(), contains('--dart-define'));
      }
    });
  });
}
