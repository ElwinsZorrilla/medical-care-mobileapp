import 'package:flutter_test/flutter_test.dart';
import 'package:medicare/core/domain/pagina.dart';

/// RF-15, RNF-07.
///
/// El backend no manda `lastPage`: saber si quedan más páginas es cuenta del
/// cliente. Hacerla mal produce uno de dos bugs — un scroll infinito que
/// nunca para de pedir, o una lista que se corta antes de mostrar todo.
void main() {
  Pagina<int> pagina({
    required int total,
    int nro = 1,
    int limite = 10,
    int? items,
  }) => Pagina<int>(
    items: List<int>.generate(items ?? limite, (i) => i),
    total: total,
    pagina: nro,
    limite: limite,
  );

  group('totalPaginas', () {
    test('división exacta', () {
      expect(pagina(total: 30).totalPaginas, 3);
    });

    test('redondea hacia arriba: 31 elementos son 4 páginas', () {
      expect(pagina(total: 31).totalPaginas, 4);
    });

    test('sin resultados sigue siendo una página', () {
      // Evita dividir por cero y que la lista vacía diga "página 1 de 0".
      expect(pagina(total: 0, items: 0).totalPaginas, 1);
    });

    test('un solo elemento', () {
      expect(pagina(total: 1, items: 1).totalPaginas, 1);
    });
  });

  group('hayMas — el bug del scroll infinito', () {
    test('en la primera de tres, sí', () {
      expect(pagina(total: 30, nro: 1).hayMas, isTrue);
    });

    test('en la última, no', () {
      expect(pagina(total: 30, nro: 3).hayMas, isFalse);
    });

    test('una última página exactamente llena NO pide otra', () {
      // Este es el caso que rompe la heurística ingenua de "vino llena,
      // entonces hay más": pediría la página 4, recibiría vacío, y volvería
      // a intentar en el siguiente scroll.
      final ultima = pagina(total: 30, nro: 3, limite: 10, items: 10);
      expect(ultima.items.length, ultima.limite);
      expect(ultima.hayMas, isFalse);
    });

    test('una página a medias tampoco pide más', () {
      expect(pagina(total: 25, nro: 3, items: 5).hayMas, isFalse);
    });

    test('sin resultados no hay siguiente', () {
      expect(pagina(total: 0, items: 0).hayMas, isFalse);
    });
  });

  group('concatenar', () {
    test('acumula en vez de reemplazar', () {
      const primera = Pagina<int>(
        items: [1, 2, 3],
        total: 6,
        pagina: 1,
        limite: 3,
      );
      const segunda = Pagina<int>(
        items: [4, 5, 6],
        total: 6,
        pagina: 2,
        limite: 3,
      );

      final union = primera.concatenar(segunda);
      expect(union.items, [1, 2, 3, 4, 5, 6]);
      expect(union.pagina, 2);
      expect(union.hayMas, isFalse);
    });

    test('el total se toma de la respuesta más reciente', () {
      // Si alguien creó un médico entre una página y otra, manda el dato
      // nuevo: usar el viejo dejaría el scroll creyendo que falta menos.
      const primera = Pagina<int>(items: [1], total: 2, pagina: 1, limite: 1);
      const segunda = Pagina<int>(items: [2], total: 5, pagina: 2, limite: 1);
      expect(primera.concatenar(segunda).total, 5);
    });
  });

  group('limiteValido', () {
    test('recorta al máximo del backend', () {
      // `limit=999` devuelve 400: el DTO tiene @Max(50).
      expect(Pagina.limiteValido(999), Pagina.limiteMaximo);
    });

    test('respeta los válidos', () {
      expect(Pagina.limiteValido(20), 20);
      expect(Pagina.limiteValido(Pagina.limiteMaximo), Pagina.limiteMaximo);
    });

    test('sube los que no tienen sentido', () {
      expect(Pagina.limiteValido(0), 1);
      expect(Pagina.limiteValido(-5), 1);
    });
  });

  group('map', () {
    test('transforma los items y conserva la paginación', () {
      final p = pagina(total: 30, nro: 2).map((i) => 'n$i');
      expect(p.items.first, 'n0');
      expect(p.pagina, 2);
      expect(p.total, 30);
      expect(p.hayMas, isTrue);
    });
  });

  group('vacia', () {
    test('es un estado consistente', () {
      const p = Pagina<int>.vacia();
      expect(p.estaVacia, isTrue);
      expect(p.hayMas, isFalse);
      expect(p.total, 0);
      expect(p.pagina, 1);
    });
  });
}
