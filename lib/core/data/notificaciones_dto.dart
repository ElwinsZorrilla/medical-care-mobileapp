import 'package:freezed_annotation/freezed_annotation.dart';

part 'notificaciones_dto.freezed.dart';
part 'notificaciones_dto.g.dart';

/// `NotificacionResponseDto` — RF-28.
///
/// `fechaEnvio` viaja como `String` y no como `DateTime`: declararlo `DateTime`
/// hace que `json_serializable` emita `DateTime.parse(...)` **sin** `.toUtc()`,
/// y un instante sin sufijo `Z` quedaria en hora del dispositivo. La conversion
/// es del repositorio, via `AppTime` (RNF-18).
@freezed
abstract class NotificacionDto with _$NotificacionDto {
  const factory NotificacionDto({
    required int idNotificacion,
    required String tipo,
    required String titulo,
    required String cuerpo,
    required bool leida,
    required String fechaEnvio,
    int? idCita,
    String? canal,
  }) = _NotificacionDto;

  factory NotificacionDto.fromJson(Map<String, dynamic> json) =>
      _$NotificacionDtoFromJson(json);
}

@freezed
abstract class PaginaNotificacionesDto with _$PaginaNotificacionesDto {
  const factory PaginaNotificacionesDto({
    required List<NotificacionDto> data,
    required int total,
    required int page,
    required int limit,
  }) = _PaginaNotificacionesDto;

  factory PaginaNotificacionesDto.fromJson(Map<String, dynamic> json) =>
      _$PaginaNotificacionesDtoFromJson(json);
}
