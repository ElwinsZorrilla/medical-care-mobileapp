import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/medico.dart';
import '../../../../core/domain/pagina.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/infra_provider.dart';
import '../../../../core/network/result.dart';
import '../../data/admin_api.dart';
import '../../data/admin_repository.dart';

part 'admin_provider.g.dart';

@Riverpod(keepAlive: true)
AdminRepository adminRepository(Ref ref) =>
    AdminRepository(AdminApi(ref.watch(dioClienteProvider)));

/// Lo cargado, más el error de la **página siguiente** si lo hubo.
///
/// Mismo criterio que `ListadoState` en `busqueda/presentation/providers/
/// busqueda_provider.dart`: que falle la página 3 no debe borrar lo que el
/// admin ya está mirando.
class ColaVerificacionState {
  const ColaVerificacionState({required this.pagina, this.errorAlPaginar});

  final Pagina<PerfilMedico> pagina;
  final Failure? errorAlPaginar;

  ColaVerificacionState copiar({
    Pagina<PerfilMedico>? pagina,
    Failure? errorAlPaginar,
  }) => ColaVerificacionState(
    pagina: pagina ?? this.pagina,
    errorAlPaginar: errorAlPaginar,
  );
}

/// Cola de médicos pendientes de verificación — RF-11, lado admin.
@riverpod
class ColaVerificacion extends _$ColaVerificacion {
  bool _cargandoMas = false;

  @override
  Future<ColaVerificacionState> build() async {
    return ColaVerificacionState(pagina: await _pedir(pagina: 1));
  }

  /// Carga la página siguiente y la concatena.
  Future<void> cargarMas() async {
    final actual = state.value;
    if (actual == null || !actual.pagina.hayMas || _cargandoMas) return;

    _cargandoMas = true;
    try {
      final siguiente = await _pedir(pagina: actual.pagina.siguientePagina);
      state = AsyncData(
        ColaVerificacionState(pagina: actual.pagina.concatenar(siguiente)),
      );
    } on Failure catch (e) {
      state = AsyncData(actual.copiar(errorAlPaginar: e));
    } finally {
      _cargandoMas = false;
    }
  }

  /// Reintenta solo la página que falló.
  Future<void> reintentarPagina() async {
    final actual = state.value;
    if (actual?.errorAlPaginar == null) return;
    state = AsyncData(actual!.copiar());
    await cargarMas();
  }

  /// RF-11 — verifica el exequátur. Al recargar la página 1, el médico ya
  /// actuado deja de ser PENDIENTE y desaparece solo de la cola.
  Future<Result<PerfilMedico>> verificar(int idMedico) async {
    final resultado = await ref
        .read(adminRepositoryProvider)
        .verificar(idMedico);
    if (resultado.esOk) ref.invalidateSelf();
    return resultado;
  }

  /// RF-11 — rechaza el exequátur.
  Future<Result<PerfilMedico>> rechazar(int idMedico) async {
    final resultado = await ref
        .read(adminRepositoryProvider)
        .rechazar(idMedico);
    if (resultado.esOk) ref.invalidateSelf();
    return resultado;
  }

  Future<Pagina<PerfilMedico>> _pedir({required int pagina}) async {
    final resultado = await ref
        .read(adminRepositoryProvider)
        .pendientes(pagina: pagina);
    return switch (resultado) {
      Ok(:final valor) => valor,
      Fallo(:final failure) => throw failure,
    };
  }
}
