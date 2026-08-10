import 'package:flutter_test/flutter_test.dart';
import 'package:medicare/core/domain/tipo_usuario.dart';
import 'package:medicare/core/router/app_router.dart';

/// Guard por rol — RF-06.
///
/// Se prueba la tabla de decisión del `redirect` sin levantar el router
/// entero: lo que puede romperse acá es la regla, no el cableado de
/// `go_router`.
void main() {
  group('destino según el rol', () {
    test('el médico entra a su agenda', () {
      expect(Rutas.deInicioPara(TipoUsuario.medico), Rutas.agenda);
    });

    test('el paciente entra a sus citas', () {
      expect(Rutas.deInicioPara(TipoUsuario.paciente), Rutas.misCitas);
    });

    test('el admin entra a la cola de verificación — RF-11', () {
      // Es la única función que el admin tiene en el alcance móvil: no hay
      // panel general, solo verificar/rechazar exequátures.
      expect(Rutas.deInicioPara(TipoUsuario.admin), Rutas.verificacion);
    });

    test('todo rol tiene destino: el switch es exhaustivo', () {
      for (final tipo in TipoUsuario.values) {
        expect(Rutas.deInicioPara(tipo), isNotEmpty);
      }
    });
  });

  group('rutas públicas', () {
    test('login y registro son las únicas sin sesión', () {
      expect(Rutas.publicas, {Rutas.login, Rutas.registro});
    });

    test('el splash NO es pública: es el estado "todavía no sé"', () {
      // Si el splash fuera pública, un usuario autenticado podría quedarse
      // ahí. El guard lo saca hacia su pantalla de inicio.
      expect(Rutas.publicas, isNot(contains(Rutas.splash)));
    });

    test('las áreas por rol no son públicas', () {
      expect(Rutas.publicas, isNot(contains(Rutas.agenda)));
      expect(Rutas.publicas, isNot(contains(Rutas.misCitas)));
      expect(Rutas.publicas, isNot(contains(Rutas.verificacion)));
    });
  });

  group('rutas declaradas', () {
    test('no hay dos rutas con el mismo path', () {
      final rutas = [
        Rutas.splash,
        Rutas.login,
        Rutas.registro,
        Rutas.misCitas,
        Rutas.agenda,
        Rutas.verificacion,
      ];
      expect(rutas.toSet().length, rutas.length);
    });

    test('todas empiezan con /', () {
      for (final r in [
        Rutas.splash,
        Rutas.login,
        Rutas.registro,
        Rutas.misCitas,
        Rutas.agenda,
        Rutas.verificacion,
      ]) {
        expect(r, startsWith('/'));
      }
    });
  });

  group('área del admin — RF-11', () {
    test('la cola de verificación cuelga del prefijo /admin', () {
      // El guard compara con `startsWith(Rutas.admin)`: si algún día se
      // agrega otra ruta de admin, entra sola sin tocar el guard.
      expect(Rutas.verificacion, startsWith(Rutas.admin));
    });
  });
}
