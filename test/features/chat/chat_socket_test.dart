import 'package:flutter_test/flutter_test.dart';
import 'package:medicare/features/chat/data/chat_dto.dart';
import 'package:medicare/features/chat/data/chat_socket.dart';

/// El transporte de tiempo real — RF-32.
///
/// No se levanta un servidor: lo que puede romperse de verdad es la
/// **decodificacion** del evento. Si el gateway renombrara un campo, el chat
/// quedaria mudo y la suite seguiria verde. Por eso el payload se arma con
/// `MensajeDto.toJson()` real y no con un mapa escrito a mano.
void main() {
  late ChatSocket socket;

  setUp(
    () => socket = ChatSocket(urlBase: 'http://localhost:3000', token: 'jwt'),
  );
  tearDown(() => socket.cerrar());

  const dto = MensajeDto(
    idMensaje: 9,
    idConversacion: 1,
    idUsuarioRemitente: 30,
    contenido: 'Buenos dias',
    fechaEnvio: '2026-08-17T12:00:00.000Z',
    leido: true,
    urlAdjunto: '/uploads/analitica.pdf',
  );

  test('un mensaje nuevo llega mapeado entero', () async {
    final futuro = socket.mensajes.first;
    socket.manejar(ChatSocket.eventoMensaje, dto.toJson());

    final m = await futuro;
    expect(m.id, 9);
    expect(m.idConversacion, 1);
    expect(m.idRemitente, 30);
    expect(m.contenido, 'Buenos dias');
    expect(m.urlAdjunto, '/uploads/analitica.pdf');
    expect(m.leido, isTrue);
  });

  test('la fecha del evento es UTC — RNF-18', () async {
    final futuro = socket.mensajes.first;
    socket.manejar(ChatSocket.eventoMensaje, dto.toJson());

    final m = await futuro;
    expect(m.enviadoUtc.isUtc, isTrue);
    expect(m.enviadoUtc, DateTime.utc(2026, 8, 17, 12));
  });

  test('el acuse de lectura publica el id del hilo — RF-33', () async {
    final futuro = socket.lecturas.first;
    socket.manejar(ChatSocket.eventoLectura, {'idConversacion': 4});

    expect(await futuro, 4);
  });

  test('un payload roto no tumba la app', () async {
    // Llega por la red y nadie del lado cliente lo valido. Se descarta.
    final recibidos = <Object>[];
    final sub = socket.mensajes.listen(recibidos.add);
    addTearDown(sub.cancel);

    socket
      ..manejar(ChatSocket.eventoMensaje, {'idMensaje': 9})
      ..manejar(ChatSocket.eventoMensaje, 'no es un mapa')
      ..manejar(ChatSocket.eventoMensaje, null)
      ..manejar(ChatSocket.eventoLectura, {'idConversacion': 'cuatro'})
      ..manejar('evento:inventado', dto.toJson());

    await Future<void>.delayed(Duration.zero);
    expect(recibidos, isEmpty);
  });

  test('una fecha invalida se descarta en vez de propagarse', () async {
    final recibidos = <Object>[];
    final sub = socket.mensajes.listen(recibidos.add);
    addTearDown(sub.cancel);

    socket.manejar(
      ChatSocket.eventoMensaje,
      const MensajeDto(
        idMensaje: 9,
        idConversacion: 1,
        idUsuarioRemitente: 30,
        contenido: 'x',
        fechaEnvio: 'ayer',
      ).toJson(),
    );

    await Future<void>.delayed(Duration.zero);
    expect(recibidos, isEmpty);
  });

  test('sin conectar, no hay socket que reportar', () {
    // `conectado` se consulta antes de `conectar()` en la pantalla.
    expect(socket.conectado, isFalse);
  });
}
