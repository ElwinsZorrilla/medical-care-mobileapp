import 'package:url_launcher/url_launcher.dart';

/// Abre la sala fuera de la app — RF-35, RF-36.
///
/// Es una interfaz y no una llamada directa a `url_launcher` para que las
/// pruebas puedan comprobar **que se abrio la URL correcta** sin depender del
/// canal de plataforma, que en un `flutter test` no existe.
abstract interface class LanzadorSala {
  /// `true` si el sistema pudo abrirla.
  Future<bool> abrir(String url);
}

class LanzadorSalaImpl implements LanzadorSala {
  const LanzadorSalaImpl();

  @override
  Future<bool> abrir(String url) async {
    final uri = Uri.tryParse(url);
    // Una URL que no se puede parsear no se le entrega al sistema: en Android
    // un intent malformado tumba la actividad en vez de fallar limpio.
    if (uri == null || !uri.hasScheme) return false;

    return launchUrl(
      uri,
      // `externalApplication`: la app de Jitsi si esta instalada, el navegador
      // si no. Un WebView empotrado no tendria resueltos los permisos de
      // camara y microfono, y dejaria la URL de la sala —que es un secreto—
      // viviendo dentro del proceso de la app.
      mode: LaunchMode.externalApplication,
    );
  }
}
