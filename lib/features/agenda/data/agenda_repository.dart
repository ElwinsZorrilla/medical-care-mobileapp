import 'package:dio/dio.dart';

import '../../../core/domain/modalidad.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/failure_mapper.dart';
import '../../../core/network/result.dart';
import '../../../core/time/app_time.dart';
import '../domain/disponibilidad.dart';
import 'agenda_api.dart';
import 'agenda_dto.dart';

/// Traduce DTO ↔ entidad y `DioException` → [Failure].
class AgendaRepository {
  const AgendaRepository(this._api);

  final AgendaApi _api;

  /// RF-16 — franjas del médico autenticado.
  Future<Result<List<Disponibilidad>>> misFranjas() =>
      _envolver(() async => (await _api.misFranjas()).map(_aFranja).toList());

  /// RF-16 — crear franja.
  Future<Result<Disponibilidad>> crear({
    required DiaSemana dia,
    required HoraDelDia horaInicio,
    required HoraDelDia horaFin,
    required int duracionSlotMin,
    required ModalidadFranja modalidad,
    int? idCentro,
  }) => _envolver(
    () async => _aFranja(
      await _api.crear(
        CrearDisponibilidadDto(
          diaSemana: dia.apiValue,
          horaInicio: horaInicio.toApi(),
          horaFin: horaFin.toApi(),
          duracionSlotMin: duracionSlotMin,
          modalidad: modalidad.apiValue,
          idCentro: idCentro,
        ),
      ),
    ),
    // El backend usa 409 tanto para el solape como para `horaFin <=
    // horaInicio`. El mensaje del servidor distingue; se conserva.
    mensaje409: 'Esa franja choca con otra que ya tienes ese día.',
  );

  Future<Result<Disponibilidad>> actualizar({
    required int id,
    DiaSemana? dia,
    HoraDelDia? horaInicio,
    HoraDelDia? horaFin,
    int? duracionSlotMin,
    ModalidadFranja? modalidad,
  }) => _envolver(
    () async => _aFranja(
      await _api.actualizar(
        id,
        ActualizarDisponibilidadDto(
          diaSemana: dia?.apiValue,
          horaInicio: horaInicio?.toApi(),
          horaFin: horaFin?.toApi(),
          duracionSlotMin: duracionSlotMin,
          modalidad: modalidad?.apiValue,
        ),
      ),
    ),
    mensaje409: 'Ese cambio hace que la franja choque con otra.',
    mensaje403: 'Solo puedes editar tus propias franjas.',
  );

  /// RF-17 — desactivar.
  Future<Result<Disponibilidad>> desactivar(int id) => _envolver(
    () async => _aFranja(await _api.desactivar(id)),
    mensaje403: 'Solo puedes desactivar tus propias franjas.',
  );

  /// RF-18 — turnos libres de un médico en una fecha.
  ///
  /// Recibe un instante y **resuelve la fecha en calendario dominicano**. Es
  /// el punto donde el bug de zona horaria haría más daño: a las 21:00 del
  /// lunes en RD ya es martes en UTC, así que mandar la fecha UTC mostraría
  /// los turnos del día equivocado.
  Future<Result<List<Turno>>> turnos({
    required int idMedico,
    required DateTime diaUtc,
  }) => _envolver(
    () async => (await _api.turnos(
      idMedico: idMedico,
      fecha: AppTime.fechaApi(diaUtc),
    )).map(_aTurno).toList(),
  );

  // ── Traducción ──────────────────────────────────────────────────────────

  Disponibilidad _aFranja(DisponibilidadDto dto) => Disponibilidad(
    id: dto.idDisponibilidad,
    idMedico: dto.idMedico,
    dia: DiaSemana.fromApi(dto.diaSemana),
    horaInicio: HoraDelDia.parse(dto.horaInicio) ?? const HoraDelDia(0, 0),
    horaFin: HoraDelDia.parse(dto.horaFin) ?? const HoraDelDia(0, 0),
    duracionSlotMin: dto.duracionSlotMin,
    modalidad: ModalidadFranja.fromApi(dto.modalidad),
    activo: dto.activo,
    idCentro: dto.idCentro,
  );

  Turno _aTurno(TurnoDto dto) => Turno(
    idDisponibilidad: dto.idDisponibilidad,
    // Acá sí son instantes UTC, a diferencia del `horaInicio` de la franja.
    inicioUtc: DateTime.parse(dto.horaInicio).toUtc(),
    finUtc: DateTime.parse(dto.horaFin).toUtc(),
    modalidad: ModalidadFranja.fromApi(dto.modalidad),
    // Se guarda el string crudo: al reservar hay que mandar este mismo.
    inicioApi: dto.horaInicio,
  );

  Future<Result<T>> _envolver<T>(
    Future<T> Function() peticion, {
    String? mensaje409,
    String? mensaje403,
  }) async {
    try {
      return Ok(await peticion());
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 409 && mensaje409 != null) {
        final servidor = _mensajeServidor(e);
        return Fallo(
          Conflicto(
            servidor.isEmpty ? mensaje409 : servidor,
            mensajeServidor: servidor,
          ),
        );
      }
      if (status == 403 && mensaje403 != null) {
        return Fallo(Prohibido(mensaje403));
      }
      return Fallo(FailureMapper.desdeDio(e));
    } on ArgumentError catch (e) {
      // Día, modalidad u hora con forma inesperada: falla ruidoso en vez de
      // pintar una agenda con turnos en el día equivocado.
      return Fallo(ErrorInesperado(e.message.toString()));
    } on FormatException {
      return const Fallo(
        ErrorInesperado('El servidor devolvió una fecha inválida.'),
      );
    }
  }

  String _mensajeServidor(DioException e) {
    final data = e.response?.data;
    if (data is! Map) return '';
    final mensaje = data['message'];
    return switch (mensaje) {
      final String s => s,
      final List<dynamic> l => l.join(' '),
      _ => '',
    };
  }
}
