import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Las cifras que el README afirma tienen que salir de la matriz.
///
/// Esta guarda existe porque el defecto ya ocurrio: el README decia "35
/// completos, 2 parciales" cuando la matriz tenia 32 y 5. Nadie volvio a
/// contar las filas — se sumo de cabeza el cambio de la ultima fase y se
/// olvidaron tres parciales que venian de antes.
///
/// Es la misma leccion que RNF-05, RNF-11 y RNF-17, aplicada a un numero en
/// vez de a una regla: **una afirmacion que nadie vuelve a derivar deja de ser
/// cierta en silencio.**
void main() {
  /// Se leen dentro de `main` y no como `final` de nivel superior.
  ///
  /// Si el archivo falta, un `final` de nivel superior revienta al **cargar**
  /// la biblioteca y el reporte dice `loading documentacion_test.dart` sin
  /// nombrar la causa. Paso: `.dockerignore` excluye `*.md` y la prueba fallo
  /// dentro del contenedor con ese mensaje. Asi el fallo cae en un test con
  /// nombre y con la ruta que no aparecio.
  late final String matriz;
  late final String readme;

  setUpAll(() {
    matriz = File('docs/TRACEABILITY.md').readAsStringSync();
    readme = File('README.md').readAsStringSync();
  });

  /// Cuenta las filas de la matriz por estado.
  ///
  /// Un requerimiento se cuenta por el **primer** simbolo que aparece en su
  /// fila: el estado va al final, pero el texto puede mencionar otros al
  /// referirse a issues del backend.
  ({Map<String, int> conteo, List<String> ids}) contar(String prefijo) {
    final fila = RegExp('^\\| ($prefijo-\\d+) \\|', multiLine: true);
    final conteo = <String, int>{'✅': 0, '⚠️': 0, '⬜': 0, '⛔': 0};
    final ids = <String>[];

    for (final linea in matriz.split('\n')) {
      final m = fila.firstMatch(linea);
      if (m == null) continue;
      ids.add(m.group(1)!);

      final visto =
          conteo.keys
              .map((s) => (simbolo: s, donde: linea.indexOf(s)))
              .where((e) => e.donde >= 0)
              .toList()
            ..sort((a, b) => a.donde.compareTo(b.donde));
      expect(
        visto,
        isNotEmpty,
        reason: '${m.group(1)} no tiene simbolo de estado',
      );
      conteo[visto.first.simbolo] = conteo[visto.first.simbolo]! + 1;
    }
    return (conteo: conteo, ids: ids);
  }

  group('la matriz esta completa', () {
    test('los 37 RF tienen una fila y una sola', () {
      final ids = contar('RF').ids;

      expect(ids, hasLength(37));
      expect(ids.toSet(), hasLength(37), reason: 'hay un RF repetido');
      for (var i = 1; i <= 37; i++) {
        final id = 'RF-${i.toString().padLeft(2, '0')}';
        expect(ids, contains(id), reason: '$id no esta en la matriz');
      }
    });

    test('los 19 RNF tienen una fila y una sola', () {
      final ids = contar('RNF').ids;

      expect(ids, hasLength(19));
      expect(ids.toSet(), hasLength(19), reason: 'hay un RNF repetido');
      for (var i = 1; i <= 19; i++) {
        final id = 'RNF-${i.toString().padLeft(2, '0')}';
        expect(ids, contains(id), reason: '$id no esta en la matriz');
      }
    });

    test('no queda ningun RF marcado sin backend', () {
      // Los 10 de F00 se cerraron en F16. Si alguno volviera a ⛔ seria una
      // regresion del contrato, no una decision de documentacion.
      expect(contar('RF').conteo['⛔'], 0);
    });
  });

  group('el README no puede inventarse las cifras', () {
    /// Extrae los dos numeros de "N completos y M parciales".
    (int, int) delReadme(String frase) {
      final m = RegExp(
        '$frase.*?(\\d+) completos y (\\d+) parciales',
        dotAll: true,
      ).firstMatch(readme);
      expect(m, isNotNull, reason: 'no se encontro la frase: $frase');
      return (int.parse(m!.group(1)!), int.parse(m.group(2)!));
    }

    test('los RF completos y parciales coinciden con la matriz', () {
      final real = contar('RF').conteo;
      final (completos, parciales) = delReadme(
        r'\*\*37 requerimientos funcionales\*\*',
      );

      expect(completos, real['✅'], reason: 'RF completos');
      expect(parciales, real['⚠️'], reason: 'RF parciales');
    });

    test('los RNF completos y parciales coinciden con la matriz', () {
      final real = contar('RNF').conteo;
      final m = RegExp(
        r'\*\*19 no funcionales\*\*: (\d+) completos, (\d+) parciales y '
        r'(\d+) que son',
        dotAll: true,
      ).firstMatch(readme);
      expect(m, isNotNull, reason: 'no se encontro el recuento de RNF');

      expect(int.parse(m!.group(1)!), real['✅'], reason: 'RNF completos');
      expect(int.parse(m.group(2)!), real['⚠️'], reason: 'RNF parciales');
      expect(int.parse(m.group(3)!), real['⬜'], reason: 'RNF del backend');
    });

    test('cada parcial que el README lista existe y es parcial', () {
      final matrizPorId = {
        for (final linea in matriz.split('\n'))
          if (RegExp(r'^\| (RF-\d+) \|').firstMatch(linea) case final m?)
            m.group(1)!: linea,
      };

      // La tabla de parciales del README: primera columna de cada fila.
      final listados = RegExp(
        r'^\| (RF-\d+) \| ',
        multiLine: true,
      ).allMatches(readme).map((m) => m.group(1)!).toSet();

      expect(listados, isNotEmpty, reason: 'el README no lista parciales');
      final realmenteParciales = matrizPorId.entries
          .where((e) => e.value.contains('⚠️'))
          .map((e) => e.key)
          .toSet();

      // Ni de mas —prometer un hueco que no existe— ni de menos, que es el
      // error que esta prueba nacio para atrapar.
      expect(listados, realmenteParciales);
    });
  });
}
