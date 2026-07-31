import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicare/core/domain/cita_estado.dart';
import 'package:medicare/core/domain/medico.dart';
import 'package:medicare/core/theme/app_theme.dart';
import 'package:medicare/core/theme/tokens.dart';
import 'package:medicare/core/widgets/widgets.dart';
import 'package:medicare/features/perfil/presentation/widgets/badge_verificacion.dart';

/// Piso de accesibilidad — RNF-14, rubro 3.4.
///
/// Dos reglas del design system que no se anuncian pero se verifican:
///
/// - **Escala de texto hasta 200% sin romper layout ni recortar.** Un usuario
///   con baja visión sube el tamaño en el sistema; si el botón de reservar se
///   sale de la pantalla, la app deja de servirle. Es el caso que no aparece
///   probando a mano en un monitor grande.
/// - **Objetivo táctil mínimo 48×48dp.** Debajo de eso, un dedo falla; en un
///   Android de gama media con la pantalla rayada, falla más.
void main() {
  /// Monta y devuelve la excepción de layout, si la hubo.
  ///
  /// Flutter reporta un desborde como excepción durante el frame, así que
  /// `takeException` es la forma directa de detectarlo.
  ///
  /// **Sin `SingleChildScrollView`.** La primera versión envolvía todo en uno,
  /// que le pasa al hijo `maxHeight: infinity`: con altura infinita un
  /// `RenderFlex` *no puede* desbordar en vertical, así que las diez pruebas
  /// afirmaban sobre una señal que nunca podía dispararse. Se monta contra la
  /// altura real del viewport, que es la restricción que tiene el usuario.
  ///
  /// [scroll] lo reactiva para los widgets que en la app sí viven dentro de
  /// una lista y para los que desbordar es correcto.
  Future<Object?> montar(
    WidgetTester tester,
    Widget child, {
    double escala = 2.0,
    AppDensity densidad = AppDensity.patient,
    Size tamano = const Size(360, 640),
    bool scroll = false,
  }) async {
    tester.view
      ..physicalSize = tamano
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(density: densidad),
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(escala)),
          child: Scaffold(
            body: scroll ? SingleChildScrollView(child: child) : child,
          ),
        ),
      ),
    );
    await tester.pump();
    return tester.takeException();
  }

  /// Si el texto se repartió en más de una línea.
  ///
  /// El recorte no lanza excepción: `TextOverflow.ellipsis` y el clip duro son
  /// silenciosos. Para afirmar que un mensaje **no** se corta hay que mirar la
  /// geometría, no `takeException`. Con ancho infinito la altura intrínseca es
  /// la de una sola línea; si la altura real la supera, envolvió.
  bool envuelve(WidgetTester tester, Finder texto) {
    final render = tester.renderObject<RenderParagraph>(texto);
    return render.size.height > render.getMinIntrinsicHeight(double.infinity);
  }

  group('escala de texto 200%', () {
    testWidgets('el botón no desborda con una etiqueta larga', (tester) async {
      final excepcion = await montar(
        tester,
        AppButton(label: 'Reservar cita con la doctora', onPressed: () {}),
      );
      expect(excepcion, isNull);
    });

    testWidgets('el riel de estado aguanta contenido largo', (tester) async {
      final excepcion = await montar(
        tester,
        const StatusRail(
          estado: CitaEstado.pendiente,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Dra. Alejandra Peña Rodríguez de los Santos'),
              SizedBox(height: Space.xs),
              Text('Cardiología · Medicina Interna · Presencial'),
              SizedBox(height: Space.md),
              Row(
                children: [
                  Expanded(
                    child: DataField(label: 'Fecha', value: '04 AGO'),
                  ),
                  Expanded(
                    child: DataField(label: 'Hora', value: '08:30'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      expect(excepcion, isNull);
    });

    testWidgets('el campo con error no recorta el mensaje', (tester) async {
      const mensaje =
          'Usa al menos 8 caracteres, con una mayúscula y un número.';
      final excepcion = await montar(
        tester,
        const AppTextField(label: 'Contraseña', error: mensaje),
      );

      expect(excepcion, isNull);
      // Que no desborde no basta: un `maxLines: 1` con elipsis tampoco
      // desborda y deja al usuario sin saber qué le falta a la contraseña.
      // A 200% ese mensaje necesita varias líneas; si cabe en una, se cortó.
      final render = tester.renderObject<RenderParagraph>(find.text(mensaje));
      expect(render.didExceedMaxLines, isFalse);
      expect(envuelve(tester, find.text(mensaje)), isTrue);
    });

    testWidgets('el rótulo largo de DataField envuelve, no se corta', (
      tester,
    ) async {
      const rotulo = 'Presión arterial sistólica';
      final excepcion = await montar(
        tester,
        const SizedBox(
          width: 120,
          child: DataField(label: rotulo, value: '120/80'),
        ),
      );

      expect(excepcion, isNull);
      // El widget pinta el rótulo en versalitas, así que el texto renderizado
      // está en mayúsculas.
      final pintado = find.text(rotulo.toUpperCase());
      expect(pintado, findsOneWidget);
      final render = tester.renderObject<RenderParagraph>(pintado);
      expect(render.didExceedMaxLines, isFalse);
      expect(envuelve(tester, pintado), isTrue);
    });

    testWidgets('el badge de verificación con su explicación', (tester) async {
      for (final estado in EstadoVerificacion.values) {
        final excepcion = await montar(
          tester,
          BadgeVerificacion(estado: estado),
        );
        expect(excepcion, isNull, reason: estado.name);
      }
    });

    testWidgets('el estado vacío con acción', (tester) async {
      final excepcion = await montar(
        tester,
        SizedBox(
          height: 400,
          child: EmptyState(
            icono: Icons.event_note,
            titulo: 'Aún no tienes citas agendadas',
            detalle: 'Busca un médico por especialidad para empezar.',
            accion: 'Buscar médico',
            onAccion: () {},
          ),
        ),
      );
      expect(excepcion, isNull);
    });

    testWidgets('el banner de sin conexión con botón', (tester) async {
      final excepcion = await montar(
        tester,
        OfflineBanner(onReintentar: () {}),
      );
      expect(excepcion, isNull);
    });

    testWidgets('el encabezado de sección con acción', (tester) async {
      final excepcion = await montar(
        tester,
        SectionHeader(
          titulo: 'Consultas atendidas este mes',
          accion: 'Ver todas',
          onAccion: () {},
        ),
      );
      expect(excepcion, isNull);
    });

    testWidgets('en densidad clínica también', (tester) async {
      // La densidad del médico aprieta el espaciado: es donde el texto
      // ampliado tiene menos margen antes de desbordar.
      final excepcion = await montar(
        tester,
        const StatusRail(
          estado: CitaEstado.completada,
          child: Text('Dra. Alejandra Peña · Cardiología · Presencial'),
        ),
        densidad: AppDensity.clinician,
      );
      expect(excepcion, isNull);
    });

    testWidgets('en una pantalla angosta de gama baja', (tester) async {
      // 320dp de ancho es un Android chico todavía en uso.
      final excepcion = await montar(
        tester,
        AppButton(label: 'Confirmar reserva', onPressed: () {}),
        tamano: const Size(320, 560),
      );
      expect(excepcion, isNull);
    });
  });

  group('objetivo táctil de 48dp', () {
    Future<Size> medir(WidgetTester tester, Widget child, Type tipo) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: Center(child: child)),
        ),
      );
      await tester.pump();
      return tester.getSize(find.byType(tipo).first);
    }

    testWidgets('el botón en sus tres variantes', (tester) async {
      for (final v in AppButtonVariant.values) {
        final size = await medir(
          tester,
          AppButton(label: 'A', variant: v, onPressed: () {}),
          AppButton,
        );
        expect(
          size.height,
          greaterThanOrEqualTo(kTactilMinimo),
          reason: v.name,
        );
      }
    });

    testWidgets('el campo de texto', (tester) async {
      final size = await medir(
        tester,
        const AppTextField(label: 'Correo'),
        TextField,
      );
      expect(size.height, greaterThanOrEqualTo(kTactilMinimo));
    });

    testWidgets('la tarjeta interactiva', (tester) async {
      final size = await medir(
        tester,
        AppCard(onTap: () {}, child: const Text('x')),
        AppCard,
      );
      expect(size.height, greaterThanOrEqualTo(kTactilMinimo));
    });
  });

  group('el estado nunca se comunica solo por color', () {
    test('los cinco estados de cita tienen glifo distinto', () {
      final glifos = CitaEstado.values.map((e) => e.glifo).toSet();
      expect(glifos.length, CitaEstado.values.length);
    });

    test('los tres de verificación también', () {
      final glifos = EstadoVerificacion.values.map((e) => e.glifo).toSet();
      expect(glifos.length, EstadoVerificacion.values.length);
    });

    test('y todos llevan etiqueta en palabras', () {
      for (final e in CitaEstado.values) {
        expect(e.etiqueta, isNotEmpty);
      }
      for (final e in EstadoVerificacion.values) {
        expect(e.etiqueta, isNotEmpty);
      }
    });
  });

  group('semántica para lectores de pantalla', () {
    testWidgets('el riel anuncia el estado de la cita', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: StatusRail(estado: CitaEstado.cancelada, child: Text('x')),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byType(StatusRail)).label,
        contains('CANCELADA'),
      );
      handle.dispose();
    });

    testWidgets('el badge anuncia estado y explicación', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: BadgeVerificacion(estado: EstadoVerificacion.rechazado),
          ),
        ),
      );

      final label = tester.getSemantics(find.byType(BadgeVerificacion)).label;
      expect(label, contains('RECHAZADO'));
      // No basta con el estado: el lector también dice qué implica.
      expect(label, contains('soporte'));
      handle.dispose();
    });

    testWidgets('el skeleton de carga no ensucia el árbol semántico', (
      tester,
    ) async {
      // Un lector de pantalla leyendo ocho bloques vacíos es ruido.
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: LoadingSkeleton(width: 100)),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(LoadingSkeleton),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
    });
  });
}
