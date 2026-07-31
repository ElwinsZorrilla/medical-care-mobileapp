/// Configuración que entra por `--dart-define`.
///
/// Nada de esto vive en el código (R6 / RNF-04): un valor quemado acá termina
/// en el APK que se publica, y cambiarlo obliga a recompilar.
///
/// ```
/// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api
/// ```
library;

import 'package:flutter/foundation.dart';

/// Falta una variable de entorno obligatoria.
///
/// Se lanza al arrancar, a propósito. La alternativa —descubrirlo en la
/// primera petición— convierte un error de configuración en un error de red
/// intermitente, que es mucho más caro de diagnosticar.
final class ConfiguracionInvalida implements Exception {
  const ConfiguracionInvalida(this.variable, this.detalle);

  final String variable;
  final String detalle;

  @override
  String toString() =>
      'ConfiguracionInvalida: falta --dart-define=$variable. $detalle';
}

/// Variables de entorno de la app.
final class Env {
  const Env._();

  /// Base de la API, **incluyendo** el prefijo `/api`.
  ///
  /// El backend monta todo bajo `/api` ([`main.ts`] usa `setGlobalPrefix`),
  /// pero Swagger queda fuera, en `/docs`. Verificado en F00.
  ///
  /// En emulador Android `localhost` es el propio emulador: hay que usar
  /// `10.0.2.2` para llegar a la máquina anfitriona.
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Valida que todo lo obligatorio esté presente y bien formado.
  ///
  /// Se llama desde `main()` antes de `runApp`.
  static void validar() => validarBaseUrl(apiBaseUrl);

  /// La validación, separada del valor.
  ///
  /// [apiBaseUrl] es una constante de compilación: dentro de una prueba vale
  /// lo que se le haya pasado a `--dart-define` al correr `flutter test`, que
  /// no es algo sobre lo que una prueba deba depender. Con el valor como
  /// parámetro, las reglas se prueban de verdad.
  @visibleForTesting
  static void validarBaseUrl(String valor) {
    if (valor.isEmpty) {
      throw const ConfiguracionInvalida(
        'API_BASE_URL',
        'Ej: --dart-define=API_BASE_URL=http://10.0.2.2:3000/api',
      );
    }

    final Uri? uri = Uri.tryParse(valor);
    if (uri == null || !uri.isAbsolute) {
      throw const ConfiguracionInvalida(
        'API_BASE_URL',
        'Tiene que ser una URL absoluta, con esquema. Ej: http://host:3000/api',
      );
    }

    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw ConfiguracionInvalida(
        'API_BASE_URL',
        'Esquema no soportado: "${uri.scheme}". Solo http o https.',
      );
    }
  }
}

// ── SOCKET_URL: ausente a propósito ──────────────────────────────────────
//
// El diseño original la daba por hecha, pero F00 verificó que el backend no
// expone WebSocket ni Socket.IO: el módulo de chat son dos entidades sin
// controller. Declarar la variable —y peor, validarla al arrancar— haría
// fallar el arranque por una capacidad que no existe.
//
// Se agrega cuando exista el transporte. Ver docs/BACKEND_ISSUES.md #5.
