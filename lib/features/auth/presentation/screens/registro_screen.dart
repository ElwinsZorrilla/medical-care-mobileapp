import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/domain/tipo_usuario.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/widgets.dart';
import '../providers/auth_provider.dart';

/// RF-01, RF-02 — registro con rol.
class RegistroScreen extends ConsumerStatefulWidget {
  const RegistroScreen({super.key});

  @override
  ConsumerState<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends ConsumerState<RegistroScreen> {
  /// Mínimo y máximo del backend (`RegisterDto`), verificados en F00.
  static const _minContrasena = 8;
  static const _maxContrasena = 72;

  final _correo = TextEditingController();
  final _contrasena = TextEditingController();
  final _telefono = TextEditingController();

  TipoUsuario _tipo = TipoUsuario.paciente;
  bool _enviando = false;
  String? _errorGeneral;
  String? _errorCorreo;
  String? _errorContrasena;

  @override
  void dispose() {
    _correo.dispose();
    _contrasena.dispose();
    _telefono.dispose();
    super.dispose();
  }

  bool _validar() {
    final clave = _contrasena.text;
    setState(() {
      _errorCorreo = _correo.text.trim().isEmpty
          ? 'Escribe tu correo.'
          : !_correo.text.contains('@')
          ? 'Ese correo no parece válido.'
          : null;
      _errorContrasena = clave.length < _minContrasena
          ? 'Usa al menos $_minContrasena caracteres.'
          : clave.length > _maxContrasena
          ? 'Máximo $_maxContrasena caracteres.'
          : null;
    });
    return _errorCorreo == null && _errorContrasena == null;
  }

  Future<void> _crear() async {
    if (_enviando || !_validar()) return;

    setState(() {
      _enviando = true;
      _errorGeneral = null;
    });

    final telefono = _telefono.text.trim();
    final resultado = await ref
        .read(sesionActualProvider.notifier)
        .registrar(
          correo: _correo.text.trim(),
          contrasena: _contrasena.text,
          tipo: _tipo,
          // Vacío se manda como null: el backend corre con
          // `forbidNonWhitelisted` y un string vacío no aporta nada.
          telefono: telefono.isEmpty ? null : telefono,
        );

    if (!mounted) return;

    setState(() {
      _enviando = false;
      _errorGeneral = resultado.failureONull?.mensaje;
    });
  }

  /// Vuelve al login sin apilar una segunda copia.
  ///
  /// Normalmente hay algo que desapilar, porque al registro se llega desde el
  /// login con `push`. Pero a `/registro` también se puede entrar directo por
  /// deep link: ahí no hay nada debajo y `pop` cerraría la app, que es
  /// exactamente el defecto que se está corrigiendo.
  void _volverAlLogin(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(Rutas.login);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppScaffold(
      titulo: 'Crear cuenta',
      tituloCompacto: true,
      leading: BackButton(onPressed: () => _volverAlLogin(context)),
      body: ListView(
        padding: const EdgeInsets.all(Space.lg),
        children: [
          Text('SOY', style: context.text.label),
          const SizedBox(height: Space.sm),
          SegmentedButton<TipoUsuario>(
            segments: [
              for (final t in TipoUsuario.registrables)
                ButtonSegment(value: t, label: Text(t.etiqueta)),
            ],
            selected: {_tipo},
            onSelectionChanged: _enviando
                ? null
                : (s) => setState(() => _tipo = s.first),
          ),
          const SizedBox(height: Space.xl),

          AppTextField(
            label: 'Correo',
            controller: _correo,
            hint: 'paciente@correo.com',
            error: _errorCorreo,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            enabled: !_enviando,
          ),
          const SizedBox(height: Space.lg),

          AppTextField(
            label: 'Contraseña',
            controller: _contrasena,
            obscure: true,
            error: _errorContrasena,
            textInputAction: TextInputAction.next,
            enabled: !_enviando,
          ),
          const SizedBox(height: Space.xs),
          Text(
            'Al menos $_minContrasena caracteres.',
            style: context.text.caption,
          ),
          const SizedBox(height: Space.lg),

          AppTextField(
            label: 'Teléfono (opcional)',
            controller: _telefono,
            hint: '8091234567',
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            monoespaciado: true,
            enabled: !_enviando,
            onSubmitted: (_) => _crear(),
          ),

          if (_errorGeneral != null) ...[
            const SizedBox(height: Space.lg),
            Semantics(
              liveRegion: true,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(Space.md),
                decoration: BoxDecoration(
                  color: colors.granate.withValues(alpha: 0.08),
                  borderRadius: Radii.chip,
                  border: Border.all(
                    color: colors.granate,
                    width: Strokes.filete,
                  ),
                ),
                child: Text(
                  _errorGeneral!,
                  style: context.text.body.copyWith(color: colors.ink),
                ),
              ),
            ),
          ],

          const SizedBox(height: Space.xl),
          AppButton(
            label: 'Crear cuenta',
            cargando: _enviando,
            onPressed: _crear,
          ),
          const SizedBox(height: Space.md),
          AppButton(
            label: 'Ya tengo cuenta',
            variant: AppButtonVariant.secundaria,
            onPressed: _enviando ? null : () => _volverAlLogin(context),
          ),
        ],
      ),
    );
  }
}
