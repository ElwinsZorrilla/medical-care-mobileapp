import 'package:dio/dio.dart';

import '../../../core/data/medico_dto.dart';
import '../../../core/domain/especialidad.dart';
import '../../../core/domain/medico.dart';
import '../../../core/domain/pagina.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/failure_mapper.dart';
import '../../../core/network/result.dart';
import 'admin_api.dart';

/// Traduce DTO → entidad y `DioException` → [Failure].
class AdminRepository {
  const AdminRepository(this._api);

  final AdminApi _api;

  /// Cola de médicos con exequátur pendiente de verificar.
  Future<Result<Pagina<PerfilMedico>>> pendientes({
    int pagina = 1,
    int limite = Pagina.limiteDefecto,
  }) async {
    try {
      final dto = await _api.pendientes(
        pagina: pagina,
        limite: Pagina.limiteValido(limite),
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
      return Fallo(ContratoRoto('$e'));
    } on FormatException catch (e) {
      return Fallo(ContratoRoto('$e'));
    } on DioException catch (e) {
      return Fallo(FailureMapper.desdeDio(e));
    } on ArgumentError catch (e) {
      return Fallo(ErrorInesperado(e.message.toString()));
    }
  }

  /// RF-11 — admin verifica el exequátur.
  Future<Result<PerfilMedico>> verificar(int idMedico) =>
      _actualizarVerificacion(idMedico, EstadoVerificacion.verificado);

  /// RF-11 — admin rechaza el exequátur.
  Future<Result<PerfilMedico>> rechazar(int idMedico) =>
      _actualizarVerificacion(idMedico, EstadoVerificacion.rechazado);

  Future<Result<PerfilMedico>> _actualizarVerificacion(
    int idMedico,
    EstadoVerificacion estado,
  ) async {
    try {
      final dto = await _api.actualizarVerificacion(
        idMedico: idMedico,
        estado: estado.apiValue,
      );
      return Ok(_aMedico(dto));
    } on TypeError catch (e) {
      return Fallo(ContratoRoto('$e'));
    } on FormatException catch (e) {
      return Fallo(ContratoRoto('$e'));
    } on DioException catch (e) {
      return Fallo(FailureMapper.desdeDio(e));
    } on ArgumentError catch (e) {
      return Fallo(ErrorInesperado(e.message.toString()));
    }
  }

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
