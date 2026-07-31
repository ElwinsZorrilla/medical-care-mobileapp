import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/modalidad.dart';
import '../../../../core/network/result.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/agenda_api.dart';
import '../../data/agenda_repository.dart';
import '../../domain/disponibilidad.dart';

part 'agenda_provider.g.dart';

@Riverpod(keepAlive: true)
AgendaRepository agendaRepository(Ref ref) =>
    AgendaRepository(AgendaApi(ref.watch(dioClienteProvider)));

/// Franjas del médico autenticado — RF-16, RF-17.
@riverpod
class MisFranjas extends _$MisFranjas {
  @override
  Future<List<Disponibilidad>> build() async {
    final r = await ref.watch(agendaRepositoryProvider).misFranjas();
    return switch (r) {
      Ok(:final valor) => valor,
      Fallo(:final failure) => throw failure,
    };
  }

  /// Devuelve el fallo si lo hubo, para que la pantalla lo muestre sin
  /// perder la lista que ya tenía.
  Future<Object?> crear({
    required DiaSemana dia,
    required HoraDelDia horaInicio,
    required HoraDelDia horaFin,
    required int duracionSlotMin,
    required ModalidadFranja modalidad,
  }) async {
    final r = await ref
        .read(agendaRepositoryProvider)
        .crear(
          dia: dia,
          horaInicio: horaInicio,
          horaFin: horaFin,
          duracionSlotMin: duracionSlotMin,
          modalidad: modalidad,
        );
    if (r.esOk) ref.invalidateSelf();
    return r.failureONull;
  }

  /// RF-17 — desactivar.
  Future<Object?> desactivar(int id) async {
    final r = await ref.read(agendaRepositoryProvider).desactivar(id);
    if (r.esOk) ref.invalidateSelf();
    return r.failureONull;
  }

  /// Franjas activas del día pedido, ordenadas.
  ///
  /// Se calcula sobre lo ya cargado en vez de pedir al servidor: la lista
  /// completa son unas pocas filas y filtrar en memoria evita un viaje.
  List<Disponibilidad> delDia(DiaSemana dia) {
    final todas = state.value ?? const <Disponibilidad>[];
    return todas.where((f) => f.dia == dia && f.activo).toList()
      ..sort((a, b) => a.horaInicio.compareTo(b.horaInicio));
  }
}

/// Día seleccionado en la grilla de turnos.
