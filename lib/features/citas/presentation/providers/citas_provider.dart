import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/data/medico_directorio.dart';
import '../../../../core/data/turnos_repository.dart';
import '../../../../core/domain/cita_estado.dart';
import '../../../../core/domain/medico.dart';
import '../../../../core/domain/pagina.dart';
import '../../../../core/domain/turno.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/infra_provider.dart';
import '../../../../core/network/result.dart';
import '../../../../core/time/app_time.dart';
import '../../data/citas_api.dart';
import '../../data/citas_repository.dart';
import '../../domain/cita.dart';

part 'citas_provider.g.dart';

@Riverpod(keepAlive: true)
CitasRepository citasRepository(Ref ref) =>
    CitasRepository(CitasApi(ref.watch(dioClienteProvider)));

/// Caché de médicos — resuelve el N+1 de los listados.
///
/// `keepAlive`: el valor de la caché está en que sobrevive a la navegación.
/// Si se reconstruyera al volver a la lista, cada visita pagaría de nuevo
/// las mismas peticiones.
@Riverpod(keepAlive: true)
MedicoDirectorio medicoDirectorio(Ref ref) =>
    MedicoDirectorio(ref.watch(dioClienteProvider));

/// Filtro de estado — **del lado cliente**.
///
/// `ListAppointmentsQueryDto` del backend solo acepta paginación: no hay
/// `estado`, `desde` ni `hasta` (F00). Se filtra sobre la página cargada, y
/// por eso la UI dice "de las cargadas" y no promete un filtro global.
@riverpod
class FiltroEstadoCita extends _$FiltroEstadoCita {
  @override
  CitaEstado? build() => null;

  void seleccionar(CitaEstado? estado) => state = estado;
}

/// Citas del paciente o agenda del médico — RF-24.
class CitasState {
  const CitasState({
    required this.pagina,
    this.medicos = const {},
    this.errorAlPaginar,
  });

  final Pagina<Cita> pagina;

  /// Nombres ya resueltos. Lo que falte se pinta sin nombre, no en blanco.
  final Map<int, PerfilMedico> medicos;

  final Object? errorAlPaginar;

  /// Aplica el filtro de estado sobre lo cargado.
  List<Cita> visibles(CitaEstado? filtro) => filtro == null
      ? pagina.items
      : pagina.items.where((c) => c.estado == filtro).toList();
}

/// Listado de citas del rol activo.
@riverpod
class ListadoCitas extends _$ListadoCitas {
  bool _cargandoMas = false;

  /// `true` para la agenda del médico, `false` para las citas del paciente.
  bool _esAgenda = false;

  @override
  Future<CitasState> build({bool agenda = false}) async {
    _esAgenda = agenda;
    final pagina = await _pedir(1);
    return CitasState(pagina: pagina, medicos: await _resolverMedicos(pagina));
  }

  Future<void> cargarMas() async {
    final actual = state.value;
    if (actual == null || !actual.pagina.hayMas || _cargandoMas) return;

    _cargandoMas = true;
    try {
      final siguiente = await _pedir(actual.pagina.siguientePagina);
      final unida = actual.pagina.concatenar(siguiente);
      state = AsyncData(
        CitasState(pagina: unida, medicos: await _resolverMedicos(unida)),
      );
    } on Object catch (e) {
      // No se pierde lo cargado: falló la página siguiente, no lo que el
      // usuario está leyendo.
      state = AsyncData(
        CitasState(
          pagina: actual.pagina,
          medicos: actual.medicos,
          errorAlPaginar: e,
        ),
      );
    } finally {
      _cargandoMas = false;
    }
  }

  /// RF-22 — cancelar con motivo.
  ///
  /// Devuelve el fallo si lo hubo, para que la pantalla lo muestre sin
  /// perder la lista.
  Future<Object?> cancelar({
    required int idCita,
    required String motivo,
  }) async {
    final r = await ref
        .read(citasRepositoryProvider)
        .cancelar(idCita: idCita, motivo: motivo);
    if (r.esOk) ref.invalidateSelf();
    return r.failureONull;
  }

  Future<Pagina<Cita>> _pedir(int pagina) async {
    final repo = ref.read(citasRepositoryProvider);
    final r = _esAgenda
        ? await repo.miAgenda(pagina: pagina)
        : await repo.misCitas(pagina: pagina);
    return switch (r) {
      Ok(:final valor) => valor,
      Fallo(:final failure) => throw failure,
    };
  }

  /// Resuelve los nombres de los médicos de la página, sin repetir ids.
  ///
  /// Diez citas de tres médicos distintos son **tres** peticiones. Sin esto
  /// serían diez, y la agenda con 50 citas serían 50.
  Future<Map<int, PerfilMedico>> _resolverMedicos(Pagina<Cita> pagina) async {
    // En la agenda del médico todas las citas son suyas: no hay nada que
    // resolver. Es el listado más largo y el que más se beneficia.
    if (_esAgenda) return const {};

    final directorio = ref.read(medicoDirectorioProvider);
    await directorio.precargar(pagina.items.map((c) => c.idMedico));

    return {
      for (final c in pagina.items) c.idMedico: ?directorio.enCache(c.idMedico),
    };
  }
}

// ── Reserva — RF-18, RF-19, RF-20, RF-21 ───────────────────────────────────
//
// Estos providers existian en el dominio y el repositorio desde F08 pero
// **ninguna pantalla los invocaba**: F15 lo descubrio auditando la matriz.
// `reservar` solo lo llamaban las pruebas, asi que RF-19 estaba marcado como
// cumplido sin que un paciente pudiera reservar nada.

@Riverpod(keepAlive: true)
TurnosRepository turnosRepository(Ref ref) =>
    TurnosRepository(ref.watch(dioClienteProvider));

/// Dia que el paciente esta mirando en la grilla de turnos.
///
/// Se guarda como instante UTC y se resuelve a fecha dominicana recien al
/// pedir, dentro de `TurnosRepository` (RNF-18).
@riverpod
class DiaReserva extends _$DiaReserva {
  @override
  DateTime build() => AppTime.ahoraUtc();

  void seleccionar(DateTime diaUtc) => state = diaUtc;

  void avanzar(int dias) => state = state.add(Duration(days: dias));
}

/// Turnos libres del medico en el dia seleccionado — RF-18.
@riverpod
Future<List<Turno>> turnosDeMedico(Ref ref, int idMedico) async {
  final r = await ref
      .watch(turnosRepositoryProvider)
      .turnos(idMedico: idMedico, diaUtc: ref.watch(diaReservaProvider));
  return switch (r) {
    Ok(:final valor) => valor,
    Fallo(:final failure) => throw failure,
  };
}

/// RF-19, RF-20, RF-21 — reservar.
@riverpod
class Reserva extends _$Reserva {
  @override
  void build() {}

  /// Devuelve el fallo si lo hubo, o `null` si salio bien.
  ///
  /// No lanza: el 409 de turno tomado (RF-20) es un resultado esperado del
  /// flujo, no una excepcion. Quien llama decide que hacer con
  /// `ReaccionAConflicto.para`.
  Future<Failure?> reservar(SolicitudReserva solicitud) async {
    final r = await ref.read(citasRepositoryProvider).reservar(solicitud);
    if (r.esOk) {
      // La cita nueva tiene que aparecer en "Mis citas" sin que el usuario
      // tenga que refrescar a mano.
      ref.invalidate(listadoCitasProvider);
    }
    return r.failureONull;
  }
}
