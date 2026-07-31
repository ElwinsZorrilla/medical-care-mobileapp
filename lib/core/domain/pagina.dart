/// Una página de resultados — RF-15, RNF-07.
///
/// El backend responde `{ data, total, page, limit }` **plano**, sin `meta` y
/// **sin `lastPage`** (verificado en F00). Saber si quedan más páginas es
/// cuenta del cliente, y hacerla mal produce uno de dos bugs: un scroll
/// infinito que nunca para de pedir, o una lista que se corta antes de
/// mostrar todo.
class Pagina<T> {
  const Pagina({
    required this.items,
    required this.total,
    required this.pagina,
    required this.limite,
  });

  const Pagina.vacia({this.limite = limiteDefecto})
    : items = const [],
      total = 0,
      pagina = 1;

  /// Valores del `PaginationQueryDto` del backend.
  static const int limiteDefecto = 10;
  static const int limiteMaximo = 50;

  final List<T> items;

  /// Total de elementos en el servidor, no en esta página.
  final int total;

  /// 1-indexada, como la espera el backend.
  final int pagina;
  final int limite;

  /// Cuántas páginas hay en total.
  int get totalPaginas => total == 0 ? 1 : (total / limite).ceil();

  /// Si vale la pena pedir la siguiente.
  ///
  /// Se compara contra [totalPaginas] y no contra "la última página vino
  /// llena": una página exactamente llena que además es la última haría que
  /// el scroll pidiera una más, recibiera vacío, y volviera a intentar.
  bool get hayMas => pagina < totalPaginas;

  int get siguientePagina => pagina + 1;

  bool get estaVacia => items.isEmpty;

  /// Concatena la página siguiente a lo ya cargado.
  ///
  /// Se conservan los items viejos: el scroll infinito acumula, no reemplaza.
  Pagina<T> concatenar(Pagina<T> siguiente) => Pagina<T>(
    items: [...items, ...siguiente.items],
    total: siguiente.total,
    pagina: siguiente.pagina,
    limite: siguiente.limite,
  );

  Pagina<R> map<R>(R Function(T item) transformar) => Pagina<R>(
    items: items.map(transformar).toList(),
    total: total,
    pagina: pagina,
    limite: limite,
  );

  /// Limita el tamaño al máximo que acepta el backend.
  ///
  /// Pedir `limit=999` devuelve 400: el DTO tiene `@Max(50)`. Recortar acá
  /// evita que un llamador distraído rompa el listado en producción.
  static int limiteValido(int limite) =>
      limite < 1 ? 1 : (limite > limiteMaximo ? limiteMaximo : limite);
}
