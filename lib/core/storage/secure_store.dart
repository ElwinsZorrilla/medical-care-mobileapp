import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Guarda los tokens de sesión cifrados en reposo — RNF-03.
///
/// **Nunca `SharedPreferences`.** En Android es un XML en claro dentro del
/// sandbox de la app: en un dispositivo con root, o con una copia de
/// seguridad mal configurada, el refresh token queda legible. Y en este
/// backend ese token vale **7 días completos y no se puede revocar**
/// (BACKEND_ISSUES.md #3), así que filtrarlo es peor que de costumbre.
///
/// `flutter_secure_storage` usa el Keystore de Android y el Keychain de iOS.
abstract interface class SecureStore {
  Future<String?> leerAccessToken();
  Future<String?> leerRefreshToken();
  Future<void> guardarTokens({
    required String accessToken,
    required String refreshToken,
  });

  /// Borra la sesión del dispositivo.
  ///
  /// Es todo lo que el logout puede hacer hoy: el backend no expone
  /// `/auth/logout` ni revoca refresh tokens.
  Future<void> limpiar();
}

class SecureStoreImpl implements SecureStore {
  SecureStoreImpl({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            // Sin `encryptedSharedPreferences`: quedo deprecado en v10 —
            // Google descontinuo Jetpack Security— y el paquete migra solo
            // a cifrado propio en el primer acceso. Pasarlo hoy no hace
            // nada salvo ensuciar el analyze.
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );

  static const _claveAccess = 'medicare.access_token';
  static const _claveRefresh = 'medicare.refresh_token';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> leerAccessToken() => _storage.read(key: _claveAccess);

  @override
  Future<String?> leerRefreshToken() => _storage.read(key: _claveRefresh);

  @override
  Future<void> guardarTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _claveAccess, value: accessToken);
    await _storage.write(key: _claveRefresh, value: refreshToken);
  }

  @override
  Future<void> limpiar() async {
    await _storage.delete(key: _claveAccess);
    await _storage.delete(key: _claveRefresh);
  }
}
