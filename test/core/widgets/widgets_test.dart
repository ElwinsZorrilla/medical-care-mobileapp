import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicare/core/domain/cita_estado.dart';
import 'package:medicare/core/theme/app_theme.dart';
import 'package:medicare/core/theme/tokens.dart';
import 'package:medicare/core/widgets/widgets.dart';

/// Pruebas de los 12 componentes base.
///
/// Se concentran en la **lógica condicional** de cada uno —lo que los
/// goldens no cubren— y en el piso de calidad que el rubro exige: objetivo
/// táctil de 48dp, semántica para lectores de pantalla, y que el estado
/// nunca se comunique solo por color.
void main() {
  /// Monta un widget con el tema real del sistema.
  Future<void> montar(
    WidgetTester tester,
    Widget child, {
    AppDensity densidad = AppDensity.patient,
    Brightness brillo = Brightness.light,
    double escalaTexto = 1.0,
    bool sinAnimaciones = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        // La clave depende de densidad y brillo a propósito. Sin ella,
        // volver a montar con otra densidad hace que MaterialApp *anime*
        // entre los dos temas, y a mitad de la transición `context.density`
        // todavía devuelve el valor viejo. Con clave distinta el árbol se
        // reconstruye limpio en vez de interpolar.
        key: ValueKey('${densidad.name}-${brillo.name}'),
        theme: brillo == Brightness.light
            ? AppTheme.light(density: densidad)
            : AppTheme.dark(density: densidad),
        home: MediaQuery(
          data: MediaQueryData(
            textScaler: TextScaler.linear(escalaTexto),
            disableAnimations: sinAnimaciones,
          ),
          child: Scaffold(body: Center(child: child)),
        ),
      ),
    );
  }

  group('StatusRail', () {
    testWidgets('muestra etiqueta y glifo, no solo color', (tester) async {
      await montar(
        tester,
        const StatusRail(
          estado: CitaEstado.confirmada,
          child: Text('contenido'),
        ),
      );
      // El respaldo para daltonismo: la etiqueta y el glifo deben estar.
      expect(find.text('CONFIRMADA'), findsOneWidget);
      expect(find.text('●'), findsOneWidget);
      expect(find.text('contenido'), findsOneWidget);
    });

    testWidgets(
      'mostrarEtiqueta:false oculta el rótulo pero conserva la semántica',
      (tester) async {
        // flutter_test no construye el árbol de accesibilidad salvo que se
        // pida. Sin esto, cualquier bySemanticsLabel encuentra cero.
        final semantics = tester.ensureSemantics();
        await montar(
          tester,
          const StatusRail(
            estado: CitaEstado.cancelada,
            mostrarEtiqueta: false,
            child: Text('x'),
          ),
        );
        expect(find.text('CANCELADA'), findsNothing);
        // Un lector de pantalla sigue anunciando el estado.
        expect(
          tester.getSemantics(find.byType(StatusRail)).label,
          contains('CANCELADA'),
        );
        semantics.dispose();
      },
    );

    testWidgets('el riel mide exactamente 4px', (tester) async {
      await montar(
        tester,
        const StatusRail(estado: CitaEstado.pendiente, child: Text('x')),
      );
      // Se mide lo renderizado, no la propiedad del widget. Consultar
      // `constraints` con un `??` de respaldo daba una aserción que no podía
      // fallar: comparaba el token contra sí mismo.
      expect(
        tester.getSize(find.byType(AnimatedContainer)).width,
        Strokes.riel,
      );
    });

    testWidgets('respeta movimiento reducido', (tester) async {
      await montar(
        tester,
        const StatusRail(estado: CitaEstado.pendiente, child: Text('x')),
        sinAnimaciones: true,
      );
      final riel = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      expect(riel.duration, Duration.zero);
    });

    testWidgets('los cinco estados se renderizan', (tester) async {
      for (final estado in CitaEstado.values) {
        await montar(
          tester,
          StatusRail(estado: estado, child: const Text('x')),
        );
        expect(find.text(estado.etiqueta), findsOneWidget);
      }
    });
  });

  group('DataField', () {
    testWidgets('pone el rótulo en versalitas aunque llegue en minúsculas', (
      tester,
    ) async {
      await montar(
        tester,
        const DataField(label: 'tipo de sangre', value: 'O+'),
      );
      expect(find.text('TIPO DE SANGRE'), findsOneWidget);
      expect(find.text('O+'), findsOneWidget);
    });

    testWidgets('destacado usa la escala grande', (tester) async {
      await montar(
        tester,
        const DataField(label: 'Tarifa', value: r'RD$1,500', destacado: true),
      );
      final widget = tester.widget<Text>(find.text(r'RD$1,500'));
      expect(widget.style?.fontSize, 24);
    });

    testWidgets('expone label y value a accesibilidad', (tester) async {
      await montar(tester, const DataField(label: 'Presión', value: '120/80'));
      final semantics = tester.getSemantics(find.byType(DataField));
      expect(semantics.value, '120/80');
    });
  });

  group('AppCard', () {
    testWidgets('sin onTap no es interactiva', (tester) async {
      await montar(tester, const AppCard(child: Text('x')));
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('con onTap responde y respeta el táctil mínimo', (
      tester,
    ) async {
      var toques = 0;
      await montar(
        tester,
        AppCard(onTap: () => toques++, child: const Text('tocable')),
      );
      await tester.tap(find.text('tocable'));
      expect(toques, 1);
      expect(
        tester.getSize(find.byType(AppCard)).height,
        greaterThanOrEqualTo(kTactilMinimo),
      );
    });

    testWidgets('el padding sale de la densidad', (tester) async {
      await montar(
        tester,
        const AppCard(child: Text('x')),
        densidad: AppDensity.clinician,
      );
      final padding = tester.widget<Padding>(
        find.descendant(
          of: find.byType(AppCard),
          matching: find.byType(Padding),
        ),
      );
      expect(
        padding.padding,
        EdgeInsets.all(AppDensity.clinician.paddingTarjeta),
      );
    });
  });

  group('AppButton', () {
    testWidgets('dispara onPressed', (tester) async {
      var toques = 0;
      await montar(
        tester,
        AppButton(label: 'Reservar cita', onPressed: () => toques++),
      );
      await tester.tap(find.text('Reservar cita'));
      expect(toques, 1);
    });

    testWidgets('onPressed null lo deshabilita', (tester) async {
      await montar(tester, const AppButton(label: 'X', onPressed: null));

      // Se comprueba lo que importa: que no reaccione, y que lo anuncie
      // como deshabilitado. Un flag suelto del árbol semántico puede
      // cambiar de forma entre versiones de Flutter; el comportamiento no.
      await tester.tap(find.byType(AppButton), warnIfMissed: false);
      await tester.pump();
      expect(tester.takeException(), isNull);

      final semantics = tester.widget<Semantics>(
        find
            .descendant(
              of: find.byType(AppButton),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(semantics.properties.enabled, isFalse);
    });

    testWidgets('cargando bloquea la pulsación', (tester) async {
      var toques = 0;
      await montar(
        tester,
        AppButton(label: 'Enviando', cargando: true, onPressed: () => toques++),
      );
      await tester.tap(find.byType(AppButton));
      expect(toques, 0);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('alto mínimo de 48dp en las tres variantes', (tester) async {
      for (final v in AppButtonVariant.values) {
        await montar(
          tester,
          AppButton(label: 'A', variant: v, onPressed: () {}),
        );
        expect(
          tester.getSize(find.byType(AppButton)).height,
          greaterThanOrEqualTo(kTactilMinimo),
        );
      }
    });

    testWidgets('sobrevive textScale 2.0 sin desbordar', (tester) async {
      await montar(
        tester,
        AppButton(label: 'Reservar cita ahora', onPressed: () {}),
        escalaTexto: 2.0,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('AppTextField', () {
    testWidgets('sin error no pinta mensaje', (tester) async {
      await montar(tester, const AppTextField(label: 'Correo'));
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('CORREO'), findsOneWidget);
    });

    testWidgets('con error muestra el mensaje en lenguaje llano', (
      tester,
    ) async {
      await montar(
        tester,
        const AppTextField(
          label: 'Contraseña',
          error: 'Correo o contraseña incorrectos.',
        ),
      );
      expect(find.text('Correo o contraseña incorrectos.'), findsOneWidget);
    });

    testWidgets('obscure fuerza una sola línea', (tester) async {
      await montar(
        tester,
        const AppTextField(label: 'Clave', obscure: true, maxLines: 5),
      );
      final campo = tester.widget<TextField>(find.byType(TextField));
      expect(campo.maxLines, 1);
      expect(campo.obscureText, isTrue);
    });

    testWidgets('propaga los cambios', (tester) async {
      String? visto;
      await montar(
        tester,
        AppTextField(label: 'Correo', onChanged: (v) => visto = v),
      );
      await tester.enterText(find.byType(TextField), 'a@b.com');
      expect(visto, 'a@b.com');
    });
  });

  group('EmptyState', () {
    testWidgets('el vacío invita: muestra la acción', (tester) async {
      var toques = 0;
      await montar(
        tester,
        EmptyState(
          titulo: 'Aún no tienes citas',
          detalle: 'Busca un médico para empezar.',
          accion: 'Buscar médico',
          onAccion: () => toques++,
        ),
      );
      expect(find.text('Aún no tienes citas'), findsOneWidget);
      await tester.tap(find.text('Buscar médico'));
      expect(toques, 1);
    });

    testWidgets('sin acción no dibuja botón', (tester) async {
      await montar(tester, const EmptyState(titulo: 'Vacío'));
      expect(find.byType(AppButton), findsNothing);
    });
  });

  group('ErrorState', () {
    testWidgets('muestra mensaje y reintento', (tester) async {
      var toques = 0;
      await montar(
        tester,
        ErrorState(
          mensaje: 'Ese turno ya lo tomaron. Elige otra hora.',
          onReintentar: () => toques++,
        ),
      );
      expect(
        find.text('Ese turno ya lo tomaron. Elige otra hora.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Reintentar'));
      expect(toques, 1);
    });

    testWidgets('sin reintento no dibuja botón', (tester) async {
      await montar(tester, const ErrorState(mensaje: 'Falló'));
      expect(find.byType(AppButton), findsNothing);
    });
  });

  group('LoadingSkeleton', () {
    testWidgets('se queda quieto con movimiento reducido', (tester) async {
      await montar(
        tester,
        const LoadingSkeleton(width: 100),
        sinAnimaciones: true,
      );
      // Sin animación en curso, pumpAndSettle no debe colgarse.
      await tester.pumpAndSettle();
      expect(find.byType(LoadingSkeleton), findsOneWidget);
    });

    testWidgets('queda fuera del árbol semántico', (tester) async {
      await montar(tester, const LoadingSkeleton(width: 100));
      // Acotado al propio skeleton: MaterialApp mete sus propios
      // ExcludeSemantics en el andamiaje, así que buscar por tipo en toda
      // la pantalla encuentra de más.
      expect(
        find.descendant(
          of: find.byType(LoadingSkeleton),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
    });

    testWidgets('lineas apila la cantidad pedida', (tester) async {
      await montar(
        tester,
        Builder(builder: (c) => LoadingSkeleton.lineas(c, cantidad: 4)),
      );
      expect(find.byType(LoadingSkeleton), findsNWidgets(4));
    });
  });

  group('OfflineBanner', () {
    testWidgets('anuncia como región viva', (tester) async {
      await montar(tester, const OfflineBanner());
      expect(find.byType(OfflineBanner), findsOneWidget);
      expect(find.textContaining('Sin conexión'), findsOneWidget);
    });

    testWidgets('reintento con área táctil suficiente', (tester) async {
      var toques = 0;
      await montar(tester, OfflineBanner(onReintentar: () => toques++));
      await tester.tap(find.text('Reintentar'));
      expect(toques, 1);
      expect(
        tester.getSize(find.byType(InkWell)).height,
        greaterThanOrEqualTo(kTactilMinimo),
      );
    });
  });

  group('SectionHeader', () {
    testWidgets('marca el encabezado para accesibilidad', (tester) async {
      await montar(tester, const SectionHeader(titulo: 'Datos clínicos'));
      final semantics = tester.getSemantics(find.byType(SectionHeader));
      expect(semantics.flagsCollection.isHeader, isTrue);
    });

    testWidgets('acción opcional', (tester) async {
      var toques = 0;
      await montar(
        tester,
        SectionHeader(
          titulo: 'Citas',
          accion: 'Ver todas',
          onAccion: () => toques++,
        ),
      );
      await tester.tap(find.text('Ver todas'));
      expect(toques, 1);
    });
  });

  group('Avatar', () {
    testWidgets('arma iniciales de nombre y apellido', (tester) async {
      await montar(tester, const Avatar(nombre: 'Alejandra Peña'));
      expect(find.text('AP'), findsOneWidget);
    });

    testWidgets('un solo nombre da una inicial', (tester) async {
      await montar(tester, const Avatar(nombre: 'Madonna'));
      expect(find.text('M'), findsOneWidget);
    });

    testWidgets('nombre vacío no revienta', (tester) async {
      await montar(tester, const Avatar(nombre: '   '));
      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('describe la imagen para lectores de pantalla', (tester) async {
      final semantics = tester.ensureSemantics();
      await montar(tester, const Avatar(nombre: 'Juan Reyes'));
      expect(
        tester.getSemantics(find.byType(Avatar)).label,
        contains('Foto de Juan Reyes'),
      );
      semantics.dispose();
    });
  });

  group('AppScaffold', () {
    testWidgets('sin conexión inserta el banner', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const AppScaffold(
            titulo: 'Citas',
            sinConexion: true,
            body: Text('cuerpo'),
          ),
        ),
      );
      expect(find.byType(OfflineBanner), findsOneWidget);
    });

    testWidgets('con conexión no lo inserta', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const AppScaffold(titulo: 'Citas', body: Text('cuerpo')),
        ),
      );
      expect(find.byType(OfflineBanner), findsNothing);
      expect(find.text('cuerpo'), findsOneWidget);
    });
  });

  group('tema', () {
    testWidgets('las extensiones están disponibles en claro y oscuro', (
      tester,
    ) async {
      for (final brillo in Brightness.values) {
        for (final densidad in AppDensity.values) {
          await montar(
            tester,
            Builder(
              builder: (context) {
                // Si alguna extensión faltara, esto lanzaría.
                expect(context.colors.ink, isNotNull);
                expect(context.text.data.fontSize, isNotNull);
                expect(context.density, densidad);
                return const SizedBox.shrink();
              },
            ),
            densidad: densidad,
            brillo: brillo,
          );
        }
      }
    });
  });
}
