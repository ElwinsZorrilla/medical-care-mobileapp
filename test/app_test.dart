import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicare/app.dart';

void main() {
  testWidgets('la app arranca y monta el router sin excepciones', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: MedicareApp()));
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el locale queda en es-DO: el formato clinico depende de eso', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: MedicareApp()));
    await tester.pumpAndSettle();

    final MaterialApp app = tester.widget<MaterialApp>(
      find.byType(MaterialApp),
    );
    expect(app.locale, const Locale('es', 'DO'));
  });
}
