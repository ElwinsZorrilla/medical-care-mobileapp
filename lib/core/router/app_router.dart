import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/agenda/presentation/screens/disponibilidad_screen.dart';
import '../../features/auth/domain/usuario.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/registro_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/busqueda/presentation/screens/busqueda_screen.dart';
import '../../features/citas/presentation/screens/mis_citas_screen.dart';
import '../../features/historial/presentation/screens/historial_screen.dart';
import '../../features/perfil/presentation/screens/perfil_screen.dart';
import '../domain/tipo_usuario.dart';

part 'app_router.g.dart';

/// Rutas de la app, con guard por rol — RF-06.
@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  return GoRouter(
    initialLocation: Rutas.splash,
    // `refreshListenable` no sirve con Riverpod: se escucha el provider y se
    // fuerza la reevaluación del redirect cuando cambia la sesión.
    refreshListenable: _SesionListenable(ref),
    redirect: (context, state) {
      final sesion = ref.read(sesionActualProvider);
      final yendoA = state.matchedLocation;

      // Mientras no se sepa si hay sesión, nadie se mueve de la splash.
      // Redirigir acá es lo que produce el parpadeo del login al arrancar.
      if (!sesion.estaResuelta) {
        return yendoA == Rutas.splash ? null : Rutas.splash;
      }

      final publica = Rutas.publicas.contains(yendoA);

      if (!sesion.estaAutenticada) {
        return publica ? null : Rutas.login;
      }

      // Autenticado: no tiene sentido dejarlo en login, registro o splash.
      if (publica || yendoA == Rutas.splash) {
        return Rutas.deInicioPara(sesion.usuario!.tipo);
      }

      // Guard por rol: el área del médico no se abre para un paciente ni al
      // revés. La UI no ofrece esos enlaces, pero un deep link sí puede
      // llegar directo — por ejemplo desde una notificación.
      final areaMedico = yendoA.startsWith(Rutas.agenda);
      final areaPaciente = yendoA.startsWith(Rutas.misCitas);
      final tipo = sesion.usuario!.tipo;

      if (areaMedico && tipo != TipoUsuario.medico) {
        return Rutas.deInicioPara(tipo);
      }
      if (areaPaciente && tipo != TipoUsuario.paciente) {
        return Rutas.deInicioPara(tipo);
      }

      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: Rutas.splash,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: Rutas.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: Rutas.registro,
        name: 'registro',
        builder: (context, state) => const RegistroScreen(),
      ),
      GoRoute(
        path: Rutas.misCitas,
        name: 'misCitas',
        builder: (context, state) => const MisCitasScreen(),
      ),
      GoRoute(
        path: Rutas.agenda,
        name: 'agenda',
        builder: (context, state) => const MisCitasScreen(agenda: true),
      ),
      GoRoute(
        path: Rutas.disponibilidad,
        name: 'disponibilidad',
        builder: (context, state) => const DisponibilidadScreen(),
      ),
      GoRoute(
        path: Rutas.busqueda,
        name: 'busqueda',
        builder: (context, state) => const BusquedaScreen(),
      ),
      GoRoute(
        path: Rutas.historial,
        name: 'historial',
        builder: (context, state) => const HistorialScreen(),
      ),
      GoRoute(
        path: Rutas.perfil,
        name: 'perfil',
        builder: (context, state) => const PerfilScreen(),
      ),
    ],
  );
}

/// Puente entre Riverpod y `go_router`.
///
/// `GoRouter` reevalúa el `redirect` cuando este `Listenable` notifica. Sin
/// él, iniciar sesión cambiaría el estado pero la ruta se quedaría quieta.
class _SesionListenable extends ChangeNotifier {
  _SesionListenable(Ref ref) {
    ref.listen<Sesion>(sesionActualProvider, (_, _) => notifyListeners());
  }
}

/// Rutas con nombre, en un solo lugar.
///
/// Un string de ruta repetido en dos archivos es un bug esperando: se cambia
/// uno y el otro queda apuntando a la nada.
abstract final class Rutas {
  static const String splash = '/';
  static const String login = '/login';
  static const String registro = '/registro';
  static const String misCitas = '/mis-citas';
  static const String agenda = '/agenda';

  /// Comun a los dos roles: la pantalla resuelve cual mostrar segun el token.
  static const String perfil = '/perfil';

  /// Buscar medico. La abre el paciente desde su listado de citas.
  static const String busqueda = '/buscar';

  /// Franjas del medico. Area exclusiva del rol MEDICO.
  static const String disponibilidad = '/agenda/disponibilidad';

  /// Historial clinico. La ruta del backend la elige el rol de la sesion,
  /// asi que no hay parametro de paciente que alguien pueda manipular.
  static const String historial = '/historial';

  /// Accesibles sin sesión.
  static const Set<String> publicas = {login, registro};

  /// Dónde entra cada rol después de autenticarse.
  static String deInicioPara(TipoUsuario tipo) => switch (tipo) {
    TipoUsuario.medico => agenda,
    TipoUsuario.paciente => misCitas,
    // El panel de admin no es parte del alcance móvil; se le da la vista de
    // paciente para que la app no quede en una ruta que no existe.
    TipoUsuario.admin => misCitas,
  };
}
