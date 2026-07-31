import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medicare/core/network/redactor.dart';

/// La redacción de logs es un control de seguridad — RNF-06, rubro 3.1.
///
/// Un diagnóstico, una receta o una cédula en logcat es una fuga de historia
/// clínica: cualquier app con permiso de lectura de logs la ve, y cualquiera
/// con el teléfono y `adb` también.
///
/// Estas pruebas corren sobre el **código real** de [Redactor]. La primera
/// versión reimplementaba la lógica en el propio test para poder compararla,
/// lo cual no protege nada: si alguien rompe el original, la copia sigue en
/// verde. Por eso la redacción se extrajo a su propia clase.
void main() {
  String texto(Object? dato) => Redactor.cuerpo(dato).toString();

  group('campos clínicos', () {
    test('el diagnóstico no aparece en claro', () {
      final salida = texto({
        'idConsulta': 1,
        'diagnostico': 'VIH positivo',
        'tratamiento': 'Antirretroviral',
      });

      expect(salida, isNot(contains('VIH positivo')));
      expect(salida, isNot(contains('Antirretroviral')));
      expect(salida, contains(Redactor.marca));
      // Lo que no es sensible sí se ve: un log sin nada útil no sirve.
      expect(salida, contains('idConsulta'));
      expect(salida, contains('1'));
    });

    test('las recetas tampoco', () {
      final salida = texto({
        'recetas': [
          {'medicamento': 'Litio 300mg', 'dosis': '1 tableta'},
        ],
      });
      expect(salida, isNot(contains('Litio')));
    });

    test('los signos vitales tampoco', () {
      final salida = texto({
        'signosVitales': {'presionArterial': '180/110'},
      });
      expect(salida, isNot(contains('180/110')));
    });

    test('alergias y tipo de sangre tampoco', () {
      final salida = texto({'alergias': 'Penicilina', 'tipoSangre': 'O-'});
      expect(salida, isNot(contains('Penicilina')));
    });

    test('el motivo de consulta tampoco', () {
      final salida = texto({'motivoConsulta': 'Sospecha de embarazo'});
      expect(salida, isNot(contains('embarazo')));
    });
  });

  group('credenciales e identidad', () {
    test('la contraseña no aparece', () {
      final salida = texto({
        'correo': 'paciente@correo.com',
        'contrasena': 'Passw0rd!23',
      });
      expect(salida, isNot(contains('Passw0rd!23')));
      // El correo también: es un identificador personal.
      expect(salida, isNot(contains('paciente@correo.com')));
    });

    test('los tokens no aparecen', () {
      final salida = texto({
        'accessToken': 'eyJhbGciOiJIUzI1NiJ9.abc',
        'refreshToken': 'eyJhbGciOiJIUzI1NiJ9.def',
      });
      expect(salida, isNot(contains('eyJhbGci')));
    });

    test('la cédula no aparece', () {
      expect(
        texto({'documentoIdentidad': '00112345678'}),
        isNot(contains('00112345678')),
      );
    });
  });

  group('profundidad', () {
    test('redacta dentro de estructuras anidadas', () {
      // Un campo sensible tres niveles abajo se escapa si la redacción solo
      // mira el primer nivel — y así es como viaja en una respuesta paginada.
      final salida = texto({
        'data': [
          {
            'consulta': {'diagnostico': 'Cáncer de tiroides'},
          },
        ],
        'total': 1,
      });

      expect(salida, isNot(contains('Cáncer de tiroides')));
      expect(salida, contains('total'));
    });

    test('redacta dentro de una lista de listas', () {
      final salida = texto([
        [
          {'diagnostico': 'secreto'},
        ],
      ]);
      expect(salida, isNot(contains('secreto')));
    });
  });

  group('lo que no debe tocar', () {
    test('deja pasar tipos primitivos', () {
      expect(Redactor.cuerpo(null), isNull);
      expect(Redactor.cuerpo(42), 42);
      expect(Redactor.cuerpo('texto suelto'), 'texto suelto');
      expect(Redactor.cuerpo(true), true);
    });

    test('un mapa sin campos sensibles sale intacto', () {
      final entrada = {'idCita': 7, 'estado': 'PENDIENTE'};
      expect(Redactor.cuerpo(entrada), entrada);
    });

    test('conserva la forma: mapa sigue siendo mapa', () {
      final salida = Redactor.cuerpo({'diagnostico': 'x', 'idCita': 1});
      expect(salida, isA<Map<dynamic, dynamic>>());
      expect((salida! as Map)['idCita'], 1);
    });
  });

  group('cabeceras', () {
    test('Authorization se redacta', () {
      final limpias = Redactor.cabeceras({
        'Authorization': 'Bearer eyJhbGciOiJIUzI1NiJ9.abc',
        'Content-Type': 'application/json',
      });

      expect(limpias['Authorization'], Redactor.marca);
      // Lo que no es secreto se conserva: sirve para depurar.
      expect(limpias['Content-Type'], 'application/json');
    });

    test('sin importar cómo venga escrita', () {
      expect(
        Redactor.cabeceras({'authorization': 'Bearer x'})['authorization'],
        Redactor.marca,
      );
      expect(
        Redactor.cabeceras({'AUTHORIZATION': 'Bearer x'})['AUTHORIZATION'],
        Redactor.marca,
      );
    });

    test('las cookies también', () {
      expect(
        Redactor.cabeceras({'Cookie': 'sid=abc'})['Cookie'],
        Redactor.marca,
      );
    });
  });

  group('cobertura de la lista', () {
    test(
      'todo campo del contrato está clasificado, o redactado o permitido',
      () {
        // La primera versión de esta prueba era una lista escrita a mano con
        // once nombres sacados de §8. Eso solo detecta que alguien *quite* un
        // campo de `camposSensibles`; no detecta que el backend *agregue* uno,
        // porque para eso hacía falta acordarse de editar la copia — el mismo
        // olvido que la prueba decía prevenir. Y como solo miraba §8, dejó
        // pasar `direccion`, `fechaNacimiento` y `sexo` de §6.
        //
        // Ahora la fuente es `docs/openapi.json`, que se extrae del backend. Un
        // campo nuevo en el spec cae acá con su nombre hasta que alguien decida
        // explícitamente si se redacta o se permite.
        final spec =
            jsonDecode(File('docs/openapi.json').readAsStringSync())
                as Map<String, dynamic>;
        final esquemas =
            (spec['components'] as Map<String, dynamic>)['schemas']
                as Map<String, dynamic>;

        // Lista blanca: identificadores, enumerados y metadatos. Nada de esto
        // dice quién es la persona ni qué tiene.
        const permitidos = {
          'idusuario', 'idpaciente', 'idmedico', 'idcita', 'idconsulta',
          'idreceta', 'iddisponibilidad', 'idespecialidad', 'idcentro',
          'tipousuario', 'estado', 'estadoverificacion', 'modalidad',
          'diasemana', 'duracionslotmin', 'activo', 'fechacreacion',
          'fecharegistro', 'ultimoacceso', 'fechahorainicio', 'fechahorafin',
          'horainicio', 'horafin', 'fecha', 'page', 'limit', 'total', 'data',
          'nombre', 'descripcion', 'urlicono', 'urlfoto', 'especialidades',
          'especialidadids', 'numexequatur', 'biografia', 'aniosexperiencia',
          'tarifaconsulta', 'duraciondias', 'message', 'statuscode', 'error',
          // Solo de `CentroMedicoResponseDto`: ubican una clínica, no a una
          // persona. `direccion` sí se redacta aunque el centro también la
          // use — el redactor mira la clave, no de qué esquema viene, y
          // perder la dirección de una clínica en el log es barato.
          'ciudad', 'latitud', 'longitud',
          // Nombres: los de médico son públicos (RF-13 los pinta en el
          // listado). Se dejan visibles a sabiendas; el resto de la ficha —
          // documento, nacimiento, dirección— sí se tapa, que es lo que impide
          // reidentificar al paciente.
          'nombres', 'apellidos',
        };

        final sinClasificar = <String>{};
        for (final esquema in esquemas.values) {
          final props =
              (esquema as Map<String, dynamic>)['properties']
                  as Map<String, dynamic>?;
          if (props == null) continue;
          for (final campo in props.keys) {
            final clave = campo.toLowerCase();
            if (Redactor.camposSensibles.contains(clave)) continue;
            if (permitidos.contains(clave)) continue;
            sinClasificar.add(campo);
          }
        }

        expect(
          sinClasificar,
          isEmpty,
          reason:
              'campos del contrato sin decisión: $sinClasificar. '
              'Agregarlos a Redactor.camposSensibles o a la lista blanca.',
        );
      },
    );

    test('la lista está toda en minúsculas', () {
      // `esSensible` normaliza antes de buscar; una entrada en camelCase
      // nunca coincidiría y sería un hueco silencioso.
      for (final campo in Redactor.camposSensibles) {
        expect(
          campo,
          campo.toLowerCase(),
          reason: '$campo no está normalizado',
        );
      }
    });
  });
}
