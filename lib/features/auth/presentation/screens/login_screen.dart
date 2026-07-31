import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/widgets.dart';
import '../providers/auth_provider.dart';

/// RF-03 — inicio de sesión.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _correo = TextEditingController();
  final _contrasena = TextEditingController();

  bool _enviando = false;
  String? _errorGeneral;
  String? _errorCorreo;
  String? _errorContrasena;

  @override
  void dispose() {
    _correo.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  /// Validación local antes de gastar una petición.
  ///
  /// El backend valida igual —es la autoridad—, pero pedirle al servidor que
  /// diga "el correo no es un correo" con datos móviles lentos es hacer
  /// esperar al usuario por algo que se sabe al instante.
  bool _validar() {
    setState(() {
      _errorCorreo = _correo.text.trim().isEmpty
          ? 'Escribe tu correo.'
          : !_correo.text.contains('@')
          ? 'Ese correo no parece válido.'
          : null;
      _errorContrasena = _contrasena.text.isEmpty
          ? 'Escribe tu contraseña.'
          : null;
    });
    return _errorCorreo == null && _errorContrasena == null;
  }

  Future<void> _entrar() async {
    if (_enviando || !_validar()) return;

    setState(() {
      _enviando = true;
      _errorGeneral = null;
    });

    final resultado = await ref
        .read(sesionActualProvider.notifier)
        .iniciarSesion(
          correo: _correo.text.trim(),
          contrasena: _contrasena.text,
        );

    if (!mounted) return;

    setState(() {
      _enviando = false;
      // El mensaje llega ya redactado desde la capa de datos. La pantalla no
      // traduce códigos HTTP.
      _errorGeneral = resultado.failureONull?.mensaje;
    });
    // Si salió bien, el guard del router redirige solo al ver la sesión.
  }

  @override
  Widget build(BuildContext context) {
    final text = context.text;

    return AppScaffold(
      titulo: 'Entrar',
      body: ListView(
        padding: const EdgeInsets.all(Space.lg),
        children: [
          Text(
            'Gestiona tus citas médicas.',
            style: text.body.copyWith(color: context.colors.steel),
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
            textInputAction: TextInputAction.done,
            enabled: !_enviando,
            onSubmitted: (_) => _entrar(),
          ),

          if (_errorGeneral != null) ...[
            const SizedBox(height: Space.lg),
            _AvisoError(mensaje: _errorGeneral!),
          ],

          const SizedBox(height: Space.xl),
          AppButton(label: 'Entrar', cargando: _enviando, onPressed: _entrar),
          const SizedBox(height: Space.md),
          AppButton(
            label: 'Crear una cuenta',
            variant: AppButtonVariant.secundaria,
            onPressed: _enviando ? null : () => context.go(Rutas.registro),
          ),
        ],
      ),
    );
  }
}

/// Error de la operación, anclado bajo el formulario.
///
/// No es un toast: un mensaje que se desvanece obliga a recordarlo mientras
/// se corrige el campo que lo causó.
class _AvisoError extends StatelessWidget {
  const _AvisoError({required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Space.md),
        decoration: BoxDecoration(
          color: colors.granate.withValues(alpha: 0.08),
          borderRadius: Radii.chip,
          border: Border.all(color: colors.granate, width: Strokes.filete),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, size: Space.xl, color: colors.granate),
            const SizedBox(width: Space.md),
            Expanded(
              child: Text(
                mensaje,
                style: context.text.body.copyWith(color: colors.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
