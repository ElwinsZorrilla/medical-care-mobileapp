import 'package:freezed_annotation/freezed_annotation.dart';

import 'decimal_json.dart';

part 'medico_dto.freezed.dart';
part 'medico_dto.g.dart';

/// Especialidad, tal como viene del backend.
///
/// Está en `core/data/` por la misma razón que su entidad está en
/// `core/domain/`: la consumen `perfil`, `busqueda` y `citas`. Un DTO
/// duplicado en tres features es tres lugares donde olvidarse de actualizar
/// un campo cuando el backend cambie.
@freezed
abstract class EspecialidadDto with _$EspecialidadDto {
  const factory EspecialidadDto({
    required int idEspecialidad,
    required String nombre,
    String? descripcion,
    String? urlIcono,
  }) = _EspecialidadDto;

  factory EspecialidadDto.fromJson(Map<String, dynamic> json) =>
      _$EspecialidadDtoFromJson(json);
}

/// `GET /api/doctors/me`, `GET /api/doctors/{id}` y cada elemento de
/// `GET /api/doctors`.
@freezed
abstract class MedicoDto with _$MedicoDto {
  const factory MedicoDto({
    required int idMedico,
    required int idUsuario,
    required String nombres,
    required String apellidos,
    required String numExequatur,
    required String estadoVerificacion,
    @Default(<EspecialidadDto>[]) List<EspecialidadDto> especialidades,
    String? biografia,
    int? aniosExperiencia,
    // Llega como **cadena**, no como número: la columna es `Decimal` y el
    // backend la serializa con `.toString()`. Ver `decimal_json.dart`.
    @DecimalJson() double? tarifaConsulta,
  }) = _MedicoDto;

  factory MedicoDto.fromJson(Map<String, dynamic> json) =>
      _$MedicoDtoFromJson(json);
}
