import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/medico.dart';
import '../../../../core/domain/pagina.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/infra_provider.dart';
import '../../../../core/network/result.dart';
import '../../data/busqueda_api.dart';
import '../../data/busqueda_repository.dart';

part 'busqueda_provider.g.dart';

@Riverpod(keepAlive: true)
BusquedaRepository busquedaRepository(Ref ref) =>
    BusquedaRepository(BusquedaApi(ref.watch(dioClienteProvider)));

/// Especialidad seleccionada en el filtro — RF-14.
///
/// `null` significa "todas". No hay búsqueda por texto porque el backend no
/// la ofrece (BACKEND_ISSUES.md #8).
@riverpod
class FiltroEspecialidad extends _$FiltroEspecialidad {
  @override
  int? build() => null;

  void seleccionar(int? idEspecialidad) => state = idEspecialidad;
}

/// Lo cargado, más el error de la **página siguiente** si lo hubo.
///
/// Son dos cosas distintas y por eso van separadas: que falle la página 3 no
/// debe borrar las páginas 1 y 2 que el usuario está mirando. Un
/// `AsyncError` global haría exactamente eso — cambiaría la pantalla entera
/// por un mensaje de error y perdería el scroll.
class ListadoState {
  const ListadoState({required this.pagina, this.errorAlPaginar});

  final Pagina<PerfilMedico> pagina;

  /// Solo se llena cuando falla el cargado incremental. La lista sigue ahí.
  final Failure? errorAlPaginar;

  ListadoState copiar({
    Pagina<PerfilMedico>? pagina,
    Failure? errorAlPaginar,
  }) => ListadoState(
    pagina: pagina ?? this.pagina,
    errorAlPaginar: errorAlPaginar,
  );
}

/// Listado de médicos con scroll infinito — RF-15, RNF-07.
@riverpod
class ListadoMedicos extends _$ListadoMedicos {
  bool _cargandoMas = false;

  @override
  Future<ListadoState> build() async {
    // Al cambiar el filtro, Riverpod reconstruye y la lista arranca de cero.
    final especialidadId = ref.watch(filtroEspecialidadProvider);
    return ListadoState(
      pagina: await _pedir(pagina: 1, especialidadId: especialidadId),
    );
  }

  /// Carga la página siguiente y la concatena.
  ///
  /// Idempotente mientras hay una carga en curso: el scroll dispara el
  /// callback varias veces cerca del final y, sin el candado, se pediría tres
  /// veces la misma página.
  Future<void> cargarMas() async {
    final actual = state.value;
    if (actual == null || !actual.pagina.hayMas || _cargandoMas) return;

    _cargandoMas = true;
    try {
      final siguiente = await _pedir(
        pagina: actual.pagina.siguientePagina,
        especialidadId: ref.read(filtroEspecialidadProvider),
      );
      state = AsyncData(
        ListadoState(pagina: actual.pagina.concatenar(siguiente)),
      );
    } on Failure catch (e) {
      // Se conserva la lista y se anota el error: el usuario no pierde lo
      // que estaba viendo y puede reintentar desde el pie de la lista.
      state = AsyncData(actual.copiar(errorAlPaginar: e));
    } finally {
      _cargandoMas = false;
    }
  }

  /// Reintenta solo la página que falló, sin recargar todo.
  Future<void> reintentarPagina() async {
    final actual = state.value;
    if (actual?.errorAlPaginar == null) return;
    state = AsyncData(actual!.copiar());
    await cargarMas();
  }

  Future<Pagina<PerfilMedico>> _pedir({
    required int pagina,
    int? especialidadId,
  }) async {
    final resultado = await ref
        .read(busquedaRepositoryProvider)
        .medicos(pagina: pagina, especialidadId: especialidadId);
    return switch (resultado) {
      Ok(:final valor) => valor,
      Fallo(:final failure) => throw failure,
    };
  }
}
