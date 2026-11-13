import 'package:flutter/material.dart';

import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'auth_service.dart';
import 'forgot_password_screen.dart';
import 'sign_up_screen.dart';

/// A4 · Iniciar sesión
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _googleLoading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!looksLikeEmail(_email.text) || _password.text.isEmpty) {
      setState(() => _error = 'Escribe tu email y tu contraseña.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await const AuthService().signIn(email: _email.text, password: _password.text);
      // La puerta de acceso (AuthGate) cambia de pantalla al detectar la sesión.
    } catch (e) {
      if (mounted) setState(() => _error = friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _google() async {
    setState(() {
      _googleLoading = true;
      _error = null;
    });
    try {
      await const AuthService().signInWithGoogle();
    } catch (e) {
      if (mounted) setState(() => _error = friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _googleLoading = false);
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
            child: AutofillGroup(
              child: ListView(
                padding: const EdgeInsets.only(top: 8),
                children: [
                  const Text('Hola de nuevo', style: AppText.h1),
                  const SizedBox(height: 24),
                  AppButton(
                    label: 'Continuar con Google',
                    style: AppButtonStyle.google,
                    leading: const GoogleMarkPlaceholder(),
                    loading: _googleLoading,
                    onPressed: _google,
                  ),
                  const SizedBox(height: 24),
                  const Row(
                    children: [
                      Expanded(child: Divider(color: AppColors.border, thickness: 1)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('o con tu email', style: AppText.smallMuted),
                      ),
                      Expanded(child: Divider(color: AppColors.border, thickness: 1)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  LabeledField(
                    label: 'Email',
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 24),
                  LabeledField(
                    label: 'Contraseña',
                    controller: _password,
                    isPassword: true,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => _signIn(),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: LinkButton(
                      label: '¿Has olvidado tu contraseña?',
                      fontSize: 14,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => ForgotPasswordScreen(initialEmail: _email.text.trim())),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    ErrorLine(_error!),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          AppButton(label: 'Iniciar sesión', loading: _loading, onPressed: _signIn),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('¿No tienes cuenta?', style: AppText.bodyMuted),
              LinkButton(
                label: 'Créala gratis',
                onPressed: () => Navigator.of(context)
                    .pushReplacement(MaterialPageRoute(builder: (_) => const SignUpScreen())),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
