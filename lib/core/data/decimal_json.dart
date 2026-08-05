/// Lectura de los campos `Decimal` del backend.
///
/// **El contrato es asimétrico a propósito y hay que respetarlo:**
///
/// | | Tipo |
/// | - | - |
/// | `CreateDoctorDto.tarifaConsulta` (lo que se envía) | `number` |
/// | `DoctorResponseDto.tarifaConsulta` (lo que vuelve) | `string \| null` |
///
/// `doctors.service.ts` hace `dto.tarifaConsulta?.toString()` antes de
/// guardar, porque la columna es `Decimal` y un `double` de JavaScript no
/// puede representar todos los valores decimales sin error de redondeo —
/// `0.1 + 0.2 != 0.3`. Para un precio eso no es aceptable, así que viaja como
/// texto. Es la decisión correcta del backend, no un descuido.
///
/// El error que esto causó: el DTO del front declaraba `num?` en la
/// **respuesta**, y `json['tarifaConsulta'] as num?` explota con
/// `'String' is not a subtype of 'num?'`. No se veía porque ningún médico
/// tenía tarifa: `null as num?` pasa sin ruido. El primer médico que guardó
/// una tumbó la app.
///
/// Por eso la conversión va solo en la respuesta. Los DTO de envío mantienen
/// `num?`: el backend espera un número ahí y mandarle una cadena sería el
/// mismo error al revés.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

/// Se aplica al campo: `@DecimalJson() double? tarifaConsulta`.
///
/// Es un [JsonConverter] y no un `@JsonKey(fromJson: ...)` porque `JsonKey`
/// declara `@Target({field, getter})` y un parámetro de constructor de
/// `freezed` no es ninguno de los dos: el analizador lo marca con
/// `invalid_annotation_target`. La salida habitual es apagar esa regla en
/// `analysis_options.yaml`, y bajar la barra del linter para acomodar una
/// anotación no es un intercambio que valga la pena (R5). Un converter propio
/// no tiene esa restricción de destino.
class DecimalJson implements JsonConverter<double?, Object?> {
  const DecimalJson();

  @override
  double? fromJson(Object? json) => decimalDesdeJson(json);

  /// De vuelta como número: el backend espera `number` en los DTO de envío.
  /// Este converter no se usa en esa dirección hoy —`MedicoDto` solo se lee—
  /// pero devolver la cadena aquí sembraría el error simétrico si alguien lo
  /// reusara en un DTO de escritura.
  @override
  Object? toJson(double? object) => object;
}

/// Convierte a `double?` lo que el backend mande en un campo `Decimal`.
///
/// Acepta las dos formas —cadena y número— en vez de solo la que el backend
/// usa hoy. Un `Decimal` viaja como cadena, pero un `Float` de la misma tabla
/// viajaría como número, y distinguirlos desde el front es adivinar.
///
/// Una cadena que no es un número **lanza**. Devolver `null` ahí diría "este
/// médico no tiene tarifa", que es una respuesta distinta y equivocada: la
/// pantalla mostraría "Sin tarifa" sobre un dato que sí existe y llegó roto.
/// El repositorio convierte el fallo en un `Failure` visible.
double? decimalDesdeJson(Object? valor) => switch (valor) {
  null => null,
  final num n => n.toDouble(),
  final String s =>
    double.tryParse(s) ??
        (throw FormatException('Decimal ilegible del backend', s)),
  _ => throw FormatException(
    'Decimal con tipo inesperado: ${valor.runtimeType}',
    '$valor',
  ),
};
