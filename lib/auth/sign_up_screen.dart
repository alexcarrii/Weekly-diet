import 'package:flutter/material.dart';

import '../safety/safety_widgets.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'auth_service.dart';
import 'check_email_screen.dart';
import 'sign_in_screen.dart';

/// A2 · Crear cuenta con email
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _legal = false;
  bool _adult = false;
  bool _marketing = false;
  bool _loading = false;
  bool _submitted = false;
  String? _serverError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String? get _emailError {
    if (!_submitted) return null;
    if (_email.text.trim().isEmpty) return 'Escribe tu email';
    if (!looksLikeEmail(_email.text)) return 'Revisa el email: parece que falta algo';
    return null;
  }

  String? get _passwordError {
    if (!_submitted) return null;
    if (_password.text.length < kMinPasswordLength) {
      return 'La contraseña necesita al menos $kMinPasswordLength caracteres';
    }
    return null;
  }

  String? get _legalError =>
      _submitted && !_legal ? 'Para continuar, acepta los términos y la política de privacidad' : null;

  Future<void> _submit() async {
    setState(() {
      _submitted = true;
      _serverError = null;
    });
    if (_emailError != null || _passwordError != null || _legalError != null || !_adult) return;

    setState(() => _loading = true);
    try {
      final res = await const AuthService().signUp(
        email: _email.text,
        password: _password.text,
        marketingOptIn: _marketing,
      );
      if (!mounted) return;
      if (res.session == null) {
        // "Confirmar email" activado en Supabase: hay que abrir el enlace del correo.
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => CheckEmailScreen(email: _email.text.trim(), mode: CheckEmailMode.confirmSignUp),
          ),
        );
      }
      // Si hay sesión, la puerta de acceso (AuthGate) lleva al onboarding.
    } catch (e) {
      if (mounted) setState(() => _serverError = friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// M1: no se crea la cuenta y se vuelve a la bienvenida.
  Future<void> _minor() async {
    await showMinorNotice(context);
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TopBar(onBack: () => Navigator.of(context).maybePop()),
          Expanded(
            child: AutofillGroup(
              child: ListView(
                padding: const EdgeInsets.only(top: 8),
                children: [
                  const Text('Crea tu cuenta', style: AppText.h1),
                  const SizedBox(height: 24),
                  LabeledField(
                    label: 'Email',
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    error: _emailError,
                  ),
                  const SizedBox(height: 24),
                  LabeledField(
                    label: 'Contraseña',
                    controller: _password,
                    isPassword: true,
                    autofillHints: const [AutofillHints.newPassword],
                    helper: 'Mínimo $kMinPasswordLength caracteres',
                    error: _passwordError,
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 24),
                  CheckRow(
                    value: _legal,
                    hasError: _legalError != null,
                    onChanged: (v) => setState(() => _legal = v),
                    label: const LegalText(),
                  ),
                  if (_legalError != null) ...[
                    const SizedBox(height: 8),
                    ErrorLine(_legalError!),
                  ],
                  const SizedBox(height: 12),
                  AdultConfirmation(
                    value: _adult,
                    showError: _submitted,
                    onChanged: (v) => setState(() => _adult = v),
                    onMinor: _minor,
                  ),
                  const SizedBox(height: 4),
                  CheckRow(
                    value: _marketing,
                    onChanged: (v) => setState(() => _marketing = v),
                    label: const Text('Quiero recibir ideas y ofertas por email (opcional)'),
                  ),
                  if (_serverError != null) ...[
                    const SizedBox(height: 16),
                    ErrorLine(_serverError!),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          AppButton(label: 'Crear cuenta', loading: _loading, onPressed: _submit),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('¿Ya tienes cuenta?', style: AppText.bodyMuted),
              LinkButton(
                label: 'Inicia sesión',
                onPressed: () => Navigator.of(context)
                    .pushReplacement(MaterialPageRoute(builder: (_) => const SignInScreen())),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
