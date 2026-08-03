import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/domain/medico.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/widgets.dart';
import '../providers/busqueda_provider.dart';

/// Buscar médico — RF-12, RF-13, RF-14, RF-15.
class BusquedaScreen extends ConsumerStatefulWidget {
  const BusquedaScreen({super.key});

  @override
  ConsumerState<BusquedaScreen> createState() => _BusquedaScreenState();
}

class _BusquedaScreenState extends ConsumerState<BusquedaScreen> {
  final _scroll = ScrollController();

  /// A cuántos píxeles del final se pide la página siguiente.
  ///
  /// Con datos móviles lentos, esperar a tocar el fondo deja al usuario
  /// mirando un spinner. Adelantarse una pantalla hace que la carga ocurra
  /// mientras todavía está leyendo.
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
      // El provider ignora las llamadas repetidas mientras carga.
      ref.read(listadoMedicosProvider.notifier).cargarMas();
    }
  }

  @override
  Widget build(BuildContext context) {
    final listado = ref.watch(listadoMedicosProvider);

    return AppScaffold(
      titulo: 'Buscar médico',
      body: Column(
        children: [
          const _FiltroEspecialidades(),
          Expanded(
            child: switch (listado) {
              AsyncLoading<ListadoState>() => Padding(
                padding: const EdgeInsets.all(Space.lg),
                child: LoadingSkeleton.lineas(context, cantidad: 8),
              ),
              AsyncError<ListadoState>(:final error) => ErrorState(
                mensaje: error is Failure ? error.mensaje : 'Algo salió mal.',
                onReintentar: () => ref.invalidate(listadoMedicosProvider),
              ),
              AsyncData<ListadoState>(:final value) =>
                value.pagina.estaVacia
                    ? const EmptyState(
                        icono: Icons.search_off,
                        titulo: 'No hay médicos en esta especialidad',
                        detalle: 'Prueba con otra o quita el filtro.',
                      )
                    : _ListaMedicos(estado: value, scroll: _scroll),
            },
          ),
        ],
      ),
    );
  }
}

/// RF-12, RF-14 — catálogo como filtro.
class _FiltroEspecialidades extends ConsumerWidget {
  const _FiltroEspecialidades();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogo = ref.watch(catalogoEspecialidadesProvider);
    final seleccionada = ref.watch(filtroEspecialidadProvider);

    return switch (catalogo) {
      AsyncLoading<List<dynamic>>() => const SizedBox(
        height: Space.huge,
        child: Padding(
          padding: EdgeInsets.all(Space.lg),
          child: LoadingSkeleton(),
        ),
      ),
      // Si el catálogo falla, la búsqueda sin filtro sigue funcionando: no se
      // tumba la pantalla entera. Pero tampoco puede desaparecer en silencio:
      // el provider es `keepAlive`, así que sin una salida el filtro quedaría
      // muerto por el resto de la sesión, y ni el "Reintentar" de la lista lo
      // recupera porque invalida otro provider.
      AsyncError<List<dynamic>>() => Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.lg,
          vertical: Space.sm,
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: AppButton(
            label: 'Cargar especialidades',
            variant: AppButtonVariant.secundaria,
            expandido: false,
            onPressed: () => ref.invalidate(catalogoEspecialidadesProvider),
          ),
        ),
      ),
      AsyncData(:final value) => SizedBox(
        height: Space.huge + Space.md,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: Space.lg),
          itemCount: value.length + 1,
          separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
          itemBuilder: (context, i) {
            if (i == 0) {
              return _Chip(
                etiqueta: 'Todas',
                activo: seleccionada == null,
                onTap: () => ref
                    .read(filtroEspecialidadProvider.notifier)
                    .seleccionar(null),
              );
            }
            final e = value[i - 1];
            return _Chip(
              etiqueta: e.nombre,
              activo: seleccionada == e.id,
              onTap: () => ref
                  .read(filtroEspecialidadProvider.notifier)
                  .seleccionar(e.id),
            );
          },
        ),
      ),
    };
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.etiqueta,
    required this.activo,
    required this.onTap,
  });

  final String etiqueta;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;

    return Semantics(
      button: true,
      selected: activo,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.chip,
        child: Container(
          alignment: Alignment.center,
          constraints: const BoxConstraints(minHeight: kTactilMinimo),
          padding: const EdgeInsets.symmetric(horizontal: Space.lg),
          decoration: BoxDecoration(
            color: activo ? colors.verde : colors.surface,
            borderRadius: Radii.chip,
            border: Border.all(
              color: activo ? colors.verde : colors.filete,
              width: Strokes.filete,
            ),
          ),
          child: Text(
            etiqueta,
            style: text.bodyStrong.copyWith(
              color: activo ? colors.surface : colors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _ListaMedicos extends ConsumerWidget {
  const _ListaMedicos({required this.estado, required this.scroll});

  final ListadoState estado;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final density = context.density;
    final pagina = estado.pagina;
    // Pie: o el indicador de la pagina siguiente, o el error de esa pagina.
    final hayPie = pagina.hayMas || estado.errorAlPaginar != null;

    return ListView.separated(
      controller: scroll,
      padding: const EdgeInsets.all(Space.lg),
      itemCount: pagina.items.length + (hayPie ? 1 : 0),
      separatorBuilder: (_, _) => SizedBox(height: density.separacionLista),
      itemBuilder: (context, i) {
        if (i >= pagina.items.length) {
          final error = estado.errorAlPaginar;
          if (error != null) {
            // La lista de arriba sigue intacta: falló la pagina siguiente,
            // no lo que el usuario ya estaba leyendo.
            return Padding(
              padding: const EdgeInsets.all(Space.lg),
              child: Column(
                children: [
                  Text(error.mensaje, style: context.text.caption),
                  const SizedBox(height: Space.md),
                  AppButton(
                    label: 'Cargar más',
                    variant: AppButtonVariant.secundaria,
                    expandido: false,
                    onPressed: () => ref
                        .read(listadoMedicosProvider.notifier)
                        .reintentarPagina(),
                  ),
                ],
              ),
            );
          }
          return const Padding(
            padding: EdgeInsets.all(Space.lg),
            child: Center(child: LoadingSkeleton(height: Space.xl)),
          );
        }
        return _TarjetaMedico(medico: pagina.items[i]);
      },
    );
  }
}

class _TarjetaMedico extends StatelessWidget {
  const _TarjetaMedico({required this.medico});

  final PerfilMedico medico;

  @override
  Widget build(BuildContext context) {
    final text = context.text;

    return AppCard(
      // RF-19: tocar al medico lleva a reservar con el. Estuvo vacio hasta
      // F15, asi que la busqueda no llevaba a ninguna parte.
      onTap: () => context.push(Rutas.reservaCon(medico.idMedico)),
      child: Row(
        children: [
          Avatar(nombre: medico.nombreCompleto),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(medico.nombreCompleto, style: text.heading),
                const SizedBox(height: Space.xs),
                // RF-13 — la relación médico ↔ especialidad, visible.
                Text(
                  medico.especialidadesTexto,
                  style: text.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (medico.tarifaConsulta != null) ...[
            const SizedBox(width: Space.md),
            Text(
              r'RD$' + medico.tarifaConsulta!.toStringAsFixed(0),
              style: text.data,
            ),
          ],
          // RF-31: escribirle sin reservar. Va a una ruta y no al provider de
          // `chat` porque un feature no importa de otro (rubro 3.3); la
          // pantalla detrás resuelve el hilo.
          IconButton(
            onPressed: () => context.push(Rutas.abrirChatCon(medico.idMedico)),
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: 'Escribir a ${medico.nombreCompleto}',
          ),
        ],
      ),
    );
  }
}
