import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../domain/chat.dart';
import 'chat_dto.dart';

/// Transporte de tiempo real — RF-32.
///
/// **El socket solo avisa; enviar sigue yendo por REST.** Si el envio fuera
/// por socket, un mensaje escrito con la conexion caida se perderia sin que
/// nadie lo supiera: no hay codigo de estado ni reintento. Con REST, un envio
/// fallido devuelve un `Failure` que la pantalla puede mostrar.
///
/// El JWT viaja en `auth.token` del handshake y no en la query, porque las
/// URLs quedan en logs de proxy y en historiales de navegador — el objeto
/// `auth` no. Es la misma decision que toma el gateway del backend.
class ChatSocket {
  ChatSocket({required this.urlBase, required this.token});

  /// Origen del backend **sin** el sufijo `/api`: el namespace del socket
  /// cuelga de la raiz, no del prefijo REST.
  final String urlBase;
  final String token;

  io.Socket? _socket;

  final _mensajes = StreamController<Mensaje>.broadcast();
  final _lecturas = StreamController<int>.broadcast();

  /// Mensajes nuevos que llegan sin pedirlos.
  Stream<Mensaje> get mensajes => _mensajes.stream;

  /// Ids de conversacion cuya contraparte acaba de leer — RF-33.
  Stream<int> get lecturas => _lecturas.stream;

  bool get conectado => _socket?.connected ?? false;

  void conectar() {
    if (_socket != null) return;

    _socket =
        io.io(
            '$urlBase/chat',
            io.OptionBuilder()
                .setTransports(['websocket'])
                .setAuth({'token': token})
                // Reconexion automatica: en movil la red se cae al entrar a un
                // ascensor y vuelve sola. Sin esto el chat quedaria mudo hasta
                // reiniciar la app, y como el envio va por REST el usuario no se
                // enteraria de que dejo de recibir.
                .enableReconnection()
                .build(),
          )
          ..on(eventoMensaje, (dato) => manejar(eventoMensaje, dato))
          ..on(eventoLectura, (dato) => manejar(eventoLectura, dato));
  }

  /// Nombres tal cual los emite el gateway. Como constantes y no como
  /// literales sueltos: la prueba usa las mismas, asi que un renombre no
  /// puede dejar la suite verde con el socket mudo.
  static const eventoMensaje = 'mensaje:nuevo';
  static const eventoLectura = 'mensaje:leido';

  /// Decodifica un evento y lo publica.
  ///
  /// Separado de `conectar` para que se pueda ejercer sin servidor: es donde
  /// vive el unico riesgo real del transporte —que el backend renombre un
  /// campo y el chat se quede mudo sin que nada se ponga rojo—. La conexion
  /// en si es una llamada a la libreria.
  @visibleForTesting
  void manejar(String evento, Object? dato) {
    if (dato is! Map) return;
    final json = Map<String, dynamic>.from(dato);

    switch (evento) {
      case eventoMensaje:
        // Un payload incompleto no puede tumbar la app: llega por la red y
        // nadie del lado cliente lo valido.
        try {
          _mensajes.add(_aMensaje(json));
        } on Object {
          return;
        }
      case eventoLectura:
        final id = json['idConversacion'];
        if (id is int) _lecturas.add(id);
    }
  }

  Mensaje _aMensaje(Map<String, dynamic> json) {
    final d = MensajeDto.fromJson(json);
    return Mensaje(
      id: d.idMensaje,
      idConversacion: d.idConversacion,
      idRemitente: d.idUsuarioRemitente,
      contenido: d.contenido,
      urlAdjunto: d.urlAdjunto,
      enviadoUtc: DateTime.parse(d.fechaEnvio).toUtc(),
      leido: d.leido,
    );
  }

  Future<void> cerrar() async {
    _socket?.dispose();
    _socket = null;
    await _mensajes.close();
    await _lecturas.close();
  }
}
