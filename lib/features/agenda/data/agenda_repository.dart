import 'package:dio/dio.dart';

import '../../../core/domain/modalidad.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/failure_mapper.dart';
import '../../../core/network/result.dart';
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

  // Los turnos (RF-18) se mudaron a core/data/turnos_repository.dart: los
  // consumen `agenda` y `citas`, y un feature no importa de otro.

  Future<Result<T>> _envolver<T>(
    Future<T> Function() peticion, {
    String? mensaje409,
    String? mensaje403,
  }) async {
    try {
      return Ok(await peticion());
    } on TypeError catch (e) {
      // Un campo con otro tipo del declarado. `Result<T>` promete que ningun
      // camino lanza; sin esto la promesa era falsa y la app se cerraba.
      return Fallo(ContratoRoto('$e'));
    } on FormatException catch (e) {
      // Fecha, numero o `Decimal` ilegible.
      return Fallo(ContratoRoto('$e'));
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
