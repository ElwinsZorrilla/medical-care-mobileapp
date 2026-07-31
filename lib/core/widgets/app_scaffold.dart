import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

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
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.leading,
    this.tituloCompacto = false,
    super.key,
  });

  final String titulo;
  final Widget body;
  final List<Widget>? acciones;

  // `sinConexion` y `onReintentarConexion` se eliminaron en F15.
  //
  // Su doc decia "lo inyecta el observador global de conectividad (F13)" y ese
  // observador nunca se escribio: ninguna de las diez pantallas pasaba los
  // parametros, asi que `OfflineBanner` solo aparecia en la galeria de
  // desarrollo. Un parametro que nadie usa con un comentario que afirma que si
  // es peor que no tenerlo: hace creer que el cuarto estado esta cubierto.
  //
  // Hoy `SinConexion` llega a `ErrorState` con su mensaje y su boton, que es
  // accionable y correcto. Un banner global ademas necesitaria un paquete de
  // conectividad, que reporta la interfaz de red y no si el servidor responde:
  // diria "con conexion" en el wifi de un cafe que no deja salir.

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
        child: Column(children: [Expanded(child: body)]),
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
