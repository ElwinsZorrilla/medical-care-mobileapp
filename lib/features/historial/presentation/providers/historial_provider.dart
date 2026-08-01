import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/pagina.dart';
import '../../../../core/domain/tipo_usuario.dart';
import '../../../../core/network/infra_provider.dart';
import '../../../../core/network/result.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/historial_api.dart';
import '../../data/historial_repository.dart';
import '../../domain/consulta.dart';

part 'historial_provider.g.dart';

@Riverpod(keepAlive: true)
HistorialRepository historialRepository(Ref ref) =>
    HistorialRepository(HistorialApi(ref.watch(dioClienteProvider)));

/// Historial clínico del usuario autenticado — RF-27, RNF-06.
///
/// La ruta se elige por el rol de la sesión, no por un parámetro: así **no
/// existe una forma de pedir el historial de otro** ni siquiera por error de
/// programación. El backend además lo filtra por token, pero la UI no se
/// apoya solo en eso (rubro 3.1).
@riverpod
class Historial extends _$Historial {
  bool _cargandoMas = false;

  @override
  Future<Pagina<Consulta>> build() async {
    final sesion = ref.watch(sesionActualProvider);
    final tipo = sesion.usuario?.tipo;

    // Sin sesión resuelta no se pide nada: pedir el historial de nadie
    // devolvería 401 y pintaría un error donde solo falta esperar.
    if (tipo == null) return const Pagina<Consulta>.vacia();

    return _pedir(pagina: 1, tipo: tipo);
  }

  Future<void> cargarMas() async {
    final actual = state.value;
    final tipo = ref.read(sesionActualProvider).usuario?.tipo;
    if (actual == null || tipo == null || !actual.hayMas || _cargandoMas) {
      return;
    }

    _cargandoMas = true;
    try {
      final siguiente = await _pedir(
        pagina: actual.siguientePagina,
        tipo: tipo,
      );
      state = AsyncData(actual.concatenar(siguiente));
    } on Object {
      // Se conserva lo cargado: el historial que el paciente está leyendo no
      // desaparece porque falle la página siguiente.
      state = AsyncData(actual);
    } finally {
      _cargandoMas = false;
    }
  }

  Future<Pagina<Consulta>> _pedir({
    required int pagina,
    required TipoUsuario tipo,
  }) async {
    final repo = ref.read(historialRepositoryProvider);
    final r = tipo == TipoUsuario.medico
        ? await repo.atendidas(pagina: pagina)
        : await repo.miHistorial(pagina: pagina);
    return switch (r) {
      Ok(:final valor) => valor,
      Fallo(:final failure) => throw failure,
    };
  }
}

/// RF-25, RF-26 — registrar una consulta sobre una cita.
@riverpod
class RegistroConsulta extends _$RegistroConsulta {
  @override
  void build() {}

  /// Devuelve el fallo si lo hubo, o `null` si salió bien.
  Future<Object?> registrar(SolicitudConsulta solicitud) async {
    final r = await ref.read(historialRepositoryProvider).registrar(solicitud);

    if (r.esOk) {
      // La cita pasó a COMPLETADA como efecto del registro, así que los
      // listados que la muestran quedaron viejos.
      ref.invalidate(historialProvider);
    }
    return r.failureONull;
  }
}
