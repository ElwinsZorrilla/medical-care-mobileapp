import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_dto.freezed.dart';
part 'chat_dto.g.dart';

/// `ConversacionResponseDto` — RF-31.
///
/// Las fechas viajan como `String`: declararlas `DateTime` hace que
/// `json_serializable` emita `DateTime.parse(...)` **sin** `.toUtc()`, y un
/// instante sin sufijo `Z` quedaria en hora del dispositivo (RNF-18).
@freezed
abstract class ConversacionDto with _$ConversacionDto {
  const factory ConversacionDto({
    required int idConversacion,
    required int idPaciente,
    required int idMedico,
    @Default(0) int noLeidos,
    String? estado,
    String? fechaUltimoMensaje,
  }) = _ConversacionDto;

  factory ConversacionDto.fromJson(Map<String, dynamic> json) =>
      _$ConversacionDtoFromJson(json);
}

/// `MensajeResponseDto` — RF-31, RF-33, RF-34.
@freezed
abstract class MensajeDto with _$MensajeDto {
  const factory MensajeDto({
    required int idMensaje,
    required int idConversacion,
    required int idUsuarioRemitente,
    required String contenido,
    required String fechaEnvio,
    @Default(false) bool leido,
    String? urlAdjunto,
  }) = _MensajeDto;

  factory MensajeDto.fromJson(Map<String, dynamic> json) =>
      _$MensajeDtoFromJson(json);
}
