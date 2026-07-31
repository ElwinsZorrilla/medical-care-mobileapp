import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicare/core/storage/secure_store.dart';
import 'package:mocktail/mocktail.dart';

class _AlmacenFalso extends Mock implements FlutterSecureStorage {}

/// Constantes con nombre: el hook de pre-commit marca un campo de token
/// seguido de una cadena literal como posible secreto en duro (RNF-04), y no
/// se debilita la regla por una prueba.
const _acceso = 'relleno-acceso';
const _refresco = 'relleno-refresco';

/// Dónde viven los tokens es un control de seguridad — RNF-03, rubro 3.1.
///
/// El refresh token de este backend dura **7 días y no se puede revocar**
/// (BACKEND_ISSUES.md #3). En `SharedPreferences` sería un XML en claro dentro
/// del sandbox: legible con root o con una copia de seguridad mal configurada.
void main() {
  late _AlmacenFalso almacen;
  late SecureStoreImpl store;

  setUp(() {
    almacen = _AlmacenFalso();
    store = SecureStoreImpl(storage: almacen);

    when(
      () => almacen.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {});
    when(() => almacen.delete(key: any(named: 'key'))).thenAnswer((_) async {});
    when(
      () => almacen.read(key: any(named: 'key')),
    ).thenAnswer((_) async => null);
  });

  // Las claves literales, no una forma. Afirmar solo "son dos y empiezan con
  // medicare." deja pasar que las dos escrituras usen la misma clave: el
  // refresh no se guardaría nunca y la prueba seguiría verde.
  const claveAccess = 'medicare.access_token';
  const claveRefresh = 'medicare.refresh_token';

  group('los tokens van al almacén cifrado', () {
    test('guardar escribe cada token en su clave', () async {
      await store.guardarTokens(accessToken: _acceso, refreshToken: _refresco);

      verify(() => almacen.write(key: claveAccess, value: _acceso)).called(1);
      verify(
        () => almacen.write(key: claveRefresh, value: _refresco),
      ).called(1);
    });

    test('leer va a esas mismas claves', () async {
      // Si `leer` y `guardar` usaran claves distintas, la sesión no
      // sobreviviría a cerrar la app y nadie lo notaría hasta producción.
      await store.leerAccessToken();
      verify(() => almacen.read(key: claveAccess)).called(1);

      await store.leerRefreshToken();
      verify(() => almacen.read(key: claveRefresh)).called(1);
    });

    test('limpiar borra los dos, no solo el access', () async {
      // Dejar el refresh vivo permite volver a sacar un access token: no
      // sería un cierre de sesión, sería esconder el botón.
      await store.limpiar();

      verify(() => almacen.delete(key: claveAccess)).called(1);
      verify(() => almacen.delete(key: claveRefresh)).called(1);
    });

    test('ida y vuelta: lo guardado es lo que se lee', () async {
      // Cubre de una vez cualquier desajuste entre las claves de escritura y
      // las de lectura, sin depender de los literales de arriba.
      final disco = <String, String>{};
      when(
        () => almacen.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((inv) async {
        disco[inv.namedArguments[#key] as String] =
            inv.namedArguments[#value] as String;
      });
      when(
        () => almacen.read(key: any(named: 'key')),
      ).thenAnswer((inv) async => disco[inv.namedArguments[#key]]);
      when(() => almacen.delete(key: any(named: 'key'))).thenAnswer((
        inv,
      ) async {
        disco.remove(inv.namedArguments[#key]);
      });

      await store.guardarTokens(accessToken: _acceso, refreshToken: _refresco);
      expect(await store.leerAccessToken(), _acceso);
      expect(await store.leerRefreshToken(), _refresco);

      await store.limpiar();
      expect(await store.leerAccessToken(), isNull);
      expect(await store.leerRefreshToken(), isNull);
    });
  });

  group('guarda de código — nunca SharedPreferences', () {
    test('el paquete no está ni declarado', () {
      // La regla está escrita en un comentario dentro de secure_store.dart, y
      // un comentario no detiene a nadie. Esto sí.
      final pubspec = File('pubspec.yaml').readAsLinesSync();
      final declarado = pubspec
          .where((l) => !l.trimLeft().startsWith('#'))
          .where((l) => l.contains('shared_preferences'));

      expect(
        declarado,
        isEmpty,
        reason: 'shared_preferences aparece en pubspec.yaml',
      );
    });

    test('nada en lib/ lo importa', () {
      final ofensores = <String>[];

      for (final f in Directory('lib').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        final lineas = f.readAsLinesSync();
        for (var i = 0; i < lineas.length; i++) {
          final l = lineas[i].trim();
          if (l.startsWith('//') || l.startsWith('///')) continue;
          if (l.contains('shared_preferences') ||
              l.contains('SharedPreferences')) {
            ofensores.add('${f.path}:${i + 1}');
          }
        }
      }

      expect(
        ofensores,
        isEmpty,
        reason: 'los tokens solo pueden vivir cifrados: $ofensores',
      );
    });
  });
}
