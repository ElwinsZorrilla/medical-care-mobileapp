import 'package:freezed_annotation/freezed_annotation.dart';

part 'video_dto.freezed.dart';
part 'video_dto.g.dart';

/// `VideollamadaResponseDto` — RF-35, RF-36, RF-37.
///
/// Las fechas viajan como `String`: declararlas `DateTime` hace que
/// `json_serializable` emita `DateTime.parse(...)` **sin** `.toUtc()`, y un
/// instante sin sufijo `Z` quedaria en hora del dispositivo (RNF-18).
@freezed
abstract class VideollamadaDto with _$VideollamadaDto {
  const factory VideollamadaDto({
    required int idVideollamada,
    required int idCita,
    required String proveedor,
    required String urlSala,
    required String estado,
    String? horaInicioReal,
    String? horaFinReal,
  }) = _VideollamadaDto;

  factory VideollamadaDto.fromJson(Map<String, dynamic> json) =>
      _$VideollamadaDtoFromJson(json);
}
