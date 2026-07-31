import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/consulta.dart';
import '../providers/historial_provider.dart';

/// Registrar una consulta — RF-25, RF-26.
///
/// Esta pantalla **no existía** hasta F15. `RegistroConsulta` estaba desde F09
/// con sus pruebas, pero ningún widget lo invocaba: la matriz daba RF-25 y
/// RF-26 por cumplidos y un médico no tenía dónde escribir un diagnóstico.
///
/// **Registrar la consulta mueve la cita a COMPLETADA.** Es la única forma de
/// alcanzar ese estado —el backend no expone una transición
/// (BACKEND_ISSUES.md #4)— así que la pantalla lo dice antes de guardar, y no
/// después.
class RegistroConsultaScreen extends ConsumerStatefulWidget {
  const RegistroConsultaScreen({required this.idCita, super.key});

  final int idCita;

  @override
  ConsumerState<RegistroConsultaScreen> createState() =>
      _RegistroConsultaScreenState();
}

class _RegistroConsultaScreenState
    extends ConsumerState<RegistroConsultaScreen> {
  final _diagnostico = TextEditingController();
  final _tratamiento = TextEditingController();
  final _observaciones = TextEditingController();

  /// Recetas que se van agregando. Viajan **en la misma llamada** que la
  /// consulta, no en una posterior: dos peticiones podrían dejar una consulta
  /// sin sus recetas si la segunda falla.
  final List<NuevaReceta> _recetas = [];

  bool _enviando = false;

  /// `AppTextField` no se integra con `Form`: recibe el error ya redactado.
  /// Es la misma via que usan login y registro.
  String? _errorDiagnostico;

  @override
  void dispose() {
    _diagnostico.dispose();
    _tratamiento.dispose();
    _observaciones.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final diagnostico = _diagnostico.text.trim();
    if (diagnostico.isEmpty) {
      // Sin diagnostico no hay consulta: el backend lo rechaza con 400 y la
      // cita no pasaria a COMPLETADA.
      setState(() => _errorDiagnostico = 'El diagnóstico es obligatorio.');
      return;
    }
    setState(() {
      _errorDiagnostico = null;
      _enviando = true;
    });

    final fallo = await ref
        .read(registroConsultaProvider.notifier)
        .registrar(
          SolicitudConsulta(
            idCita: widget.idCita,
            diagnostico: diagnostico,
            tratamiento: _vacioANulo(_tratamiento.text),
            observaciones: _vacioANulo(_observaciones.text),
            recetas: _recetas,
          ),
        );

    if (!mounted) return;
    setState(() => _enviando = false);

    if (fallo == null) {
      _avisar('Consulta registrada. La cita quedó completada.');
      await Navigator.of(context).maybePop();
      return;
    }
    _avisar(fallo is Failure ? fallo.mensaje : 'Algo salió mal.');
  }

  String? _vacioANulo(String s) => s.trim().isEmpty ? null : s.trim();

  void _avisar(String mensaje) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(mensaje)));

  Future<void> _agregarReceta() async {
    final receta = await showDialog<NuevaReceta>(
      context: context,
      builder: (_) => const _DialogoReceta(),
    );
    if (receta != null) setState(() => _recetas.add(receta));
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    titulo: 'Registrar consulta',
    // Scroll: con el teclado abierto, el botón de guardar quedaría fuera de
    // pantalla en un teléfono chico.
    body: ListView(
      padding: const EdgeInsets.all(Space.lg),
      children: [
        AppTextField(
          label: 'Diagnóstico',
          controller: _diagnostico,
          error: _errorDiagnostico,
          maxLines: 3,
        ),
        const SizedBox(height: Space.lg),
        AppTextField(
          label: 'Tratamiento (opcional)',
          controller: _tratamiento,
          maxLines: 3,
        ),
        const SizedBox(height: Space.lg),
        AppTextField(
          label: 'Observaciones (opcional)',
          controller: _observaciones,
          maxLines: 3,
        ),
        const SizedBox(height: Space.xl),
        SectionHeader(
          titulo: 'Recetas (${_recetas.length})',
          accion: 'Agregar',
          onAccion: _agregarReceta,
        ),
        const SizedBox(height: Space.sm),
        for (final r in _recetas)
          AppCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(r.medicamento, style: context.text.bodyStrong),
                      Text(
                        '${r.dosis} · ${r.frecuencia}',
                        style: context.text.caption,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _recetas.remove(r)),
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Quitar receta',
                ),
              ],
            ),
          ),
        const SizedBox(height: Space.xl),
        // Se avisa **antes** de guardar: el efecto es irreversible y no hay
        // endpoint para volver atrás.
        Text(
          'Al guardar, la cita queda marcada como completada.',
          style: context.text.caption,
        ),
        const SizedBox(height: Space.md),
        AppButton(
          label: _enviando ? 'Guardando…' : 'Guardar consulta',
          onPressed: _enviando ? null : _guardar,
        ),
      ],
    ),
  );
}

/// Alta de una receta — RF-26.
class _DialogoReceta extends StatefulWidget {
  const _DialogoReceta();

  @override
  State<_DialogoReceta> createState() => _DialogoRecetaState();
}

class _DialogoRecetaState extends State<_DialogoReceta> {
  final _medicamento = TextEditingController();
  final _dosis = TextEditingController();
  final _frecuencia = TextEditingController();

  @override
  void dispose() {
    _medicamento.dispose();
    _dosis.dispose();
    _frecuencia.dispose();
    super.dispose();
  }

  /// Un error por campo, redactado. `AppTextField` no valida solo.
  final Map<String, String?> _errores = {};

  /// Los tres campos son obligatorios en el backend: una receta sin dosis o
  /// sin frecuencia no le dice nada al paciente.
  bool _valido() {
    final faltan = {
      'medicamento': _medicamento.text.trim().isEmpty,
      'dosis': _dosis.text.trim().isEmpty,
      'frecuencia': _frecuencia.text.trim().isEmpty,
    };
    setState(() {
      for (final e in faltan.entries) {
        _errores[e.key] = e.value ? 'Obligatorio.' : null;
      }
    });
    return !faltan.values.any((v) => v);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nueva receta'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppTextField(
            label: 'Medicamento',
            controller: _medicamento,
            error: _errores['medicamento'],
          ),
          const SizedBox(height: Space.md),
          AppTextField(
            label: 'Dosis',
            controller: _dosis,
            error: _errores['dosis'],
          ),
          const SizedBox(height: Space.md),
          AppTextField(
            label: 'Frecuencia',
            controller: _frecuencia,
            error: _errores['frecuencia'],
          ),
        ],
      ),
    ),
    actions: [
      AppButton(
        label: 'Cancelar',
        variant: AppButtonVariant.secundaria,
        expandido: false,
        onPressed: () => Navigator.of(context).pop(),
      ),
      AppButton(
        label: 'Agregar',
        expandido: false,
        onPressed: () {
          if (!_valido()) return;
          Navigator.of(context).pop(
            NuevaReceta(
              medicamento: _medicamento.text.trim(),
              dosis: _dosis.text.trim(),
              frecuencia: _frecuencia.text.trim(),
            ),
          );
        },
      ),
    ],
  );
}
