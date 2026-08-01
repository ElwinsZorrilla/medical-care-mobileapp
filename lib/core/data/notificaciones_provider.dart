import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../network/infra_provider.dart';
import '../network/result.dart';
import 'notificaciones_api.dart';
import 'notificaciones_repository.dart';

part 'notificaciones_provider.g.dart';

/// El acceso a notificaciones vive en `core/` y no en su feature porque lo
/// necesita la campana de la barra, que aparece en pantallas de tres features
/// distintos. Si viviera en `features/notificaciones/`, `core/widgets/` tendria
/// que importar de un feature — lo que `ARCHITECTURE.md` prohibe con esas
/// palabras— y `citas`, `perfil` e `historial` acabarian dependiendo de
/// `notificaciones` a traves del barril de widgets.
///
/// Es el mismo criterio de `medico_directorio.dart` y `turnos_repository.dart`.
/// El feature conserva lo suyo: el notificador de la bandeja y la pantalla.
@Riverpod(keepAlive: true)
NotificacionesRepository notificacionesRepository(Ref ref) =>
    NotificacionesRepository(NotificacionesApi(ref.watch(dioClienteProvider)));

/// Cuantas sin leer — el numero del badge.
///
/// **Propaga el fallo** en vez de devolver 0. Tragarlo dejaba el provider
/// fuera de estado de error, y con eso `PoliticaReintento` nunca se activaba:
/// un 503 transitorio que la politica habria recuperado dejaba el badge
/// clavado en cero. El widget ya absorbe el error con `.value ?? 0`.
@riverpod
Future<int> sinLeer(Ref ref) async {
  final r = await ref.watch(notificacionesRepositoryProvider).sinLeer();
  return switch (r) {
    Ok(:final valor) => valor,
    Fallo(:final failure) => throw failure,
  };
}
