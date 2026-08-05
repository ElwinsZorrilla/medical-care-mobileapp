@Tags(['servidor'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicare/core/domain/medico.dart';
import 'package:medicare/core/domain/pagina.dart';
import 'package:medicare/core/network/result.dart';
import 'package:medicare/features/busqueda/data/busqueda_api.dart';
import 'package:medicare/features/busqueda/data/busqueda_repository.dart';
import 'package:medicare/features/chat/data/chat_api.dart';
import 'package:medicare/features/chat/data/chat_repository.dart';
import 'package:medicare/features/chat/domain/chat.dart';
import 'package:medicare/features/perfil/data/perfil_api.dart';
import 'package:medicare/features/perfil/data/perfil_repository.dart';

/// Ejerce el código real del front contra un backend real.
///
/// **Por qué existe.** Las 620 pruebas del proyecto estaban verdes mientras
/// la app se cerraba al guardar un perfil de médico. Todas construían el JSON
/// a mano con el tipo que el front esperaba —`{'tarifaConsulta': 1500}`— y
/// ninguna preguntó nunca qué manda el servidor de verdad, que es
/// `"1500.00"`, una cadena, porque la columna es `Decimal`.
///
/// Es la misma lección que este proyecto viene aprendiendo, esta vez sobre el
/// borde con el backend: **una prueba que fabrica su propia entrada solo
/// verifica que el código coincide consigo mismo.**
///
/// **Viven en `test_servidor/` y no en `test/`** porque `flutter test` sin
/// argumentos solo recorre `test/`: así el gate y CI las ignoran sin depender
/// de que nadie olvide un flag. No es `integration_test/`, que Flutter
/// reserva para pruebas sobre un dispositivo conectado.
///
/// Se corren a mano contra el backend levantado:
///
/// ```
/// cd back && docker start medicare_postgres medicare_redis && npm run start:dev
/// cd front && flutter test test_servidor/
/// ```
const _base = 'http://localhost:3000/api';

void main() {
  late String tokenMedico;
  late String tokenPaciente;
  late int idMedico;
  late int idConversacion;

  /// Levanta un médico y un paciente nuevos, los conecta por un mensaje.
  ///
  /// Se hace con `HttpClient` crudo y no con el propio front: si el front
  /// montara el escenario, un error suyo lo dejaría montado mal y la prueba
  /// mediría su propio defecto como si fuera el del servidor.
  setUpAll(() async {
    final sello = DateTime.now().microsecondsSinceEpoch;

    Future<Map<String, dynamic>> pedir(
      String metodo,
      String ruta, {
      Map<String, dynamic>? cuerpo,
      String? token,
    }) async {
      final cliente = HttpClient();
      final req = await cliente.openUrl(metodo, Uri.parse('$_base$ruta'));
      req.headers.contentType = ContentType.json;
      if (token != null) req.headers.add('Authorization', 'Bearer $token');
      if (cuerpo != null) req.write(jsonEncode(cuerpo));
      final res = await req.close();
      final texto = await res.transform(utf8.decoder).join();
      cliente.close();
      if (res.statusCode >= 400) {
        fail('$metodo $ruta -> ${res.statusCode} $texto');
      }
      final json = jsonDecode(texto);
      return json is Map<String, dynamic> ? json : {'lista': json};
    }

    tokenMedico =
        (await pedir(
              'POST',
              '/auth/register',
              cuerpo: {
                'correo': 'med$sello@prueba.local',
                'contrasena': 'Passw0rd!',
                'tipoUsuario': 'MEDICO',
              },
            ))['accessToken']
            as String;

    // Con tarifa: es el campo que tumbaba la app. Sin ella la prueba pasaría
    // igual que pasaban las 620, porque `null` encaja en cualquier tipo.
    idMedico =
        (await pedir(
              'POST',
              '/doctors',
              token: tokenMedico,
              cuerpo: {
                'nombres': 'Elwin',
                'apellidos': 'Zorrilla',
                'numExequatur': 'EXQ-$sello',
                'tarifaConsulta': 1500,
                'aniosExperiencia': 5,
              },
            ))['idMedico']
            as int;

    tokenPaciente =
        (await pedir(
              'POST',
              '/auth/register',
              cuerpo: {
                'correo': 'pac$sello@prueba.local',
                'contrasena': 'Passw0rd!',
                'tipoUsuario': 'PACIENTE',
              },
            ))['accessToken']
            as String;

    await pedir(
      'POST',
      '/patients',
      token: tokenPaciente,
      cuerpo: {
        'nombres': 'Juan',
        'apellidos': 'Perez',
        'documentoIdentidad': '001-${sello % 10000000}-1',
        'fechaNacimiento': '1990-05-10',
      },
    );

    idConversacion =
        (await pedir(
              'POST',
              '/chat/conversations',
              token: tokenPaciente,
              cuerpo: {'idMedico': idMedico},
            ))['idConversacion']
            as int;

    await pedir(
      'POST',
      '/chat/conversations/$idConversacion/messages',
      token: tokenPaciente,
      cuerpo: {'contenido': 'Doctor, buenas tardes'},
    );
  });

  Dio dioCon(String token) => Dio(
    BaseOptions(baseUrl: _base, headers: {'Authorization': 'Bearer $token'}),
  );

  group('el paciente ve a los médicos — RF-12', () {
    test('la lista incluye al médico que tiene tarifa', () async {
      // Reproduce el reporte "los doctores no le aparecen a los pacientes":
      // basta que **un** médico tenga tarifa para que el parseo de la lista
      // entera reviente, porque el `Decimal` viaja como cadena.
      //
      // Se recorren **todas** las páginas y no solo la primera. El backend
      // devuelve los médicos por id ascendente, así que el recién creado está
      // al final: mirar solo la página 1 daba un rojo que no era del código.
      // Recorrerlas también ejerce la paginación de verdad, que es donde el
      // front calcula si quedan más —el backend no manda `lastPage`.
      final repo = BusquedaRepository(BusquedaApi(dioCon(tokenPaciente)));

      final encontrados = <PerfilMedico>[];
      var pagina = 1;
      while (true) {
        final r = await repo.medicos(pagina: pagina);
        expect(r, isA<Ok<dynamic>>(), reason: 'la búsqueda falló: $r');
        final p = (r as Ok<Pagina<PerfilMedico>>).valor;
        encontrados.addAll(p.items);
        if (!p.hayMas || p.items.isEmpty) break;
        pagina++;
      }

      final elNuestro = encontrados.where((m) => m.idMedico == idMedico);
      expect(
        elNuestro,
        isNotEmpty,
        reason:
            'el médico recién creado no aparece en la búsqueda '
            '(${encontrados.length} médicos en $pagina páginas)',
      );
      expect(elNuestro.first.tarifaConsulta, 1500.0);
    });
  });

  group('el médico guarda su perfil — RF-10', () {
    test('leer el perfil propio con tarifa no lanza', () async {
      // El camino exacto del crash reportado: `PerfilApi` -> `MedicoDto`.
      final repo = PerfilRepository(PerfilApi(dioCon(tokenMedico)));

      final r = await repo.miPerfilMedico();

      expect(r, isA<Ok<dynamic>>(), reason: 'el perfil falló: $r');
      expect((r as Ok).valor!.tarifaConsulta, 1500.0);
    });

    test('actualizar la tarifa devuelve el valor nuevo', () async {
      final repo = PerfilRepository(PerfilApi(dioCon(tokenMedico)));

      final r = await repo.actualizarPerfilMedico(
        idMedico: idMedico,
        tarifaConsulta: 2500.50,
      );

      expect(r, isA<Ok<dynamic>>(), reason: 'la actualización falló: $r');
      // Y con decimales, que es donde una cadena mal parseada se nota.
      expect((r as Ok).valor.tarifaConsulta, 2500.5);
    });
  });

  group('el médico ve los mensajes del paciente — RF-31', () {
    test('la conversación aparece en su listado, con el no leído', () async {
      // Reproduce "los mensajes de los pacientes a los doctores no aparecen".
      final repo = ChatRepository(ChatApi(dioCon(tokenMedico)));

      final r = await repo.conversaciones();

      expect(r, isA<Ok<dynamic>>(), reason: 'el listado falló: $r');
      final hilos = (r as Ok<List<Conversacion>>).valor;
      final elNuestro = hilos.where((c) => c.id == idConversacion);
      expect(
        elNuestro,
        isNotEmpty,
        reason: 'el médico no ve la conversación que le abrió el paciente',
      );
      expect(elNuestro.first.noLeidos, 1);
      expect(elNuestro.first.tieneSinLeer, isTrue);
    });

    test('el contenido del mensaje llega completo', () async {
      final repo = ChatRepository(ChatApi(dioCon(tokenMedico)));

      final r = await repo.mensajes(idConversacion: idConversacion);

      expect(r, isA<Ok<dynamic>>(), reason: 'los mensajes fallaron: $r');
      final mensajes = (r as Ok).valor;
      expect(mensajes, hasLength(1));
      expect(mensajes.first.contenido, 'Doctor, buenas tardes');
      expect(mensajes.first.leido, isFalse);
      // La fecha viaja en UTC (RNF-18) y tiene que llegar como tal.
      expect(mensajes.first.enviadoUtc.isUtc, isTrue);
    });

    test('marcar leídos deja el contador en cero', () async {
      final repo = ChatRepository(ChatApi(dioCon(tokenMedico)));

      final marcado = await repo.marcarLeidos(idConversacion);
      expect(marcado, isA<Ok<dynamic>>(), reason: 'marcar falló: $marcado');

      final r = await repo.conversaciones();
      final elNuestro = (r as Ok<List<Conversacion>>).valor
          .where((c) => c.id == idConversacion)
          .first;
      expect(elNuestro.noLeidos, 0);
    });

    test('el paciente ve su propia conversación', () async {
      final repo = ChatRepository(ChatApi(dioCon(tokenPaciente)));

      final r = await repo.conversaciones();

      expect(r, isA<Ok<dynamic>>());
      expect(
        (r as Ok<List<Conversacion>>).valor.where(
          (c) => c.id == idConversacion,
        ),
        isNotEmpty,
      );
    });
  });
}
