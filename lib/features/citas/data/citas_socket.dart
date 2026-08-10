import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

/// Transporte de tiempo real de citas.
///
/// **El socket solo avisa.** Cancelar sigue yendo por REST (código de estado
/// y reintento); esto solo sirve para que la contraparte se entere sin tener
/// que reabrir la pantalla. Mismo diseño que `ChatSocket`.
///
/// El JWT viaja en `auth.token` del handshake, no en la query — misma razón
/// que en el chat: las URLs quedan en logs de proxy y en historiales.
class CitasSocket {
  CitasSocket({required this.urlBase, required this.token});

  /// Origen del backend **sin** el sufijo `/api`: el namespace del socket
  /// cuelga de la raiz, no del prefijo REST.
  final String urlBase;
  final String token;

  io.Socket? _socket;

  final _cambios = StreamController<void>.broadcast();

  /// Se emite cada vez que una cita propia cambió del lado del servidor
  /// (por ahora, cancelaciones). El servidor ya filtró por usuario al
  /// emitir solo a la sala propia, así que no hace falta decodificar el
  /// payload: cualquier evento que llegue implica refrescar el listado.
  Stream<void> get citasCambiaron => _cambios.stream;

  bool get conectado => _socket?.connected ?? false;

  void conectar() {
    if (_socket != null) return;

    _socket =
        io.io(
            '$urlBase/citas',
            io.OptionBuilder()
                .setTransports(['websocket'])
                .setAuth({'token': token})
                .enableReconnection()
                .build(),
          )
          ..on(eventoCitaCancelada, (_) => _cambios.add(null));
  }

  /// Nombre tal cual lo emite el gateway.
  static const eventoCitaCancelada = 'cita:cancelada';

  Future<void> cerrar() async {
    _socket?.dispose();
    _socket = null;
    await _cambios.close();
  }
}
