import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/notificaciones_provider.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// Campana con contador — RF-28.
///
/// Vive en `core/widgets/` porque la usan pantallas de tres features y un
/// feature no importa de otro (rubro 3.3). Por eso el acceso a datos tambien
/// subio a `core/data/`: si el contador viviera en el feature, `core` tendria
/// que importar de `features/`, que ARCHITECTURE.md prohibe con esas palabras
/// —y `citas`, `perfil` e `historial` acabarian dependiendo de
/// `notificaciones` a traves del barril de widgets.
///
/// El contador es un `Text` sobre el icono y no un punto de color: "3" dice
/// cuantas hay, un punto solo dice "algo". Y si el contador falla, el provider
/// devuelve 0 y la campana se pinta sin badge — un numero que no se pudo
/// cargar no puede tumbar la pantalla que lo muestra.
class CampanaNotificaciones extends ConsumerWidget {
  const CampanaNotificaciones({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sinLeer = ref.watch(sinLeerProvider).value ?? 0;
    final colors = context.colors;

    return Semantics(
      button: true,
      label: sinLeer == 0
          ? 'Notificaciones'
          : 'Notificaciones, $sinLeer sin leer',
      child: IconButton(
        onPressed: () => context.push(Rutas.notificaciones),
        tooltip: 'Notificaciones',
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.notifications_none),
            if (sinLeer > 0)
              Positioned(
                right: -Space.xs,
                top: -Space.xs,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: Space.xs),
                  constraints: const BoxConstraints(minWidth: Space.lg),
                  decoration: BoxDecoration(
                    color: colors.granate,
                    borderRadius: Radii.chip,
                  ),
                  child: Text(
                    // Mas de 99 no cabe y tampoco aporta: lo que importa es
                    // que hay muchas.
                    sinLeer > 99 ? '99+' : '$sinLeer',
                    textAlign: TextAlign.center,
                    style: context.text.caption.copyWith(color: colors.surface),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
