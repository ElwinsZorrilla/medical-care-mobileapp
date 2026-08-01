import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/tipo_usuario.dart';
import '../../../../core/network/infra_provider.dart';
import '../../../../core/network/result.dart';
import '../../../../core/theme/density_provider.dart';
import '../../data/auth_api.dart';
import '../../data/auth_repository.dart';
import '../../domain/usuario.dart';

part 'auth_provider.g.dart';

// `secureStoreProvider` y `dioClienteProvider` viven ahora en
// `core/network/infra_provider.dart`. Estaban aquí y los seis features los
// importaban desde este archivo: siete violaciones de "un feature no importa
// de otro" (rubro 3.3), arrastradas desde F04.

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) => AuthRepository(
  AuthApi(ref.watch(dioClienteProvider)),
  ref.watch(secureStoreProvider),
);

/// Estado de sesión de la app.
///
/// Arranca en [SesionDesconocida] y no pasa a [SesionAnonima] hasta haber
/// consultado el almacenamiento. Esa distinción es lo que evita el parpadeo
/// del login al abrir la app.
@Riverpod(keepAlive: true)
class SesionActual extends _$SesionActual {
  @override
  Sesion build() {
    // `core` avisa cuando el refresh ya no puede recuperar la sesión. Se
    // **escucha** en vez de que `core` llame acá: así la dependencia va de
    // feature a core y no al revés, que es lo que impedía subir el cliente
    // HTTP en F13.
    ref.listen(sesionExpiradaProvider, (_, _) => expirar());

    // Se dispara sin await: el estado inicial es "desconocida" y la UI
    // muestra el splash hasta que esto resuelva.
    Future.microtask(restaurar);
    return const Sesion.desconocida();
  }

  /// Lee el token guardado y resuelve la sesión. Se llama al arrancar.
  Future<void> restaurar() async {
    final resultado = await ref.read(authRepositoryProvider).restaurarSesion();
    state = resultado.when(
      ok: (usuario) => usuario == null
          ? const Sesion.anonima()
          : Sesion.autenticada(usuario),
      // Si falla por red, no se puede afirmar que no haya sesión. Se deja
      // anónima igual —es lo único accionable— pero sin borrar los tokens:
      // al recuperar conexión, el siguiente arranque los encuentra.
      fallo: (_) => const Sesion.anonima(),
    );
    _sincronizarDensidad();
  }

  Future<Result<Usuario>> iniciarSesion({
    required String correo,
    required String contrasena,
  }) async {
    final resultado = await ref
        .read(authRepositoryProvider)
        .iniciarSesion(correo: correo, contrasena: contrasena);
    _aplicar(resultado);
    return resultado;
  }

  Future<Result<Usuario>> registrar({
    required String correo,
    required String contrasena,
    required TipoUsuario tipo,
    String? telefono,
  }) async {
    final resultado = await ref
        .read(authRepositoryProvider)
        .registrar(
          correo: correo,
          contrasena: contrasena,
          tipo: tipo,
          telefono: telefono,
        );
    _aplicar(resultado);
    return resultado;
  }

  /// RF-05 — cierra sesión en el dispositivo.
  Future<void> cerrarSesion() async {
    await ref.read(authRepositoryProvider).cerrarSesion();
    state = const Sesion.anonima();
    _sincronizarDensidad();
  }

  /// La llama el interceptor cuando el refresh ya no puede recuperar nada.
  void expirar() {
    state = const Sesion.anonima();
    _sincronizarDensidad();
  }

  void _aplicar(Result<Usuario> resultado) {
    if (resultado case Ok(:final valor)) {
      state = Sesion.autenticada(valor);
      _sincronizarDensidad();
    }
  }

  /// La densidad de la interfaz la decide el rol (DESIGN_SYSTEM.md §5).
  void _sincronizarDensidad() {
    final tipo = state.usuario?.tipo;
    ref
        .read(densidadUiProvider.notifier)
        .establecer(tipo?.densidad ?? TipoUsuario.paciente.densidad);
  }
}
