import 'package:dio/dio.dart';

import '../domain/modalidad.dart';
import '../domain/turno.dart';
import '../error/failure.dart';
import '../error/failure_mapper.dart';
import '../network/result.dart';
import '../time/app_time.dart';

/// Turnos libres de un médico en una fecha — RF-18.
///
/// `GET /availability/doctors/{idMedico}/slots?fecha=` es una ruta **pública**
/// que hoy consume `citas` para reservar, y que `agenda` va a consumir cuando
/// el médico pueda previsualizar los turnos que genera su configuración.
///
/// Vive en `core/` y no dentro de `citas` porque el concepto es de los dos
/// lados —uno los genera, el otro los toma— y un feature no importa de otro
/// (rubro 3.3). Es el mismo criterio por el que `MedicoDirectorio` está acá.
///
/// El DTO se parsea a mano y no con `freezed`. Son cuatro campos escalares de
/// un único endpoint que se mapean de inmediato a dominio: generar una clase
/// para eso agrega dos archivos al árbol de codegen sin que nadie vuelva a
/// tocar el intermedio.
class TurnosRepository {
  const TurnosRepository(this._dio);

  final Dio _dio;

  /// Recibe un instante y **resuelve la fecha en calendario dominicano**.
  ///
  /// Es el punto donde el bug de zona horaria haría más daño: a las 21:00 del
  /// lunes en RD ya es martes en UTC, así que mandar la fecha UTC mostraría
  /// los turnos del día equivocado (RNF-18).
  Future<Result<List<Turno>>> turnos({
    required int idMedico,
    required DateTime diaUtc,
  }) async {
    try {
      final res = await _dio.get<List<dynamic>>(
        '/availability/doctors/$idMedico/slots',
        queryParameters: {'fecha': AppTime.fechaApi(diaUtc)},
      );
      return Ok(
        (res.data ?? const [])
            .map((e) => _aTurno(e as Map<String, dynamic>))
            .toList(),
      );
    } on TypeError catch (e) {
      // Un campo con otro tipo del declarado. `Result<T>` promete que ningun
      // camino lanza; sin esto la promesa era falsa y la app se cerraba.
      return Fallo(ContratoRoto('$e'));
    } on FormatException catch (e) {
      // Fecha, numero o `Decimal` ilegible.
      return Fallo(ContratoRoto('$e'));
    } on DioException catch (e) {
      return Fallo(FailureMapper.desdeDio(e));
    } on ArgumentError catch (e) {
      // Modalidad desconocida en algún turno: falla ruidoso en vez de caer a
      // un valor por defecto que le mentiría al paciente sobre si la consulta
      // es presencial o virtual.
      return Fallo(ErrorInesperado(e.message.toString()));
    }
  }

  Turno _aTurno(Map<String, dynamic> json) {
    final inicio = json['horaInicio'] as String;
    return Turno(
      idDisponibilidad: json['idDisponibilidad'] as int,
      inicioUtc: DateTime.parse(inicio).toUtc(),
      finUtc: DateTime.parse(json['horaFin'] as String).toUtc(),
      modalidad: ModalidadFranja.fromApi(json['modalidad'] as String),
      // Se guarda el string crudo: al reservar se manda este, no uno
      // reconstruido desde `inicioUtc`.
      inicioApi: inicio,
    );
  }
}
