import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/especialidades_catalogo.dart';
import '../../../../core/domain/especialidad.dart';
import '../../../../core/domain/fecha_calendario.dart';
import '../../../../core/domain/tipo_usuario.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/perfil.dart';
import '../providers/perfil_provider.dart';

/// Crear o editar el perfil propio — RF-10.
///
/// La capa de datos existía desde F05 con sus pruebas y **ninguna pantalla la
/// llamaba**: RF-10 estaba marcado como cubierto y no había dónde editar. Lo
/// destapó F15 recorriendo `lib/` en busca de métodos públicos sin consumidor.
///
/// Una sola pantalla para los dos roles, resuelta por el tipo de la sesión —
/// como el resto de la app. El backend saca el titular del token, así que
/// aquí no hay ningún id de usuario que alguien pueda cambiar (RF-09).
class EdicionPerfilScreen extends StatelessWidget {
  const EdicionPerfilScreen({required this.tipo, super.key});

  /// Lo inyecta el router, que ya resolvió la sesión para su guard por rol.
  ///
  /// Leerlo aquí de `sesionActualProvider` obligaría a importar de
  /// `features/auth`, y un feature no importa de otro (rubro 3.3). La guarda
  /// de `test/arquitectura_test.dart` lo rechazó al primer intento, que es
  /// justo para lo que se escribió.
  final TipoUsuario? tipo;

  @override
  Widget build(BuildContext context) {
    return switch (tipo) {
      TipoUsuario.medico => const _FormularioMedico(),
      // El admin no tiene perfil clínico; se le da la vista de paciente por
      // coherencia con el resto del router.
      _ => const _FormularioPaciente(),
    };
  }
}

// ── Paciente ───────────────────────────────────────────────────────────────

class _FormularioPaciente extends ConsumerStatefulWidget {
  const _FormularioPaciente();

  @override
  ConsumerState<_FormularioPaciente> createState() => _PacienteState();
}

class _PacienteState extends ConsumerState<_FormularioPaciente> {
  final _nombres = TextEditingController();
  final _apellidos = TextEditingController();
  final _documento = TextEditingController();
  final _nacimiento = TextEditingController();
  final _direccion = TextEditingController();
  final _tipoSangre = TextEditingController();
  final _alergias = TextEditingController();
  final _seguro = TextEditingController();

  /// `AppTextField` no se integra con `Form`: recibe el error ya redactado,
  /// igual que login y registro.
  final Map<String, String?> _errores = {};

  bool _enviando = false;
  bool _precargado = false;

  @override
  void dispose() {
    for (final c in [
      _nombres,
      _apellidos,
      _documento,
      _nacimiento,
      _direccion,
      _tipoSangre,
      _alergias,
      _seguro,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Rellena una sola vez con lo que ya hay guardado.
  ///
  /// Sin esto, abrir la edición borraría los campos que el usuario no toca:
  /// el PATCH manda lo que está en pantalla.
  void _precargar(PerfilPaciente p) {
    if (_precargado) return;
    _precargado = true;
    _nombres.text = p.nombres;
    _apellidos.text = p.apellidos;
    _documento.text = p.documentoIdentidad;
    _nacimiento.text = p.fechaNacimiento.toApi();
    _direccion.text = p.direccion ?? '';
    _tipoSangre.text = p.tipoSangre ?? '';
    _alergias.text = p.alergias ?? '';
    _seguro.text = p.seguroMedico ?? '';
  }

  Future<void> _guardar(bool existe) async {
    final nacimiento = FechaCalendario.parse(_nacimiento.text.trim());
    setState(() {
      _errores['nombres'] = _nombres.text.trim().isEmpty
          ? 'Obligatorio.'
          : null;
      _errores['apellidos'] = _apellidos.text.trim().isEmpty
          ? 'Obligatorio.'
          : null;
      // El documento solo se pide al crear: el backend no deja cambiarlo.
      _errores['documento'] = (!existe && _documento.text.trim().isEmpty)
          ? 'Obligatorio.'
          : null;
      _errores['nacimiento'] = nacimiento == null
          ? 'Usa el formato AAAA-MM-DD.'
          : null;
    });
    if (_errores.values.any((e) => e != null)) return;

    setState(() => _enviando = true);
    final fallo = await ref
        .read(edicionPerfilProvider.notifier)
        .guardarPaciente(
          existe: existe,
          nombres: _nombres.text.trim(),
          apellidos: _apellidos.text.trim(),
          documentoIdentidad: _documento.text.trim(),
          fechaNacimiento: nacimiento!,
          direccion: _nulo(_direccion),
          tipoSangre: _nulo(_tipoSangre),
          alergias: _nulo(_alergias),
          seguroMedico: _nulo(_seguro),
        );

    if (!mounted) return;
    setState(() => _enviando = false);
    await _cerrarOAvisar(context, fallo);
  }

  String? _nulo(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  @override
  Widget build(BuildContext context) {
    final perfil = ref.watch(miPerfilPacienteProvider);

    return AppScaffold(
      titulo: 'Mis datos',
      body: switch (perfil) {
        AsyncLoading<PerfilPaciente?>() => Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: LoadingSkeleton.lineas(context, cantidad: 6),
        ),
        AsyncError<PerfilPaciente?>(:final error) => ErrorState(
          mensaje: error is Failure ? error.mensaje : 'Algo salió mal.',
          onReintentar: () => ref.invalidate(miPerfilPacienteProvider),
        ),
        AsyncData<PerfilPaciente?>(:final value) => _cuerpo(value),
      },
    );
  }

  Widget _cuerpo(PerfilPaciente? p) {
    if (p != null) _precargar(p);
    final existe = p != null;

    return ListView(
      padding: const EdgeInsets.all(Space.lg),
      children: [
        AppTextField(
          label: 'Nombres',
          controller: _nombres,
          error: _errores['nombres'],
        ),
        const SizedBox(height: Space.lg),
        AppTextField(
          label: 'Apellidos',
          controller: _apellidos,
          error: _errores['apellidos'],
        ),
        const SizedBox(height: Space.lg),
        AppTextField(
          label: 'Documento de identidad',
          controller: _documento,
          error: _errores['documento'],
          // El backend lo fija al crear y no lo acepta en el PATCH.
          enabled: !existe,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const SizedBox(height: Space.lg),
        AppTextField(
          label: 'Fecha de nacimiento (AAAA-MM-DD)',
          controller: _nacimiento,
          error: _errores['nacimiento'],
          hint: '1985-03-21',
        ),
        const SizedBox(height: Space.xl),
        const SectionHeader(titulo: 'Datos clínicos'),
        const SizedBox(height: Space.md),
        AppTextField(label: 'Tipo de sangre', controller: _tipoSangre),
        const SizedBox(height: Space.lg),
        AppTextField(label: 'Alergias', controller: _alergias, maxLines: 2),
        const SizedBox(height: Space.lg),
        AppTextField(label: 'Dirección', controller: _direccion, maxLines: 2),
        const SizedBox(height: Space.lg),
        AppTextField(label: 'Seguro médico', controller: _seguro),
        const SizedBox(height: Space.xl),
        AppButton(
          label: _enviando
              ? 'Guardando…'
              : (existe ? 'Guardar cambios' : 'Crear perfil'),
          onPressed: _enviando ? null : () => _guardar(existe),
        ),
      ],
    );
  }
}

// ── Médico ─────────────────────────────────────────────────────────────────

class _FormularioMedico extends ConsumerStatefulWidget {
  const _FormularioMedico();

  @override
  ConsumerState<_FormularioMedico> createState() => _MedicoState();
}

class _MedicoState extends ConsumerState<_FormularioMedico> {
  final _nombres = TextEditingController();
  final _apellidos = TextEditingController();
  final _exequatur = TextEditingController();
  final _biografia = TextEditingController();
  final _anios = TextEditingController();
  final _tarifa = TextEditingController();

  final Map<String, String?> _errores = {};
  bool _enviando = false;
  bool _precargado = false;

  /// RF-11 — las especialidades elegidas.
  ///
  /// `Set` y no `List`: tocar dos veces el mismo chip no puede mandar el id
  /// repetido, y el backend guardaría la relación duplicada.
  final Set<int> _especialidades = {};

  @override
  void dispose() {
    for (final c in [
      _nombres,
      _apellidos,
      _exequatur,
      _biografia,
      _anios,
      _tarifa,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _precargar(PerfilMedico m) {
    if (_precargado) return;
    _precargado = true;
    _nombres.text = m.nombres;
    _apellidos.text = m.apellidos;
    _exequatur.text = m.numExequatur;
    _biografia.text = m.biografia ?? '';
    _anios.text = m.aniosExperiencia?.toString() ?? '';
    _tarifa.text = m.tarifaConsulta?.toStringAsFixed(0) ?? '';
    _especialidades
      ..clear()
      ..addAll(m.especialidades.map((e) => e.id));
  }

  Future<void> _guardar(int? idMedico) async {
    setState(() {
      _errores['nombres'] = _nombres.text.trim().isEmpty
          ? 'Obligatorio.'
          : null;
      _errores['apellidos'] = _apellidos.text.trim().isEmpty
          ? 'Obligatorio.'
          : null;
      _errores['exequatur'] =
          (idMedico == null && _exequatur.text.trim().isEmpty)
          ? 'Sin exequátur no podemos validarte.'
          : null;
    });
    if (_errores.values.any((e) => e != null)) return;

    setState(() => _enviando = true);
    final fallo = await ref
        .read(edicionPerfilProvider.notifier)
        .guardarMedico(
          idMedico: idMedico,
          nombres: _nombres.text.trim(),
          apellidos: _apellidos.text.trim(),
          numExequatur: _exequatur.text.trim(),
          biografia: _biografia.text.trim().isEmpty
              ? null
              : _biografia.text.trim(),
          aniosExperiencia: int.tryParse(_anios.text.trim()),
          tarifaConsulta: double.tryParse(_tarifa.text.trim()),
          especialidadIds: _especialidades.toList(),
        );

    if (!mounted) return;
    setState(() => _enviando = false);
    await _cerrarOAvisar(context, fallo);
  }

  @override
  Widget build(BuildContext context) {
    final perfil = ref.watch(miPerfilMedicoProvider);

    return AppScaffold(
      titulo: 'Mis datos',
      body: switch (perfil) {
        AsyncLoading<PerfilMedico?>() => Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: LoadingSkeleton.lineas(context, cantidad: 6),
        ),
        AsyncError<PerfilMedico?>(:final error) => ErrorState(
          mensaje: error is Failure ? error.mensaje : 'Algo salió mal.',
          onReintentar: () => ref.invalidate(miPerfilMedicoProvider),
        ),
        AsyncData<PerfilMedico?>(:final value) => _cuerpo(value),
      },
    );
  }

  Widget _cuerpo(PerfilMedico? m) {
    if (m != null) _precargar(m);

    return ListView(
      padding: const EdgeInsets.all(Space.lg),
      children: [
        AppTextField(
          label: 'Nombres',
          controller: _nombres,
          error: _errores['nombres'],
        ),
        const SizedBox(height: Space.lg),
        AppTextField(
          label: 'Apellidos',
          controller: _apellidos,
          error: _errores['apellidos'],
        ),
        const SizedBox(height: Space.lg),
        AppTextField(
          label: 'Número de exequátur',
          controller: _exequatur,
          error: _errores['exequatur'],
          // Es la credencial que valida al médico: el backend no la acepta en
          // el PATCH, solo al crear.
          enabled: m == null,
        ),
        const SizedBox(height: Space.xl),
        const SectionHeader(titulo: 'Perfil público'),
        const SizedBox(height: Space.md),
        AppTextField(label: 'Biografía', controller: _biografia, maxLines: 4),
        const SizedBox(height: Space.lg),
        AppTextField(
          label: 'Años de experiencia',
          controller: _anios,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const SizedBox(height: Space.lg),
        AppTextField(
          label: 'Tarifa de consulta (RD\$)',
          controller: _tarifa,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const SizedBox(height: Space.xl),
        const SectionHeader(titulo: 'Especialidades'),
        const SizedBox(height: Space.md),
        _SelectorEspecialidades(
          elegidas: _especialidades,
          onCambio: (id, activa) => setState(() {
            activa ? _especialidades.add(id) : _especialidades.remove(id);
          }),
        ),
        const SizedBox(height: Space.xl),
        AppButton(
          label: _enviando
              ? 'Guardando…'
              : (m == null ? 'Crear perfil' : 'Guardar cambios'),
          onPressed: _enviando ? null : () => _guardar(m?.idMedico),
        ),
      ],
    );
  }
}

/// RF-11 — el médico elige sus especialidades del catálogo.
///
/// Es un multi-select y no un desplegable de una sola: un médico puede tener
/// varias, y el backend recibe una lista.
///
/// Si el catálogo no carga, **el formulario sigue usable**: el resto del
/// perfil se puede guardar igual. Tumbar la pantalla entera porque falló una
/// petición secundaria dejaría al médico sin poder ni corregir su nombre.
class _SelectorEspecialidades extends ConsumerWidget {
  const _SelectorEspecialidades({
    required this.elegidas,
    required this.onCambio,
  });

  final Set<int> elegidas;
  final void Function(int id, bool activa) onCambio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogo = ref.watch(catalogoEspecialidadesProvider);

    return switch (catalogo) {
      AsyncLoading<List<Especialidad>>() => const LoadingSkeleton(),
      AsyncError<List<Especialidad>>() => Align(
        alignment: Alignment.centerLeft,
        child: AppButton(
          label: 'Cargar especialidades',
          variant: AppButtonVariant.secundaria,
          expandido: false,
          onPressed: () => ref.invalidate(catalogoEspecialidadesProvider),
        ),
      ),
      AsyncData<List<Especialidad>>(:final value) =>
        value.isEmpty
            ? Text(
                'No hay especialidades en el catálogo.',
                style: context.text.caption,
              )
            : Wrap(
                spacing: Space.sm,
                runSpacing: Space.sm,
                children: [
                  for (final e in value)
                    _ChipEspecialidad(
                      etiqueta: e.nombre,
                      activa: elegidas.contains(e.id),
                      onTap: () => onCambio(e.id, !elegidas.contains(e.id)),
                    ),
                ],
              ),
    };
  }
}

class _ChipEspecialidad extends StatelessWidget {
  const _ChipEspecialidad({
    required this.etiqueta,
    required this.activa,
    required this.onTap,
  });

  final String etiqueta;
  final bool activa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      selected: activa,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.chip,
        child: Container(
          alignment: Alignment.center,
          constraints: const BoxConstraints(minHeight: kTactilMinimo),
          padding: const EdgeInsets.symmetric(horizontal: Space.md),
          decoration: BoxDecoration(
            color: activa ? colors.verde : colors.surface,
            borderRadius: Radii.chip,
            border: Border.all(
              color: activa ? colors.verde : colors.filete,
              width: Strokes.filete,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Tercer canal: el color solo no distingue elegida de no
              // elegida para quien no lo percibe (RNF-04).
              Icon(
                activa ? Icons.check : Icons.add,
                size: Space.md,
                color: activa ? colors.surface : colors.steel,
              ),
              const SizedBox(width: Space.xs),
              Text(
                etiqueta,
                style: context.text.label.copyWith(
                  color: activa ? colors.surface : colors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cierra al guardar bien, o deja el formulario con el mensaje del servidor.
///
/// No se vacía nada al fallar: perder lo escrito por un 409 sería castigar al
/// usuario por un problema del servidor.
Future<void> _cerrarOAvisar(BuildContext context, Failure? fallo) async {
  final messenger = ScaffoldMessenger.of(context);
  if (fallo == null) {
    messenger.showSnackBar(const SnackBar(content: Text('Perfil guardado.')));
    await Navigator.of(context).maybePop();
    return;
  }
  messenger.showSnackBar(SnackBar(content: Text(fallo.mensaje)));
}
