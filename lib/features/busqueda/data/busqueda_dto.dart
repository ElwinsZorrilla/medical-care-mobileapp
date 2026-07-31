import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/data/medico_dto.dart';

part 'busqueda_dto.freezed.dart';
part 'busqueda_dto.g.dart';

/// `GET /api/specialties` — RF-12.
///
/// **Sin paginar.** El backend devuelve el arreglo completo; hay 10
/// especialidades sembradas y no crecen con el uso.
@freezed
abstract class CatalogoEspecialidadDto with _$CatalogoEspecialidadDto {
  const factory CatalogoEspecialidadDto({
    required int idEspecialidad,
    required String nombre,
    String? descripcion,
    String? urlIcono,
  }) = _CatalogoEspecialidadDto;

  factory CatalogoEspecialidadDto.fromJson(Map<String, dynamic> json) =>
      _$CatalogoEspecialidadDtoFromJson(json);
}

/// `GET /api/doctors?page=&limit=&especialidadId=` — RF-14, RF-15.
///
/// La forma es **plana**: `{ data, total, page, limit }`. No hay `meta` ni
/// `lastPage` — eso se calcula en el cliente (ver `Pagina`).
@freezed
abstract class PaginaMedicosDto with _$PaginaMedicosDto {
  const factory PaginaMedicosDto({
    required List<MedicoDto> data,
    required int total,
    required int page,
    required int limit,
  }) = _PaginaMedicosDto;

  factory PaginaMedicosDto.fromJson(Map<String, dynamic> json) =>
      _$PaginaMedicosDtoFromJson(json);
}
