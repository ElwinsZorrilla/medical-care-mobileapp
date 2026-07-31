import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'offline_banner.dart';

/// Andamio de pantalla.
///
/// Centraliza el fondo `paper`, el título en `display` y el banner de sin
/// conexión, para que ninguna pantalla vuelva a resolver eso por su cuenta.
///
/// El banner es global a propósito: el estado de conexión no pertenece a una
/// pantalla, y repetir la lógica en cada una garantiza que alguna se olvide.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.titulo,
    required this.body,
    this.acciones,
    this.sinConexion = false,
    this.onReintentarConexion,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.leading,
    this.tituloCompacto = false,
    super.key,
  });

  final String titulo;
  final Widget body;
  final List<Widget>? acciones;

  /// Lo inyecta el observador global de conectividad (F13).
  final bool sinConexion;
  final VoidCallback? onReintentarConexion;

  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final Widget? leading;

  /// Usa `title` en vez de `display`. Para pantallas de segundo nivel, donde
  /// un titular de 32px se come el espacio útil.
  final bool tituloCompacto;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;

    return Scaffold(
      backgroundColor: colors.paper,
      appBar: AppBar(
        leading: leading,
        actions: acciones,
        titleSpacing: leading == null ? Space.lg : null,
        title: Text(
          titulo,
          style: tituloCompacto ? text.title : text.display,
          // Con textScale 2.0 el titular baja de tamaño antes que recortarse.
          overflow: TextOverflow.ellipsis,
        ),
        toolbarHeight: tituloCompacto ? kToolbarHeight : Space.huge + Space.md,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (sinConexion) OfflineBanner(onReintentar: onReintentarConexion),
            Expanded(child: body),
          ],
        ),
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
