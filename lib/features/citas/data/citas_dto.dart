import 'package:freezed_annotation/freezed_annotation.dart';

part 'citas_dto.freezed.dart';
part 'citas_dto.g.dart';

/// `AppointmentResponseDto` — RF-24.
///
/// **Ids planos, sin objetos anidados.** No trae el nombre del médico ni la
/// especialidad: eso se resuelve aparte con `MedicoDirectorio`.
@freezed
abstract class CitaDto with _$CitaDto {
  const factory CitaDto({
    required int idCita,
    required int idPaciente,
    required int idMedico,
    required String fechaHoraInicio,
    required String fechaHoraFin,
    required String modalidad,
    required String estado,
    required String fechaCreacion,
    int? idCentro,
    int? idDisponibilidad,
    String? motivoConsulta,
  }) = _CitaDto;

  factory CitaDto.fromJson(Map<String, dynamic> json) =>
      _$CitaDtoFromJson(json);
}

/// `POST /api/appointments` — RF-19, RF-21.
@freezed
abstract class CrearCitaDto with _$CrearCitaDto {
  const factory CrearCitaDto({
    required int idMedico,
    required String fecha,
    required String horaInicio,
    required String modalidad,
    String? motivoConsulta,
  }) = _CrearCitaDto;

  factory CrearCitaDto.fromJson(Map<String, dynamic> json) =>
      _$CrearCitaDtoFromJson(json);
}

/// `PATCH /api/appointments/{id}/cancelar` — RF-22.
///
/// El motivo es **obligatorio** del lado servidor.
@freezed
abstract class CancelarCitaDto with _$CancelarCitaDto {
  const factory CancelarCitaDto({required String motivo}) = _CancelarCitaDto;

  factory CancelarCitaDto.fromJson(Map<String, dynamic> json) =>
      _$CancelarCitaDtoFromJson(json);
}

/// `GET /api/appointments/me` y `/agenda` — paginado plano.
@freezed
abstract class PaginaCitasDto with _$PaginaCitasDto {
  const factory PaginaCitasDto({
    required List<CitaDto> data,
    required int total,
    required int page,
    required int limit,
  }) = _PaginaCitasDto;

  factory PaginaCitasDto.fromJson(Map<String, dynamic> json) =>
      _$PaginaCitasDtoFromJson(json);
}
