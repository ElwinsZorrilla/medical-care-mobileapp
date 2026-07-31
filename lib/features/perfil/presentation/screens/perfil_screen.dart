import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/domain/tipo_usuario.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/perfil.dart';
import '../providers/perfil_provider.dart';
import '../widgets/badge_verificacion.dart';

/// Perfil del usuario autenticado — RF-07, RF-08, RF-11.
///
/// Una sola pantalla que resuelve por rol. El id **nunca** sale de acá: los
/// endpoints `/patients/me` y `/doctors/me` lo toman del token (RF-09), así
/// que no hay forma de pedir el perfil de otro (RF-10).
class PerfilScreen extends ConsumerWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sesion = ref.watch(sesionActualProvider);
    final usuario = sesion.usuario;

    if (usuario == null) {
      return const AppScaffold(
        titulo: 'Perfil',
        body: LoadingSkeleton(height: Space.xxl),
      );
    }

    return AppScaffold(
      titulo: 'Mi perfil',
      acciones: [
        // RF-27: la puerta al historial clinico. Sin esto la pantalla existia
        // con sus 11 pruebas de widget y nadie podia abrirla.
        IconButton(
          onPressed: () => context.push(Rutas.historial),
          icon: const Icon(Icons.folder_outlined),
          tooltip: 'Mi historial',
        ),
        IconButton(
          onPressed: () =>
              ref.read(sesionActualProvider.notifier).cerrarSesion(),
          icon: const Icon(Icons.logout),
          tooltip: 'Cerrar sesión',
        ),
      ],
      body: switch (usuario.tipo) {
        TipoUsuario.medico => const _PerfilMedicoVista(),
        TipoUsuario.paciente ||
        TipoUsuario.admin => const _PerfilPacienteVista(),
      },
    );
  }
}

/// Envoltura con los cuatro estados que exige el rubro: cargando, vacío,
/// error y sin conexión.
class _Estados<T> extends StatelessWidget {
  const _Estados({
    required this.valor,
    required this.alRecargar,
    required this.vacio,
    required this.contenido,
  });

  final AsyncValue<T?> valor;
  final VoidCallback alRecargar;

  /// Qué mostrar cuando el perfil todavía no existe.
  final Widget vacio;
  final Widget Function(T dato) contenido;

  @override
  Widget build(BuildContext context) => switch (valor) {
    AsyncLoading<T?>() => Padding(
      padding: const EdgeInsets.all(Space.lg),
      child: LoadingSkeleton.lineas(context, cantidad: 6),
    ),
    AsyncError<T?>(:final error) => ErrorState(
      // `Failure` ya trae el mensaje redactado; cualquier otra cosa cae a un
      // texto genérico antes que mostrar un `toString()` de excepción.
      mensaje: error is Failure ? error.mensaje : 'Algo salió mal.',
      onReintentar: alRecargar,
    ),
    // `AsyncValue` solo tiene estos tres: agregar un `_` de respaldo haría
    // que el compilador dejara de avisar si mañana aparece un cuarto.
    AsyncData<T?>(:final value) => value == null ? vacio : contenido(value),
  };
}

class _PerfilPacienteVista extends ConsumerWidget {
  const _PerfilPacienteVista();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asincrono = ref.watch(miPerfilPacienteProvider);

    return _Estados<PerfilPaciente>(
      valor: asincrono,
      alRecargar: () => ref.invalidate(miPerfilPacienteProvider),
      vacio: const EmptyState(
        icono: Icons.badge_outlined,
        titulo: 'Aún no completas tu perfil',
        detalle: 'Necesitamos tus datos para que un médico pueda atenderte.',
      ),
      contenido: (p) => ListView(
        padding: const EdgeInsets.all(Space.lg),
        children: [
          _Encabezado(nombre: p.nombreCompleto, subtitulo: 'Paciente'),
          const SizedBox(height: Space.xl),

          const SectionHeader(titulo: 'Identidad'),
          const SizedBox(height: Space.md),
          AppCard(
            child: Column(
              children: [
                // Documento y fecha de nacimiento son de solo lectura: el
                // backend no los acepta en la actualización.
                DataField(label: 'Documento', value: p.documentoIdentidad),
                SizedBox(height: context.density.paddingTarjeta),
                DataField(
                  label: 'Fecha de nacimiento',
                  value: p.fechaNacimiento.formateada,
                ),
                if (p.sexo != null) ...[
                  SizedBox(height: context.density.paddingTarjeta),
                  DataField(label: 'Sexo', value: p.sexo!),
                ],
              ],
            ),
          ),

          const SizedBox(height: Space.xl),
          const SectionHeader(titulo: 'Datos clínicos'),
          const SizedBox(height: Space.md),
          AppCard(
            child: Column(
              children: [
                DataField(
                  label: 'Tipo de sangre',
                  value: p.tipoSangre ?? '—',
                  destacado: p.tipoSangre != null,
                ),
                SizedBox(height: context.density.paddingTarjeta),
                DataField(label: 'Alergias', value: p.alergias ?? 'Ninguna'),
                SizedBox(height: context.density.paddingTarjeta),
                DataField(label: 'Seguro médico', value: p.seguroMedico ?? '—'),
              ],
            ),
          ),

          if (p.direccion != null) ...[
            const SizedBox(height: Space.xl),
            const SectionHeader(titulo: 'Contacto'),
            const SizedBox(height: Space.md),
            AppCard(
              child: DataField(label: 'Dirección', value: p.direccion!),
            ),
          ],

          const SizedBox(height: Space.huge),
        ],
      ),
    );
  }
}

class _PerfilMedicoVista extends ConsumerWidget {
  const _PerfilMedicoVista();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asincrono = ref.watch(miPerfilMedicoProvider);

    return _Estados<PerfilMedico>(
      valor: asincrono,
      alRecargar: () => ref.invalidate(miPerfilMedicoProvider),
      vacio: const EmptyState(
        icono: Icons.medical_information_outlined,
        titulo: 'Aún no completas tu perfil',
        detalle:
            'Sin tu exequátur no podemos validarte ni mostrarte a los '
            'pacientes.',
      ),
      contenido: (m) => ListView(
        padding: const EdgeInsets.all(Space.lg),
        children: [
          _Encabezado(
            nombre: m.nombreCompleto,
            subtitulo: m.especialidades.isEmpty
                ? 'Sin especialidades'
                : m.especialidades.map((e) => e.nombre).join(' · '),
          ),
          const SizedBox(height: Space.xl),

          // RF-11 — lo primero que ve el médico, porque decide si puede
          // recibir pacientes.
          BadgeVerificacion(estado: m.estadoVerificacion),

          const SizedBox(height: Space.xl),
          const SectionHeader(titulo: 'Credenciales'),
          const SizedBox(height: Space.md),
          AppCard(
            child: Column(
              children: [
                // Identificador legal: mono, como manda el design system.
                DataField(label: 'Exequátur', value: m.numExequatur),
                SizedBox(height: context.density.paddingTarjeta),
                DataField(
                  label: 'Años de experiencia',
                  value: m.aniosExperiencia?.toString() ?? '—',
                ),
                SizedBox(height: context.density.paddingTarjeta),
                DataField(
                  label: 'Tarifa de consulta',
                  value: m.tarifaConsulta == null
                      ? '—'
                      : r'RD$' + m.tarifaConsulta!.toStringAsFixed(0),
                  destacado: m.tarifaConsulta != null,
                ),
              ],
            ),
          ),

          if (m.biografia != null && m.biografia!.isNotEmpty) ...[
            const SizedBox(height: Space.xl),
            const SectionHeader(titulo: 'Biografía'),
            const SizedBox(height: Space.md),
            AppCard(child: Text(m.biografia!, style: context.text.body)),
          ],

          const SizedBox(height: Space.huge),
        ],
      ),
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.nombre, required this.subtitulo});

  final String nombre;
  final String subtitulo;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Avatar(nombre: nombre, tamano: Space.huge),
      const SizedBox(width: Space.lg),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(nombre, style: context.text.heading),
            const SizedBox(height: Space.xs),
            Text(subtitulo, style: context.text.caption),
          ],
        ),
      ),
    ],
  );
}
