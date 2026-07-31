import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_router.g.dart';

/// Rutas de la app.
///
/// F01 deja solo el esqueleto. El `redirect` por rol (RF-06) entra en F04,
/// cuando exista el estado de sesión: sin los tres estados
/// —desconocido / autenticado / anónimo— el login parpadea al arrancar.
@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  return GoRouter(
    initialLocation: Rutas.inicio,
    routes: <RouteBase>[
      GoRoute(
        path: Rutas.inicio,
        name: 'inicio',
        builder: (BuildContext context, GoRouterState state) =>
            const _PantallaInicial(),
      ),
    ],
  );
}

/// Rutas con nombre, en un solo lugar.
///
/// Un string de ruta repetido en dos archivos es un bug esperando: se cambia
/// uno y el otro queda apuntando a la nada.
abstract final class Rutas {
  static const String inicio = '/';
}

/// Placeholder de F01. La reemplaza el flujo real de autenticación en F04.
class _PantallaInicial extends StatelessWidget {
  const _PantallaInicial();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: SizedBox.shrink());
  }
}
