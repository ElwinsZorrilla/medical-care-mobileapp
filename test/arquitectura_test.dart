import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Las reglas de capas del rubro 3.3, ejecutables.
///
/// `docs/ARCHITECTURE.md` dice que la regla "feature A → feature B" está
/// "verificada en el gate". No lo estaba: seis revisiones la dieron por buena
/// mientras siete archivos la violaban. Una regla que solo vive en Markdown no
/// es una regla, es una intención — el mismo argumento por el que la
/// prohibición de `SharedPreferences` pasó de comentario a prueba.
///
/// Solo recorre `lib/`. Los tests **sí** pueden importar de varios features:
/// nada en `lib/` depende de `test/`, así que no crean acoplamiento, y un test
/// de contrato existe justamente para mirar varios módulos a la vez y
/// comprobar que hablan el mismo protocolo. Partir
/// `test/contrato_api_test.dart` en seis para cumplir la letra de la regla
/// eliminaría lo único que lo hace útil.
void main() {
  /// Se derivan del disco y no de una lista a mano.
  ///
  /// La lista escrita quedo desactualizada al crear `notificaciones`: la
  /// guarda dejo de ver cualquier import hacia el modulo nuevo y volvio a
  /// vivir solo en Markdown para el, que es justo lo que denuncia el docstring
  /// de este archivo.
  final features = Directory('lib/features')
      .listSync()
      .whereType<Directory>()
      // Separador de Windows y de POSIX: `listSync` devuelve `lib/features\x`
      // en Windows, y partir solo por `/` dejaba nombres como `features\auth`.
      // Con eso la guarda dejaba de reconocer cualquier feature y pasaba en
      // verde sin comprobar nada — lo atrapo su propia asercion de que el
      // registro de deuda solo puede encoger.
      .map((d) => d.path.split(RegExp(r'[/\\]')).last)
      .toSet();

  /// Violaciones que ya existían cuando se escribió esta guarda.
  ///
  /// Todas son el mismo problema: `dioClienteProvider`, `secureStoreProvider`
  /// y `sesionActualProvider` viven en `features/auth/presentation/`, y los
  /// otros cinco features los necesitan para construir su repositorio.
  ///
  /// **No se arreglaron acá a propósito.** Mover los dos primeros a `core/` es
  /// mecánico, pero `dioCliente` llama a `sesionActual.expirar()` cuando el
  /// refresh falla, así que subirlo invierte la dependencia: `core` pasaría a
  /// depender de `auth`. Resolverlo bien pide decidir dónde vive la sesión y
  /// probablemente una interfaz en `core` que `auth` implemente. Es un
  /// rediseño con decisiones propias, no un movimiento de archivos, y meterlo
  /// en el commit de endurecimiento lo volvería irrevisable.
  ///
  /// El registro solo puede encoger: una entrada que ya no corresponde también
  /// falla, así que no se puede dejar podrido.
  const deudaConocida = {
    'lib/features/historial/presentation/providers/historial_provider.dart',
    'lib/features/historial/presentation/screens/historial_screen.dart',
    'lib/features/perfil/presentation/screens/perfil_screen.dart',
  };

  /// Archivos de `lib/`, con su ruta normalizada a barras.
  List<({String ruta, List<String> lineas})> fuentes() {
    final lib = Directory('lib');
    expect(
      lib.existsSync(),
      isTrue,
      reason:
          'corre desde la raíz del paquete; cwd = ${Directory.current.path}',
    );

    final archivos = <({String ruta, List<String> lineas})>[];
    for (final e in lib.listSync(recursive: true)) {
      if (e is! File || !e.path.endsWith('.dart')) continue;
      archivos.add((
        ruta: e.path.replaceAll(r'\', '/'),
        lineas: e.readAsLinesSync(),
      ));
    }
    expect(archivos.length, greaterThan(30), reason: 'no recorrió lib/');
    return archivos;
  }

  /// El feature al que pertenece una ruta, o `null` si es `core`.
  String? featureDe(String ruta) {
    final m = RegExp(r'^lib/features/([^/]+)/').firstMatch(ruta);
    return m?.group(1);
  }

  group('rubro 3.3 — sin dependencias entre features', () {
    test('ningún feature importa de otro', () {
      final ofensores = <String, Set<String>>{};

      for (final f in fuentes()) {
        final propio = featureDe(f.ruta);
        if (propio == null) continue;

        for (final linea in f.lineas) {
          if (!linea.trimLeft().startsWith('import ')) continue;
          // Relativo (`../../../auth/...`) o por paquete.
          for (final otro in features) {
            if (otro == propio) continue;
            final cruzado =
                RegExp('/$otro/').hasMatch(linea) ||
                linea.contains('package:medicare/features/$otro/');
            if (cruzado) {
              (ofensores[f.ruta] ??= {}).add(otro);
            }
          }
        }
      }

      final nuevos = ofensores.keys.toSet().difference(deudaConocida);
      expect(
        nuevos,
        isEmpty,
        reason:
            'Import entre features. Lo compartido sube a core/. Nuevos: '
            '${nuevos.map((r) => '$r → ${ofensores[r]}').join(', ')}',
      );

      // El registro tiene que encoger. Si una entrada ya no viola nada,
      // sacarla — si no, la próxima violación real se esconde detrás de ella.
      final resueltos = deudaConocida.difference(ofensores.keys.toSet());
      expect(
        resueltos,
        isEmpty,
        reason:
            'Ya no violan la regla; quitarlos de `deudaConocida`: $resueltos',
      );
    });
  });

  group('rubro 3.3 — la presentación no habla HTTP', () {
    test('ninguna pantalla ni widget importa dio', () {
      // Un `Response` o una `DioException` en un widget significa que la
      // traducción a `Failure` se saltó, y el usuario termina viendo un
      // mensaje de librería en inglés.
      final ofensores = <String>[];

      for (final f in fuentes()) {
        if (!f.ruta.contains('/presentation/screens/') &&
            !f.ruta.contains('/presentation/widgets/')) {
          continue;
        }
        for (var i = 0; i < f.lineas.length; i++) {
          if (f.lineas[i].contains('package:dio/')) {
            ofensores.add('${f.ruta}:${i + 1}');
          }
        }
      }

      expect(ofensores, isEmpty, reason: 'dio en presentación: $ofensores');
    });

    test('ningún widget nombra Response ni DioException', () {
      final ofensores = <String>[];

      for (final f in fuentes()) {
        if (!f.ruta.contains('/presentation/')) continue;
        for (var i = 0; i < f.lineas.length; i++) {
          final l = f.lineas[i];
          if (l.trimLeft().startsWith('//')) continue;
          if (RegExp(r'\bDioException\b|\bResponse<').hasMatch(l)) {
            ofensores.add('${f.ruta}:${i + 1}');
          }
        }
      }

      expect(
        ofensores,
        isEmpty,
        reason: 'la capa de datos traduce a Failure: $ofensores',
      );
    });
  });

  /// Rutas alcanzables — la leccion de F15, vuelta prueba.
  ///
  /// Auditar la matriz destapo seis requerimientos marcados como cubiertos que
  /// no tenian interfaz. Al arreglarlos aparecieron **tres mas**: dos rutas
  /// registradas a las que ninguna linea de `lib/` navegaba (RF-16/17 y RF-27),
  /// y media capa de repositorio que solo llamaban las pruebas.
  ///
  /// El patron se repitio siete revisiones seguidas porque nadie recorria el
  /// conjunto. Esto lo hace por nosotros: una pantalla sin puerta de entrada es
  /// codigo muerto con prueba de widget, que es la forma mas cara de codigo
  /// muerto — parece cubierto.
  group('rubro 3.6 — de toda ruta se puede volver', () {
    /// Rutas a las que `context.go` es correcto.
    ///
    /// `go` **reemplaza la pila entera**: despues de un `go` no hay nada que
    /// desapilar, no aparece la flecha de atras —`canPop` es falso— y el
    /// boton fisico de Android cierra la app. Solo es correcto cuando la
    /// intencion es justamente esa, que no haya vuelta:
    const cambiosDeCasa = {
      // Tras autenticarse. Volver al login desde aca seria un bug.
      'misCitas', 'agenda', 'deInicioPara',
      // Tras cerrar sesion o expirar. Volver a la sesion vieja no existe.
      'login',
      'splash',
    };

    test('nadie usa go() para un desvio del que hay que volver', () {
      // Reportado en uso real: "le doy back y se cierra la aplicacion
      // completa". El paciente entraba a su perfil desde el listado de citas
      // con `go`, la pila quedaba con una sola entrada, y atras cerraba la
      // app en vez de devolverlo a sus citas. Lo mismo con la busqueda.
      final malas = <String>[];

      for (final f in fuentes()) {
        for (var i = 0; i < f.lineas.length; i++) {
          final m = RegExp(
            r'context\.go\(\s*Rutas\.(\w+)',
          ).firstMatch(f.lineas[i]);
          if (m == null) continue;
          if (cambiosDeCasa.contains(m.group(1))) continue;
          malas.add('${f.ruta}:${i + 1} -> Rutas.${m.group(1)}');
        }
      }

      expect(
        malas,
        isEmpty,
        reason:
            'go() borra la pila y deja al usuario sin vuelta atras.\n'
            'Para un desvio —perfil, busqueda, un detalle— va push().\n'
            '$malas',
      );
    });
  });

  group('rubro 3.6 — toda ruta tiene por donde llegarse', () {
    /// Rutas que no necesitan un `go`/`push` explicito.
    const alcanzablesSinEnlace = {
      // La primera pantalla.
      'splash',
      // Destinos de `Rutas.deInicioPara` tras autenticarse.
      'misCitas', 'agenda',
      // El `redirect` manda aca cuando no hay sesion.
      'login',
      // Se llega desde login.
      'registro',
    };

    test('ninguna ruta queda sin origen de navegacion', () {
      final router = File('lib/core/router/app_router.dart').readAsStringSync();

      // Nombres declarados en `abstract final class Rutas`.
      final declaradas = RegExp(r'static (?:const String|String) (\w+)\s*[=(]')
          .allMatches(router)
          .map((m) => m.group(1)!)
          // `publicas` es un conjunto y `deInicioPara` una funcion de
          // ayuda: ninguno de los dos es una ruta que alcanzar.
          .where((n) => n != 'publicas' && n != 'deInicioPara')
          .toSet();
      expect(declaradas, isNotEmpty, reason: 'no se leyo la clase Rutas');

      // Cada uso de `Rutas.x` fuera del propio router es una puerta.
      final conPuerta = <String>{};
      for (final f in fuentes()) {
        if (f.ruta.endsWith('core/router/app_router.dart')) continue;
        for (final linea in f.lineas) {
          for (final m in RegExp(r'Rutas\.(\w+)').allMatches(linea)) {
            conPuerta.add(m.group(1)!);
          }
        }
      }

      // `reservaCon` es la puerta de `reserva`; `registroConsultaDe` la de
      // `registroConsulta`. Se normalizan los pares constructor/constante.
      const alias = {
        'reservaCon': 'reserva',
        'registroConsultaDe': 'registroConsulta',
        'chatCon': 'chat',
        'abrirChatCon': 'abrirChat',
        'salaDe': 'sala',
      };
      conPuerta.addAll(
        conPuerta.map((n) => alias[n]).whereType<String>().toList(),
      );

      final huerfanas = declaradas
          .where((n) => !alias.containsKey(n))
          .where((n) => !alcanzablesSinEnlace.contains(n))
          .where((n) => !conPuerta.contains(n))
          .toList();

      expect(
        huerfanas,
        isEmpty,
        reason:
            'Rutas registradas a las que nadie navega: $huerfanas. '
            'Una pantalla sin puerta de entrada esta muerta por mas pruebas '
            'de widget que tenga.',
      );
    });
  });
}
