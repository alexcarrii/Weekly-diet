import 'dart:async';

import 'package:flutter/material.dart';

import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'auth_service.dart';

enum CheckEmailMode { passwordReset, confirmSignUp }

/// A6 · Revisa tu email (recuperar contraseña o confirmar la cuenta)
class CheckEmailScreen extends StatefulWidget {
  const CheckEmailScreen({super.key, required this.email, required this.mode});

  final String email;
  final CheckEmailMode mode;

  @override
  State<CheckEmailScreen> createState() => _CheckEmailScreenState();
}

class _CheckEmailScreenState extends State<CheckEmailScreen> {
  // Supabase permite un email cada 60 s por usuario.
  static const _cooldown = 60;
  int _secondsLeft = _cooldown;
  Timer? _timer;
  bool _sending = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _secondsLeft = _cooldown;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _resend() async {
    setState(() {
      _sending = true;
      _message = null;
    });
    try {
      const auth = AuthService();
      if (widget.mode == CheckEmailMode.passwordReset) {
        await auth.sendPasswordReset(widget.email);
      } else {
        await auth.resendSignUpEmail(widget.email);
      }
      if (mounted) {
        setState(() {
          _startTimer();
          _message = 'Te lo hemos vuelto a enviar.';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _message = friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String get _countdown {
    final m = _secondsLeft ~/ 60;
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isReset = widget.mode == CheckEmailMode.passwordReset;
    final body = isReset
        ? 'te llegará un enlace en unos minutos. Caduca en 1 hora.'
        : 'te llegará un enlace para confirmar tu cuenta. Ábrelo desde este dispositivo.';
    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TopBar(onBack: () => Navigator.of(context).maybePop()),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 40),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
                    child: const Icon(Icons.mail_outline, size: 40, color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Revisa tu email', style: AppText.h1),
                const SizedBox(height: 20),
                Text.rich(
                  TextSpan(
                    style: AppText.bodyMuted,
                    children: [
                      TextSpan(text: isReset ? 'Si hay una cuenta con ' : 'Hemos enviado un correo a '),
                      TextSpan(
                        text: widget.email,
                        style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700),
                      ),
                      TextSpan(text: isReset ? ', $body' : '. Allí $body'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const InfoBox(text: '¿No lo ves? Mira en la carpeta de spam.'),
                if (_message != null) ...[
                  const SizedBox(height: 16),
                  Text(_message!, style: AppText.smallMuted),
                ],
              ],
            ),
          ),
          // "Abrir el correo" del diseño no se incluye en la versión web: el navegador
          // no puede abrir la app de correo del móvil. Se añadirá en la app nativa.
          AppButton(
            label: _secondsLeft > 0 ? 'Reenviar en $_countdown' : 'Reenviar el email',
            style: AppButtonStyle.outline,
            loading: _sending,
            onPressed: _secondsLeft > 0 ? null : _resend,
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Volver a iniciar sesión',
            style: AppButtonStyle.ghost,
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
          ),
        ],
      ),
    );
  }
}
