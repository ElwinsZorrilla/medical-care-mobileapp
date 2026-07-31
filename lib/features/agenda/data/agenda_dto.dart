import 'package:freezed_annotation/freezed_annotation.dart';

part 'agenda_dto.freezed.dart';
part 'agenda_dto.g.dart';

/// `GET /api/availability/me` y respuesta de crear/editar — RF-16, RF-17.
///
/// `horaInicio` y `horaFin` son strings `HH:mm` en **hora local de Santo
/// Domingo**, sin fecha ni zona.
@freezed
abstract class DisponibilidadDto with _$DisponibilidadDto {
  const factory DisponibilidadDto({
    required int idDisponibilidad,
    required int idMedico,
    required int diaSemana,
    required String horaInicio,
    required String horaFin,
    required int duracionSlotMin,
    required String modalidad,
    required bool activo,
    int? idCentro,
  }) = _DisponibilidadDto;

  factory DisponibilidadDto.fromJson(Map<String, dynamic> json) =>
      _$DisponibilidadDtoFromJson(json);
}

/// `POST /api/availability`
@freezed
abstract class CrearDisponibilidadDto with _$CrearDisponibilidadDto {
  const factory CrearDisponibilidadDto({
    required int diaSemana,
    required String horaInicio,
    required String horaFin,
    required int duracionSlotMin,
    required String modalidad,
    int? idCentro,
  }) = _CrearDisponibilidadDto;

  factory CrearDisponibilidadDto.fromJson(Map<String, dynamic> json) =>
      _$CrearDisponibilidadDtoFromJson(json);
}

/// `PATCH /api/availability/{id}` — todo opcional.
@freezed
abstract class ActualizarDisponibilidadDto with _$ActualizarDisponibilidadDto {
  const factory ActualizarDisponibilidadDto({
    int? diaSemana,
    String? horaInicio,
    String? horaFin,
    int? duracionSlotMin,
    String? modalidad,
    int? idCentro,
  }) = _ActualizarDisponibilidadDto;

  factory ActualizarDisponibilidadDto.fromJson(Map<String, dynamic> json) =>
      _$ActualizarDisponibilidadDtoFromJson(json);
}

/// `GET /api/availability/doctors/{idMedico}/slots?fecha=` — RF-18.
///
