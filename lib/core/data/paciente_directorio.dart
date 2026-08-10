import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/paciente.dart';
import '../network/infra_provider.dart';
import 'paciente_dto.dart';

part 'paciente_directorio.g.dart';

/// Resuelve `idPaciente` → [PacienteBasico], con caché en memoria.
///
/// ## Por qué existe
///
/// `AppointmentResponseDto` devuelve **ids planos**: `idPaciente: 2`, sin
/// nombre (verificado en F00, documentado en BACKEND_ISSUES.md #10). Para
/// pintar la agenda del médico con el nombre del paciente hace falta una
/// resolución extra — el mismo problema que `MedicoDirectorio` resuelve para
/// el lado del paciente.
///
/// `GET /patients/{id}` (agregado para cerrar #10) es privado: solo responde
/// si el médico autenticado tiene una cita con ese paciente. Un 403 se trata
/// igual que un 404 — no se pudo resolver, la cita se pinta sin nombre.
///
/// Mismo criterio de caché y coalescencia que `MedicoDirectorio`: sin ella,
/// una agenda de 50 citas serían 50 peticiones en vez de tantas como
/// pacientes distintos haya.
class PacienteDirectorio {
  PacienteDirectorio(this._dio);

  final Dio _dio;

  final Map<int, PacienteBasico> _cache = {};
  final Map<int, Future<PacienteBasico?>> _enVuelo = {};

  int get peticiones => _peticiones;
  int _peticiones = 0;

  PacienteBasico? enCache(int idPaciente) => _cache[idPaciente];

  /// Resuelve un paciente. `null` si no se pudo —no tiene cita con él, o
  /// falló la red—, y **no lanza**: la cita se pinta sin el nombre en vez de
  /// tumbar la lista entera.
  Future<PacienteBasico?> resolver(int idPaciente) {
    final yaEsta = _cache[idPaciente];
    if (yaEsta != null) return Future.value(yaEsta);

    final enCurso = _enVuelo[idPaciente];
    if (enCurso != null) return enCurso;

    final futuro = _pedir(idPaciente);
    _enVuelo[idPaciente] = futuro;
    return futuro;
  }

  Future<void> precargar(Iterable<int> ids) async {
    final pendientes = ids.toSet().where((id) => !_cache.containsKey(id));
    await Future.wait(pendientes.map(resolver));
  }

  Future<PacienteBasico?> _pedir(int idPaciente) async {
    _peticiones++;
    try {
      final res = await _dio.get<Map<String, dynamic>>('/patients/$idPaciente');
      final dto = PacienteBasicoDto.fromJson(res.data!);
      final paciente = _aEntidad(dto);
      _cache[idPaciente] = paciente;
      return paciente;
    } on DioException {
      // 403 (sin cita con ese paciente) o 404: los dos son "no resuelto".
      return null;
    } finally {
      _enVuelo.removeWhere((id, _) => id == idPaciente);
    }
  }

  PacienteBasico _aEntidad(PacienteBasicoDto dto) => PacienteBasico(
    idPaciente: dto.idPaciente,
    idUsuario: dto.idUsuario,
    nombres: dto.nombres,
    apellidos: dto.apellidos,
  );
}

/// El directorio, compartido. `keepAlive` por la misma razón que
/// `medicoDirectorioProvider`: la caché tiene que sobrevivir a la
/// navegación.
@Riverpod(keepAlive: true)
PacienteDirectorio pacienteDirectorio(Ref ref) =>
    PacienteDirectorio(ref.watch(dioClienteProvider));
