import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/especialidad.dart';
import '../error/failure.dart';
import '../error/failure_mapper.dart';
import '../network/infra_provider.dart';
import '../network/result.dart';
import 'medico_dto.dart';

part 'especialidades_catalogo.g.dart';

/// `GET /specialties` — el catálogo, sin paginar.
///
/// Vive en `core/` y no en `busqueda` porque lo consumen **dos** features:
/// `busqueda` lo usa de filtro (RF-12) y `perfil` para que el médico elija
/// las suyas (RF-11). Que `perfil` importara el provider de `busqueda`
/// cruzaría features, que `ARCHITECTURE.md` prohíbe con esas palabras y
/// `arquitectura_test.dart` pone en rojo.
///
/// Es el mismo movimiento que ya se hizo con `medico_directorio`,
/// `turnos_repository` y el dominio de notificaciones: cuando un segundo
/// feature necesita algo, sube a `core/` en vez de tenderse un puente.
class EspecialidadesApi {
  const EspecialidadesApi(this._dio);

  final Dio _dio;

  /// **Ruta pública**: no exige token.
  Future<List<EspecialidadDto>> catalogo() async {
    final res = await _dio.get<List<dynamic>>('/specialties');
    return (res.data ?? const [])
        .map((e) => EspecialidadDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

class EspecialidadesRepository {
  const EspecialidadesRepository(this._api);

  final EspecialidadesApi _api;

  Future<Result<List<Especialidad>>> catalogo() async {
    try {
      final dtos = await _api.catalogo();
      return Ok(
        dtos
            .map(
              (e) => Especialidad(
                id: e.idEspecialidad,
                nombre: e.nombre,
                descripcion: e.descripcion,
                urlIcono: e.urlIcono,
              ),
            )
            .toList(),
      );
    } on TypeError catch (e) {
      return Fallo(ContratoRoto('$e'));
    } on FormatException catch (e) {
      return Fallo(ContratoRoto('$e'));
    } on DioException catch (e) {
      return Fallo(FailureMapper.desdeDio(e));
    }
  }
}

@Riverpod(keepAlive: true)
EspecialidadesRepository especialidadesRepository(Ref ref) =>
    EspecialidadesRepository(EspecialidadesApi(ref.watch(dioClienteProvider)));

/// Catálogo de especialidades — RF-11, RF-12.
///
/// `keepAlive`: son unos pocos registros que no cambian durante la sesión.
/// Volver a pedirlos cada vez que se abre el filtro —o la edición de perfil—
/// es gastar datos móviles en algo que ya se tiene.
@Riverpod(keepAlive: true)
Future<List<Especialidad>> catalogoEspecialidades(Ref ref) async {
  final resultado = await ref
      .watch(especialidadesRepositoryProvider)
      .catalogo();
  return switch (resultado) {
    Ok(:final valor) => valor,
    Fallo(:final failure) => throw failure,
  };
}
