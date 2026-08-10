import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/data/medico_dto.dart';

part 'admin_dto.freezed.dart';
part 'admin_dto.g.dart';

/// `GET /api/doctors?estadoVerificacion=&page=&limit=` — cola de admin.
///
/// Misma forma plana que `busqueda/data/busqueda_dto.dart#PaginaMedicosDto`:
/// `{ data, total, page, limit }`, sin `meta` ni `lastPage`. Se duplica a
/// propósito en vez de importar de `busqueda` — un feature no importa de
/// otro (ARCHITECTURE.md, rubro 3.3).
@freezed
abstract class PaginaMedicosAdminDto with _$PaginaMedicosAdminDto {
  const factory PaginaMedicosAdminDto({
    required List<MedicoDto> data,
    required int total,
    required int page,
    required int limit,
  }) = _PaginaMedicosAdminDto;

  factory PaginaMedicosAdminDto.fromJson(Map<String, dynamic> json) =>
      _$PaginaMedicosAdminDtoFromJson(json);
}
