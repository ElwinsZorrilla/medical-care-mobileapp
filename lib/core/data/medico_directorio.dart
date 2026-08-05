import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/especialidad.dart';
import '../domain/medico.dart';
import '../network/infra_provider.dart';
import 'medico_dto.dart';

part 'medico_directorio.g.dart';

/// Resuelve `idMedico` → [PerfilMedico], con caché en memoria.
///
/// ## Por qué existe
///
/// `AppointmentResponseDto` devuelve **ids planos**: `idMedico: 2`, sin
/// nombre ni especialidad (verificado en F00). Para pintar la tarjeta de una
/// cita hace falta el nombre del médico, así que cada cita necesita una
/// resolución extra.
///
/// Sin caché, una lista de 10 citas son **10 peticiones** a `/doctors/{id}`,
/// y la agenda del médico con 50 citas serían 50. Con datos móviles lentos
/// —el usuario que describe `DESIGN_SYSTEM.md` §1— eso es la diferencia entre
/// una lista que aparece y una que tarda diez segundos. RNF-07 se cae solo
/// por esto.
///
/// ## Qué resuelve la caché
///
/// Las citas se repiten mucho entre médicos: un paciente suele tener varias
/// con el mismo. Diez citas de tres médicos distintos son **tres**
/// peticiones, no diez. Además coalesce las simultáneas: si dos tarjetas
/// piden el mismo id a la vez, sale una sola petición y las dos esperan ese
/// mismo `Future` — el mismo patrón del refresh de F03.
///
/// Vive en `core/` porque la necesitan `citas` (listados) y `historial`
/// (consultas), y un feature no importa de otro.
class MedicoDirectorio {
  MedicoDirectorio(this._dio);

  final Dio _dio;

  /// Lo ya resuelto. No expira durante la sesión: el nombre de un médico y
  /// su exequátur no cambian mientras alguien mira su agenda.
  final Map<int, PerfilMedico> _cache = {};

  /// Peticiones en vuelo, para no disparar dos por el mismo id.
  final Map<int, Future<PerfilMedico?>> _enVuelo = {};

  /// Cuántas veces se salió a la red. Solo para pruebas.
  int get peticiones => _peticiones;
  int _peticiones = 0;

  /// Lo que ya está resuelto, sin esperar.
  ///
  /// La usa la UI para pintar de inmediato lo que tiene y dejar el resto en
  /// estado de carga, en vez de bloquear la lista entera.
  PerfilMedico? enCache(int idMedico) => _cache[idMedico];

  /// Resuelve un médico. `null` si no se pudo.
  ///
  /// **No lanza.** Que no se pueda resolver un nombre no debe tumbar la
  /// lista de citas: se pinta la cita sin el nombre, que sigue siendo útil
  /// —fecha, hora y estado están ahí— en vez de una pantalla de error.
  Future<PerfilMedico?> resolver(int idMedico) {
    final yaEsta = _cache[idMedico];
    if (yaEsta != null) return Future.value(yaEsta);

    final enCurso = _enVuelo[idMedico];
    if (enCurso != null) return enCurso;

    final futuro = _pedir(idMedico);
    _enVuelo[idMedico] = futuro;
    return futuro;
  }

  /// Resuelve varios de una vez, sin repetir ids.
  Future<void> precargar(Iterable<int> ids) async {
    final pendientes = ids.toSet().where((id) => !_cache.containsKey(id));
    await Future.wait(pendientes.map(resolver));
  }

  Future<PerfilMedico?> _pedir(int idMedico) async {
    _peticiones++;
    try {
      final res = await _dio.get<Map<String, dynamic>>('/doctors/$idMedico');
      final dto = MedicoDto.fromJson(res.data!);
      final medico = _aEntidad(dto);
      _cache[idMedico] = medico;
      return medico;
    } on DioException {
      return null;
    } on ArgumentError {
      // Estado de verificación desconocido. La cita se pinta sin nombre.
      return null;
    } finally {
      // `remove` devolveria el Future guardado y el analizador exigiria
      // esperarlo; `removeWhere` no devuelve nada y expresa lo mismo.
      _enVuelo.removeWhere((id, _) => id == idMedico);
    }
  }

  PerfilMedico _aEntidad(MedicoDto dto) => PerfilMedico(
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

/// El directorio, compartido.
///
/// El provider vivia en `citas`, con la clase ya aca. Cuando `chat` necesito
/// resolver el nombre del medico de una conversacion, esa asimetria se volvio
/// un import cruzado: bajo a `core/` junto a lo que ya estaba.
///
/// `keepAlive`: el valor de la cache esta en que sobrevive a la navegacion.
/// Si se reconstruyera al volver a la lista, cada visita pagaria de nuevo las
/// mismas peticiones.
@Riverpod(keepAlive: true)
MedicoDirectorio medicoDirectorio(Ref ref) =>
    MedicoDirectorio(ref.watch(dioClienteProvider));
