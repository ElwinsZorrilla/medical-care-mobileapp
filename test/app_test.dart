import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicare/app.dart';
import 'package:medicare/core/network/infra_provider.dart';
import 'package:medicare/core/network/politica_reintento.dart';
import 'package:medicare/core/storage/secure_store.dart';

/// Doble en memoria: `flutter_secure_storage` habla por canal nativo y en un
/// test de widget no hay plataforma que responda.
class _StoreVacio implements SecureStore {
  @override
  Future<String?> leerAccessToken() async => null;

  @override
  Future<String?> leerRefreshToken() async => null;

  @override
  Future<void> guardarTokens({
    required String accessToken,
    required String refreshToken,
  }) async {}

  @override
  Future<void> limpiar() async {}
}

void main() {
  Future<void> montarApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        // La misma politica que main.dart. Con el default de Riverpod un
        // fallo se queda en AsyncLoading ~38 s y el ErrorState no llega a
        // pintarse: la prueba verificaria algo que la app no hace.
        retry: PoliticaReintento.decidir,
        overrides: [secureStoreProvider.overrideWithValue(_StoreVacio())],
        child: const MedicareApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('la app arranca y monta el router sin excepciones', (
    WidgetTester tester,
  ) async {
    await montarApp(tester);

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el locale queda en es-DO: el formato clinico depende de eso', (
    WidgetTester tester,
  ) async {
    await montarApp(tester);

    final MaterialApp app = tester.widget<MaterialApp>(
      find.byType(MaterialApp),
    );
    expect(app.locale, const Locale('es', 'DO'));
  });

  testWidgets('sin sesión guardada, el guard lleva al login', (
    WidgetTester tester,
  ) async {
    // RF-06: el arranque resuelve la sesión y, al no haberla, redirige. Si
    // el estado inicial fuera "anónimo" en vez de "desconocido", esto
    // pasaría igual pero el usuario vería un parpadeo del login antes.
    await montarApp(tester);

    expect(find.text('Entrar'), findsWidgets);
  });
}
