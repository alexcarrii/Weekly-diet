import 'package:flutter/material.dart';

import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'auth_service.dart';
import 'check_email_screen.dart';

/// A5 · Recuperar contraseña
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final _email = TextEditingController(text: widget.initialEmail);
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!looksLikeEmail(_email.text)) {
      setState(() => _error = 'Escribe el email con el que te registraste');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await const AuthService().sendPasswordReset(_email.text);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CheckEmailScreen(email: _email.text.trim(), mode: CheckEmailMode.passwordReset),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _error = friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TopBar(onBack: () => Navigator.of(context).maybePop()),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 8),
              children: [
                const Text('Recupera tu contraseña', style: AppText.h1),
                const SizedBox(height: 12),
                const Text('Escribe tu email y te enviaremos un enlace para crear una nueva.',
                    style: AppText.bodyMuted),
                const SizedBox(height: 24),
                LabeledField(
                  label: 'Email',
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  error: _error,
                  onSubmitted: (_) => _send(),
                ),
              ],
            ),
          ),
          AppButton(label: 'Enviar enlace', loading: _loading, onPressed: _send),
        ],
      ),
    );
  }
}
