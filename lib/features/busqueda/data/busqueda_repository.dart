import 'package:dio/dio.dart';

import '../../../core/data/medico_dto.dart';
import '../../../core/domain/especialidad.dart';
import '../../../core/domain/medico.dart';
import '../../../core/domain/pagina.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/failure_mapper.dart';
import '../../../core/network/result.dart';
import 'busqueda_api.dart';
import 'busqueda_dto.dart';

/// Traduce DTO → entidad y `DioException` → [Failure].
class BusquedaRepository {
  const BusquedaRepository(this._api);

  final BusquedaApi _api;

  /// RF-12 — catálogo de especialidades.
  Future<Result<List<Especialidad>>> especialidades() async {
    try {
      final dtos = await _api.especialidades();
      return Ok(dtos.map(_aEspecialidad).toList());
    } on TypeError catch (e) {
      // Un campo con otro tipo del declarado. `Result<T>` promete que ningun
      // camino lanza; sin esto la promesa era falsa y la app se cerraba.
      return Fallo(ContratoRoto('$e'));
    } on FormatException catch (e) {
      // Fecha, numero o `Decimal` ilegible.
      return Fallo(ContratoRoto('$e'));
    } on DioException catch (e) {
      return Fallo(FailureMapper.desdeDio(e));
    }
  }

  /// RF-14, RF-15 — médicos, filtrables por especialidad y paginados.
  Future<Result<Pagina<PerfilMedico>>> medicos({
    int pagina = 1,
    int limite = Pagina.limiteDefecto,
    int? especialidadId,
  }) async {
    try {
      final dto = await _api.medicos(
        pagina: pagina,
        // El recorte vive aca y no en la API: es la superficie que usa la
        // app, y `limit=999` devuelve 400 por el @Max(50) del backend.
        limite: Pagina.limiteValido(limite),
        especialidadId: especialidadId,
      );
      return Ok(
        Pagina<PerfilMedico>(
          items: dto.data.map(_aMedico).toList(),
          total: dto.total,
          pagina: dto.page,
          limite: dto.limit,
        ),
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
      // Estado de verificación desconocido en algún médico de la lista.
      return Fallo(ErrorInesperado(e.message.toString()));
    }
  }

  Especialidad _aEspecialidad(CatalogoEspecialidadDto dto) => Especialidad(
    id: dto.idEspecialidad,
    nombre: dto.nombre,
    descripcion: dto.descripcion,
    urlIcono: dto.urlIcono,
  );

  PerfilMedico _aMedico(MedicoDto dto) => PerfilMedico(
    idMedico: dto.idMedico,
    idUsuario: dto.idUsuario,
    nombres: dto.nombres,
    apellidos: dto.apellidos,
    numExequatur: dto.numExequatur,
    estadoVerificacion: EstadoVerificacion.fromApi(dto.estadoVerificacion),
    especialidades: dto.especialidades
        .map(
          (e) => Especialidad(
            id: e.idEspecialidad,
            nombre: e.nombre,
            descripcion: e.descripcion,
            urlIcono: e.urlIcono,
          ),
        )
        .toList(),
    biografia: dto.biografia,
    aniosExperiencia: dto.aniosExperiencia,
    tarifaConsulta: dto.tarifaConsulta?.toDouble(),
  );
}
