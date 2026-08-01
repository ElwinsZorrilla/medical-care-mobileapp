import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../storage/secure_store.dart';
import 'dio_client.dart';

part 'infra_provider.g.dart';

/// Infraestructura compartida: el cliente HTTP y el almacen cifrado.
///
/// Vivian en `features/auth/presentation/providers/` y **los seis features
/// los importaban desde ahi**: siete archivos violando la regla de que un
/// feature no importa de otro (rubro 3.3), detectado en F13 y arrastrado
/// desde F04.
///
/// Subirlos se aplazo porque `dioCliente` avisaba a `SesionActual` cuando el
/// refresh fallaba, y moverlo tal cual habria invertido la dependencia: `core`
/// pasaria a importar de `auth`. Se resuelve con una senal — ver
/// [SesionExpirada]— que `core` emite y `auth` escucha. Nadie cruza.

@Riverpod(keepAlive: true)
SecureStore secureStore(Ref ref) => SecureStoreImpl();

/// Aviso de que la sesion ya no se puede recuperar.
///
/// Es un contador y no un `bool` a proposito: dos expiraciones seguidas tienen
/// que notificar dos veces, y un `bool` que ya esta en `true` no vuelve a
/// disparar al oyente.
///
/// La emite el interceptor de refresh desde `core`; la escucha `SesionActual`
/// en `auth`. Esa direccion es la unica que respeta las capas: `core` no sabe
/// que existe una sesion, solo que algo caduco.
@Riverpod(keepAlive: true)
class SesionExpirada extends _$SesionExpirada {
  @override
  int build() => 0;

  void disparar() => state++;
}

@Riverpod(keepAlive: true)
Dio dioCliente(Ref ref) => DioClient.crear(
  store: ref.watch(secureStoreProvider),
  // Cuando el refresh falla no hay nada que recuperar. Sin este aviso el
  // usuario se queda en una pantalla que ya no puede cargar nada, viendo
  // errores en vez de la de login.
  onSesionExpirada: () async =>
      ref.read(sesionExpiradaProvider.notifier).disparar(),
);
