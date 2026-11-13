import 'package:flutter/material.dart';

import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'auth_service.dart';

/// A7 · Nueva contraseña (se abre desde el enlace del email de recuperación)
class NewPasswordScreen extends StatefulWidget {
  const NewPasswordScreen({super.key, required this.onDone});

  /// Se llama cuando la contraseña se ha guardado: la app sigue al onboarding o al inicio.
  final VoidCallback onDone;

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_password.text.length < kMinPasswordLength) {
      setState(() => _error = 'La contraseña necesita al menos $kMinPasswordLength caracteres');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await const AuthService().updatePassword(_password.text);
      widget.onDone();
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
          const SizedBox(height: 48),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 8),
              children: [
                const Text('Crea una contraseña nueva', style: AppText.h1),
                const SizedBox(height: 12),
                const Text('Al guardarla entrarás directamente en la app.', style: AppText.bodyMuted),
                const SizedBox(height: 24),
                LabeledField(
                  label: 'Contraseña nueva',
                  controller: _password,
                  isPassword: true,
                  autofillHints: const [AutofillHints.newPassword],
                  helper: 'Mínimo $kMinPasswordLength caracteres',
                  error: _error,
                  onSubmitted: (_) => _save(),
                ),
              ],
            ),
          ),
          AppButton(label: 'Guardar y entrar', loading: _loading, onPressed: _save),
        ],
      ),
    );
  }
}
