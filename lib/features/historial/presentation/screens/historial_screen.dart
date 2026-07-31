import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/pagina.dart';
import '../../../../core/domain/tipo_usuario.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/time/app_time.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/consulta.dart';
import '../providers/historial_provider.dart';

/// Historial clínico — RF-27, RNF-06.
///
/// El paciente ve sus consultas; el médico, las que atendió. **No hay
/// parámetro de paciente**: la ruta la elige el rol de la sesión, así que no
/// existe forma de pedir el historial de otro ni por error de programación.
class HistorialScreen extends ConsumerStatefulWidget {
  const HistorialScreen({super.key});

  @override
  ConsumerState<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends ConsumerState<HistorialScreen> {
  final _scroll = ScrollController();
  static const _umbralPrecarga = 400.0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_alScrollear);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_alScrollear)
      ..dispose();
    super.dispose();
  }

  void _alScrollear() {
    if (!_scroll.hasClients) return;
    final faltante = _scroll.position.maxScrollExtent - _scroll.position.pixels;
    if (faltante < _umbralPrecarga) {
      ref.read(historialProvider.notifier).cargarMas();
    }
  }

  @override
  Widget build(BuildContext context) {
    final historial = ref.watch(historialProvider);
    final esMedico =
        ref.watch(sesionActualProvider).usuario?.tipo == TipoUsuario.medico;

    return AppScaffold(
      titulo: esMedico ? 'Consultas atendidas' : 'Mi historial',
      tituloCompacto: true,
      body: switch (historial) {
        AsyncLoading<Pagina<Consulta>>() => Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: LoadingSkeleton.lineas(context, cantidad: 8),
        ),
        AsyncError<Pagina<Consulta>>(:final error) => ErrorState(
          mensaje: error is Failure ? error.mensaje : 'Algo salió mal.',
          onReintentar: () => ref.invalidate(historialProvider),
        ),
        AsyncData<Pagina<Consulta>>(:final value) =>
          value.estaVacia
              ? EmptyState(
                  icono: Icons.folder_outlined,
                  titulo: esMedico
                      ? 'Aún no has registrado consultas'
                      : 'Tu historial está vacío',
                  detalle: esMedico
                      ? 'Cuando completes una cita, la consulta aparecerá acá.'
                      : 'Después de tu primera consulta verás acá el '
                            'diagnóstico y las recetas.',
                )
              : _Lista(pagina: value, scroll: _scroll),
      },
    );
  }
}

class _Lista extends StatelessWidget {
  const _Lista({required this.pagina, required this.scroll});

  final Pagina<Consulta> pagina;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    final density = context.density;

    return ListView.separated(
      controller: scroll,
      padding: const EdgeInsets.all(Space.lg),
      itemCount: pagina.items.length + (pagina.hayMas ? 1 : 0),
      separatorBuilder: (_, _) => SizedBox(height: density.separacionLista),
      itemBuilder: (context, i) {
        if (i >= pagina.items.length) {
          return const Padding(
            padding: EdgeInsets.all(Space.lg),
            child: Center(child: LoadingSkeleton(height: Space.xl)),
          );
        }
        return _TarjetaConsulta(consulta: pagina.items[i]);
      },
    );
  }
}

class _TarjetaConsulta extends StatelessWidget {
  const _TarjetaConsulta({required this.consulta});

  final Consulta consulta;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final density = context.density;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(AppTime.fechaLarga(consulta.registradaUtc), style: text.caption),
          SizedBox(height: density.separacionLista),

          // El diagnóstico es lo que el paciente vino a buscar.
          DataField(label: 'Diagnóstico', value: consulta.diagnostico),

          if (consulta.tratamiento != null &&
              consulta.tratamiento!.isNotEmpty) ...[
            SizedBox(height: density.paddingTarjeta),
            DataField(label: 'Tratamiento', value: consulta.tratamiento!),
          ],

          if (consulta.tieneVitales) ...[
            SizedBox(height: density.paddingTarjeta),
            const _Separador(),
            SizedBox(height: density.paddingTarjeta),
            _Vitales(signos: consulta.signosVitales!),
          ],

          if (consulta.tieneRecetas) ...[
            SizedBox(height: density.paddingTarjeta),
            const _Separador(),
            SizedBox(height: density.paddingTarjeta),
            _Recetas(recetas: consulta.recetas),
          ],

          if (consulta.observaciones != null &&
              consulta.observaciones!.isNotEmpty) ...[
            SizedBox(height: density.paddingTarjeta),
            DataField(label: 'Observaciones', value: consulta.observaciones!),
          ],
        ],
      ),
    );
  }
}

/// Signos vitales — el bloque que más justifica la monoespaciada.
///
/// `120/80`, `37.2 °C`, `78 lpm`: en columna y tabular se comparan de un
/// vistazo entre consultas, que es exactamente lo que un médico hace al
/// revisar un historial.
class _Vitales extends StatelessWidget {
  const _Vitales({required this.signos});

  final SignosVitales signos;

  @override
  Widget build(BuildContext context) {
    final pares = signos.paraMostrar;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('SIGNOS VITALES', style: context.text.label),
        SizedBox(height: context.density.separacionLista),
        Wrap(
          spacing: Space.xl,
          runSpacing: Space.md,
          children: [
            for (final p in pares) DataField(label: p.etiqueta, value: p.valor),
          ],
        ),
      ],
    );
  }
}

/// Recetas — RF-26.
class _Recetas extends StatelessWidget {
  const _Recetas({required this.recetas});

  final List<Receta> recetas;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final density = context.density;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('RECETA', style: text.label),
        SizedBox(height: density.separacionLista),
        for (final r in recetas) ...[
          // Medicamento y pauta en mono: es el bloque del recetario.
          Text(r.medicamento, style: text.data),
          Text(r.pauta, style: text.caption),
          if (r.indicaciones != null && r.indicaciones!.isNotEmpty)
            Text(r.indicaciones!, style: text.caption),
          if (r != recetas.last) SizedBox(height: density.separacionLista),
        ],
      ],
    );
  }
}

class _Separador extends StatelessWidget {
  const _Separador();

  @override
  Widget build(BuildContext context) =>
      Divider(height: Strokes.filete, color: context.colors.filete);
}
