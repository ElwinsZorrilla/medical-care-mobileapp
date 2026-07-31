import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Las reglas de capas del rubro 3.3, ejecutables.
///
/// `docs/ARCHITECTURE.md` dice que la regla "feature A → feature B" está
/// "verificada en el gate". No lo estaba: seis revisiones la dieron por buena
/// mientras siete archivos la violaban. Una regla que solo vive en Markdown no
/// es una regla, es una intención — el mismo argumento por el que la
/// prohibición de `SharedPreferences` pasó de comentario a prueba.
///
/// Solo recorre `lib/`. Los tests **sí** pueden importar de varios features:
/// nada en `lib/` depende de `test/`, así que no crean acoplamiento, y un test
/// de contrato existe justamente para mirar varios módulos a la vez y
/// comprobar que hablan el mismo protocolo. Partir
/// `test/contrato_api_test.dart` en seis para cumplir la letra de la regla
/// eliminaría lo único que lo hace útil.
void main() {
  const features = {
    'agenda',
    'auth',
    'busqueda',
    'citas',
    'historial',
    'perfil',
  };

  /// Violaciones que ya existían cuando se escribió esta guarda.
  ///
  /// Todas son el mismo problema: `dioClienteProvider`, `secureStoreProvider`
  /// y `sesionActualProvider` viven en `features/auth/presentation/`, y los
  /// otros cinco features los necesitan para construir su repositorio.
  ///
  /// **No se arreglaron acá a propósito.** Mover los dos primeros a `core/` es
  /// mecánico, pero `dioCliente` llama a `sesionActual.expirar()` cuando el
  /// refresh falla, así que subirlo invierte la dependencia: `core` pasaría a
  /// depender de `auth`. Resolverlo bien pide decidir dónde vive la sesión y
  /// probablemente una interfaz en `core` que `auth` implemente. Es un
  /// rediseño con decisiones propias, no un movimiento de archivos, y meterlo
  /// en el commit de endurecimiento lo volvería irrevisable.
  ///
  /// El registro solo puede encoger: una entrada que ya no corresponde también
  /// falla, así que no se puede dejar podrido.
  const deudaConocida = {
    'lib/features/agenda/presentation/providers/agenda_provider.dart',
    'lib/features/busqueda/presentation/providers/busqueda_provider.dart',
    'lib/features/citas/presentation/providers/citas_provider.dart',
    'lib/features/historial/presentation/providers/historial_provider.dart',
    'lib/features/historial/presentation/screens/historial_screen.dart',
    'lib/features/perfil/presentation/providers/perfil_provider.dart',
    'lib/features/perfil/presentation/screens/perfil_screen.dart',
  };

  /// Archivos de `lib/`, con su ruta normalizada a barras.
  List<({String ruta, List<String> lineas})> fuentes() {
    final lib = Directory('lib');
    expect(
      lib.existsSync(),
      isTrue,
      reason:
          'corre desde la raíz del paquete; cwd = ${Directory.current.path}',
    );

    final archivos = <({String ruta, List<String> lineas})>[];
    for (final e in lib.listSync(recursive: true)) {
      if (e is! File || !e.path.endsWith('.dart')) continue;
      archivos.add((
        ruta: e.path.replaceAll(r'\', '/'),
        lineas: e.readAsLinesSync(),
      ));
    }
    expect(archivos.length, greaterThan(30), reason: 'no recorrió lib/');
    return archivos;
  }

  /// El feature al que pertenece una ruta, o `null` si es `core`.
  String? featureDe(String ruta) {
    final m = RegExp(r'^lib/features/([^/]+)/').firstMatch(ruta);
    return m?.group(1);
  }

  group('rubro 3.3 — sin dependencias entre features', () {
    test('ningún feature importa de otro', () {
      final ofensores = <String, Set<String>>{};

      for (final f in fuentes()) {
        final propio = featureDe(f.ruta);
        if (propio == null) continue;

        for (final linea in f.lineas) {
          if (!linea.trimLeft().startsWith('import ')) continue;
          // Relativo (`../../../auth/...`) o por paquete.
          for (final otro in features) {
            if (otro == propio) continue;
            final cruzado =
                RegExp('/$otro/').hasMatch(linea) ||
                linea.contains('package:medicare/features/$otro/');
            if (cruzado) {
              (ofensores[f.ruta] ??= {}).add(otro);
            }
          }
        }
      }

      final nuevos = ofensores.keys.toSet().difference(deudaConocida);
      expect(
        nuevos,
        isEmpty,
        reason:
            'Import entre features. Lo compartido sube a core/. Nuevos: '
            '${nuevos.map((r) => '$r → ${ofensores[r]}').join(', ')}',
      );

      // El registro tiene que encoger. Si una entrada ya no viola nada,
      // sacarla — si no, la próxima violación real se esconde detrás de ella.
      final resueltos = deudaConocida.difference(ofensores.keys.toSet());
      expect(
        resueltos,
        isEmpty,
        reason:
            'Ya no violan la regla; quitarlos de `deudaConocida`: $resueltos',
      );
    });
  });

  group('rubro 3.3 — la presentación no habla HTTP', () {
    test('ninguna pantalla ni widget importa dio', () {
      // Un `Response` o una `DioException` en un widget significa que la
      // traducción a `Failure` se saltó, y el usuario termina viendo un
      // mensaje de librería en inglés.
      final ofensores = <String>[];

      for (final f in fuentes()) {
        if (!f.ruta.contains('/presentation/screens/') &&
            !f.ruta.contains('/presentation/widgets/')) {
          continue;
        }
        for (var i = 0; i < f.lineas.length; i++) {
          if (f.lineas[i].contains('package:dio/')) {
            ofensores.add('${f.ruta}:${i + 1}');
          }
        }
      }

      expect(ofensores, isEmpty, reason: 'dio en presentación: $ofensores');
    });

    test('ningún widget nombra Response ni DioException', () {
      final ofensores = <String>[];

      for (final f in fuentes()) {
        if (!f.ruta.contains('/presentation/')) continue;
        for (var i = 0; i < f.lineas.length; i++) {
          final l = f.lineas[i];
          if (l.trimLeft().startsWith('//')) continue;
          if (RegExp(r'\bDioException\b|\bResponse<').hasMatch(l)) {
            ofensores.add('${f.ruta}:${i + 1}');
          }
        }
      }

      expect(
        ofensores,
        isEmpty,
        reason: 'la capa de datos traduce a Failure: $ofensores',
      );
    });
  });
}
