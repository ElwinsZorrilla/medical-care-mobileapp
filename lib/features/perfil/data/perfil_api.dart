import 'package:dio/dio.dart';

import 'perfil_dto.dart';

/// Solo HTTP.
///
/// **Ninguna ruta recibe el id del usuario.** `/patients/me` y `/doctors/me`
/// lo sacan del JWT del lado servidor (RF-09). Si el front lo mandara, sería
/// un dato que el cliente puede elegir — que es exactamente lo que RF-09
/// prohíbe.
class PerfilApi {
  const PerfilApi(this._dio);

  final Dio _dio;

  // ── Paciente ────────────────────────────────────────────────────────────

  Future<PacienteDto> miPerfilPaciente() async {
    final res = await _dio.get<Map<String, dynamic>>('/patients/me');
    return PacienteDto.fromJson(res.data!);
  }

  Future<PacienteDto> crearPerfilPaciente(CrearPacienteDto body) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/patients',
      data: body.toJson(),
    );
    return PacienteDto.fromJson(res.data!);
  }

  Future<PacienteDto> actualizarPerfilPaciente(
    ActualizarPacienteDto body,
  ) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/patients/me',
      // Los nulos se descartan: un PATCH con `direccion: null` borraría el
      // dato en vez de dejarlo como está.
      data: _sinNulos(body.toJson()),
    );
    return PacienteDto.fromJson(res.data!);
  }

  // ── Médico ──────────────────────────────────────────────────────────────

  Future<MedicoDto> miPerfilMedico() async {
    final res = await _dio.get<Map<String, dynamic>>('/doctors/me');
    return MedicoDto.fromJson(res.data!);
  }

  Future<MedicoDto> perfilMedicoPorId(int idMedico) async {
    final res = await _dio.get<Map<String, dynamic>>('/doctors/$idMedico');
    return MedicoDto.fromJson(res.data!);
  }

  Future<MedicoDto> crearPerfilMedico(CrearMedicoDto body) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/doctors',
      data: body.toJson(),
    );
    return MedicoDto.fromJson(res.data!);
  }

  /// `PATCH /doctors/{id}` — el backend responde **403** si no es el titular.
  Future<MedicoDto> actualizarPerfilMedico(
    int idMedico,
    ActualizarMedicoDto body,
  ) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/doctors/$idMedico',
      data: _sinNulos(body.toJson()),
    );
    return MedicoDto.fromJson(res.data!);
  }

  Future<MedicoDto> vincularEspecialidades(
    int idMedico,
    List<int> especialidadIds,
  ) async {
    final res = await _dio.put<Map<String, dynamic>>(
      '/doctors/$idMedico/especialidades',
      data: VincularEspecialidadesDto(
        especialidadIds: especialidadIds,
      ).toJson(),
    );
    return MedicoDto.fromJson(res.data!);
  }

  /// Quita las claves nulas del cuerpo.
  ///
  /// `freezed` serializa todos los campos, incluidos los que no se tocaron.
  /// Mandarlos en `null` en un PATCH le diría al backend "borrá esto".
  static Map<String, dynamic> _sinNulos(Map<String, dynamic> json) => {
    for (final e in json.entries)
      if (e.value != null) e.key: e.value,
  };
}
