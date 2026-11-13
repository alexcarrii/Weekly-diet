import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/accept_terms_screen.dart';
import 'auth/auth_service.dart';
import 'auth/new_password_screen.dart';
import 'auth/welcome_screen.dart';
import 'home/home_screen.dart';
import 'onboarding/onboarding_flow.dart';
import 'platform/url_cleaner.dart';
import 'safety/safety_logic.dart';
import 'ui/theme.dart';
import 'ui/widgets.dart';

// La URL y la clave pública (anon) llegan al compilar con --dart-define.
// La clave anon es pública por diseño: la seguridad la pone el RLS de la base de datos.
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }
  runApp(const WeeklyDietApp());
}

class WeeklyDietApp extends StatelessWidget {
  const WeeklyDietApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weekly Diet',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: buildAppTheme(),
      home: supabaseUrl.isEmpty || supabaseAnonKey.isEmpty ? const _MissingConfigScreen() : const AuthGate(),
    );
  }
}

class _MissingConfigScreen extends StatelessWidget {
  const _MissingConfigScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Falta la configuración de Supabase.\n'
            'Compila con --dart-define=SUPABASE_URL=... y SUPABASE_ANON_KEY=...',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

/// Decide qué pantalla ver:
///   sin sesión → Bienvenida (A1) · enlace de recuperar → Nueva contraseña (A7)
///   sin términos o sin mayoría de edad → Aceptar términos (A3) · onboarding sin terminar → Onboarding
///   cribado sin responder (o de una versión anterior) → Cribado + objetivo · todo listo → Inicio
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final StreamSubscription<AuthState> _sub;
  bool _recovery = openedFromPasswordReset();
  bool _urlCleaned = false;
  String? _userId;
  Map<String, dynamic>? _profile;
  String? _profileError;

  @override
  void initState() {
    super.initState();
    _userId = db.auth.currentUser?.id;
    if (_userId != null) _loadProfile();
    _sub = db.auth.onAuthStateChange.listen(_onAuthChange);
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  void _onAuthChange(AuthState state) {
    final newUserId = state.session?.user.id;
    final userChanged = newUserId != _userId;
    if (state.event == AuthChangeEvent.passwordRecovery) _recovery = true;
    if (state.event == AuthChangeEvent.signedOut) _recovery = false;

    if (userChanged || state.event == AuthChangeEvent.passwordRecovery) {
      // Al entrar o salir se cierran las pantallas abiertas encima (login, registro…).
      navigatorKey.currentState?.popUntil((r) => r.isFirst);
    }
    if (!mounted) return;
    setState(() {
      _userId = newUserId;
      if (userChanged) {
        _profile = null;
        _profileError = null;
      }
    });
    if (userChanged && newUserId != null) _loadProfile();
  }

  Future<void> _loadProfile() async {
    final uid = db.auth.currentUser?.id;
    if (uid == null) return;
    setState(() => _profileError = null);
    try {
      final profile = await db
          .from('profiles')
          .select('display_name, terms_version, onboarding_completed, is_adult_confirmed, safety_screening_version')
          .eq('id', uid)
          .maybeSingle();
      if (!mounted || db.auth.currentUser?.id != uid) return;
      setState(() {
        _profile = profile;
        _profileError = profile == null ? 'No encontramos tu perfil.' : null;
      });
    } catch (e) {
      if (mounted) setState(() => _profileError = friendlyAuthError(e));
    }
  }

  String? get _firstName {
    final name = (_profile?['display_name'] as String?)?.trim();
    if (name == null || name.isEmpty) return null;
    return name.split(RegExp(r'\s+')).first;
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) return const WelcomeScreen();

    if (_recovery) {
      if (!_urlCleaned) {
        _urlCleaned = true;
        replaceBrowserUrl(appBaseUrl());
      }
      return NewPasswordScreen(
        onDone: () {
          setState(() => _recovery = false);
          _loadProfile();
        },
      );
    }

    final profile = _profile;
    if (profile == null) {
      return AppPage(
        child: Center(
          child: _profileError == null
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ErrorLine(_profileError!),
                    const SizedBox(height: 16),
                    AppButton(label: 'Reintentar', onPressed: _loadProfile),
                    const SizedBox(height: 8),
                    AppButton(
                      label: 'Cerrar sesión',
                      style: AppButtonStyle.ghost,
                      onPressed: () => const AuthService().signOut(),
                    ),
                  ],
                ),
        ),
      );
    }

    final termsAccepted = profile['terms_version'] != null;
    if (!termsAccepted || profile['is_adult_confirmed'] != true) {
      return AcceptTermsScreen(
        firstName: _firstName,
        termsAlreadyAccepted: termsAccepted,
        onAccepted: _loadProfile,
      );
    }
    if (profile['onboarding_completed'] != true) {
      return OnboardingFlow(onFinished: _loadProfile);
    }
    if (profile['safety_screening_version'] != kScreeningVersion) {
      return OnboardingFlow(key: const ValueKey('screening'), screeningOnly: true, onFinished: _loadProfile);
    }
    return HomeScreen(firstName: _firstName);
  }
}
