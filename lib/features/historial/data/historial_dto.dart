import 'package:freezed_annotation/freezed_annotation.dart';

part 'historial_dto.freezed.dart';
part 'historial_dto.g.dart';

/// `RecetaResponseDto` — RF-26.
@freezed
abstract class RecetaDto with _$RecetaDto {
  const factory RecetaDto({
    required int idReceta,
    required String medicamento,
    required String dosis,
    required String frecuencia,
    int? duracionDias,
    String? indicaciones,
  }) = _RecetaDto;

  factory RecetaDto.fromJson(Map<String, dynamic> json) =>
      _$RecetaDtoFromJson(json);
}

/// `ConsultationResponseDto` — RF-25, RF-27.
///
/// `signosVitales` viene como **objeto libre** (`jsonb` sin esquema del lado
/// servidor), así que se recibe como mapa crudo y lo interpreta el dominio.
@freezed
abstract class ConsultaDto with _$ConsultaDto {
  const factory ConsultaDto({
    required int idConsulta,
    required int idCita,
    required int idPaciente,
    required int idMedico,
    required String diagnostico,
    required String fechaRegistro,
    @Default(<RecetaDto>[]) List<RecetaDto> recetas,
    String? tratamiento,
    String? observaciones,
    Map<String, dynamic>? signosVitales,
  }) = _ConsultaDto;

  factory ConsultaDto.fromJson(Map<String, dynamic> json) =>
      _$ConsultaDtoFromJson(json);
}

/// `CreateRecetaDto`
@freezed
abstract class CrearRecetaDto with _$CrearRecetaDto {
  const factory CrearRecetaDto({
    required String medicamento,
    required String dosis,
    required String frecuencia,
    int? duracionDias,
    String? indicaciones,
  }) = _CrearRecetaDto;

  factory CrearRecetaDto.fromJson(Map<String, dynamic> json) =>
      _$CrearRecetaDtoFromJson(json);
}

/// `CreateConsultationDto` — RF-25.
///
/// Solo `idCita` y `diagnostico` son obligatorios. `recetas` va en la misma
/// llamada para que no exista una consulta sin su receta ni por un instante.
@freezed
abstract class CrearConsultaDto with _$CrearConsultaDto {
  const factory CrearConsultaDto({
    required int idCita,
    required String diagnostico,
    String? tratamiento,
    String? observaciones,
    Map<String, Object?>? signosVitales,
    List<CrearRecetaDto>? recetas,
  }) = _CrearConsultaDto;

  factory CrearConsultaDto.fromJson(Map<String, dynamic> json) =>
      _$CrearConsultaDtoFromJson(json);
}

/// `GET /consultations/me` y `/atendidas` — paginado plano.
@freezed
abstract class PaginaConsultasDto with _$PaginaConsultasDto {
  const factory PaginaConsultasDto({
    required List<ConsultaDto> data,
    required int total,
    required int page,
    required int limit,
  }) = _PaginaConsultasDto;

  factory PaginaConsultasDto.fromJson(Map<String, dynamic> json) =>
      _$PaginaConsultasDtoFromJson(json);
}
