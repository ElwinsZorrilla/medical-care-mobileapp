import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/infra_provider.dart';
import '../../../../core/network/result.dart';
import '../../data/lanzador_sala.dart';
import '../../data/video_api.dart';
import '../../data/video_repository.dart';
import '../../domain/videollamada.dart';

part 'video_provider.g.dart';

@Riverpod(keepAlive: true)
VideoRepository videoRepository(Ref ref) =>
    VideoRepository(VideoApi(ref.watch(dioClienteProvider)));

@Riverpod(keepAlive: true)
LanzadorSala lanzadorSala(Ref ref) => const LanzadorSalaImpl();

/// La sala de una cita — RF-35, RF-36, RF-37.
///
/// Arranca con `POST` y no con `GET` a proposito: el endpoint es idempotente
/// y consultar primero para crear despues seria una ida y vuelta de mas, con
/// una ventana en la que dos participantes crean dos salas distintas.
@riverpod
class Sala extends _$Sala {
  @override
  Future<Videollamada> build(int idCita) async {
    final r = await ref.read(videoRepositoryProvider).abrirSala(idCita);
    return switch (r) {
      Ok(:final valor) => valor,
      Fallo(:final failure) => throw failure,
    };
  }

  /// RF-35 — entrar a la consulta.
  ///
  /// Marca `EN_CURSO` **antes** de abrir la sala: si se abriera primero, la
  /// app pasa a segundo plano y el cambio de estado se queda a medias. El
  /// orden inverso deja el registro de horas mintiendo.
  ///
  /// Devuelve el fallo si no se pudo entrar, o `null` si todo salio bien.
  Future<Failure?> entrar() async {
    final actual = state.value;
    if (actual == null) return null;
    if (!actual.estado.admiteEntrada) {
      return const Conflicto('Esa consulta ya termino.');
    }

    if (actual.estado.puedeIrA(EstadoVideollamada.enCurso)) {
      final fallo = await cambiarEstado(EstadoVideollamada.enCurso);
      // Se sigue igual si el estado no se pudo mover: lo que el usuario vino
      // a hacer es entrar a la consulta, no actualizar una columna.
      if (fallo is SinConexion) return fallo;
    }

    final url = state.value?.urlSala ?? actual.urlSala;
    final abrio = await ref.read(lanzadorSalaProvider).abrir(url);
    if (!abrio) {
      return const ErrorInesperado(
        'No pudimos abrir la sala. Revisa que tengas un navegador instalado.',
      );
    }
    return null;
  }

  /// RF-37 — mover el estado.
  ///
  /// Devuelve el fallo, o `null` si funciono. No lanza: un cambio de estado
  /// que falla no puede dejar la pantalla en blanco cuando lo que se estaba
  /// mostrando sigue siendo cierto.
  Future<Failure?> cambiarEstado(EstadoVideollamada nuevo) async {
    final actual = state.value;
    if (actual == null) return null;
    if (!actual.estado.puedeIrA(nuevo)) {
      // La misma tabla que aplica el backend. Sin esta guarda, la app pediria
      // un salto que ya se sabe que devuelve 409.
      return Conflicto(
        'No se puede pasar de ${actual.estado.etiqueta.toLowerCase()} a '
        '${nuevo.etiqueta.toLowerCase()}.',
      );
    }

    final r = await ref
        .read(videoRepositoryProvider)
        .cambiarEstado(idCita, nuevo);

    if (r case Ok(:final valor)) {
      state = AsyncData(valor);
      return null;
    }
    return r.failureONull;
  }
}
