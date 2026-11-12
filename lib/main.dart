import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// La URL y la clave pública (anon) llegan al compilar con --dart-define.
// La clave anon es pública por diseño: la seguridad la pone el RLS de la base de datos.
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }
  runApp(const WeeklyDietApp());
}

SupabaseClient get db => Supabase.instance.client;

class WeeklyDietApp extends StatelessWidget {
  const WeeklyDietApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weekly Diet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2E7D32),
        useMaterial3: true,
      ),
      home: supabaseUrl.isEmpty || supabaseAnonKey.isEmpty
          ? const _MissingConfigScreen()
          : const AuthGate(),
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

/// Muestra el acceso o la app según haya sesión.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: db.auth.onAuthStateChange,
      builder: (context, _) {
        final session = db.auth.currentSession;
        return session == null ? const AuthScreen() : const ConnectionCheckScreen();
      },
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isSignUp = true;
  bool _acceptedTerms = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final email = _email.text.trim();
      final password = _password.text;
      if (_isSignUp) {
        if (!_acceptedTerms) {
          throw AuthException('Debes aceptar la política de privacidad y los términos.');
        }
        final res = await db.auth.signUp(
          email: email,
          password: password,
          data: {'display_name': _name.text.trim()},
        );
        if (res.session == null && mounted) {
          setState(() => _error = 'Revisa tu email para confirmar la cuenta.');
        }
      } else {
        await db.auth.signInWithPassword(email: email, password: password);
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Error inesperado: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Escribe tu email para recuperar la contraseña.');
      return;
    }
    try {
      await db.auth.resetPasswordForEmail(email);
      setState(() => _error = 'Te hemos enviado un email para cambiar la contraseña.');
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isSignUp ? 'Crear cuenta' : 'Iniciar sesión')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (_isSignUp)
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nombre'),
                textInputAction: TextInputAction.next,
              ),
            TextField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
            ),
            TextField(
              controller: _password,
              decoration: const InputDecoration(labelText: 'Contraseña'),
              obscureText: true,
            ),
            if (_isSignUp)
              CheckboxListTile(
                value: _acceptedTerms,
                onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
                title: const Text('Acepto la política de privacidad y los términos de uso'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            const SizedBox(height: 16),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_isSignUp ? 'Crear cuenta' : 'Entrar'),
            ),
            TextButton(
              onPressed: () => setState(() {
                _isSignUp = !_isSignUp;
                _error = null;
              }),
              child: Text(_isSignUp ? '¿Ya tienes cuenta? Inicia sesión' : '¿No tienes cuenta? Créala'),
            ),
            if (!_isSignUp)
              TextButton(onPressed: _resetPassword, child: const Text('He olvidado mi contraseña')),
          ],
        ),
      ),
    );
  }
}

class _Check {
  _Check(this.label, this.ok, [this.detail = '']);
  final String label;
  final bool ok;
  final String detail;
}

/// Pantalla temporal del Sprint 1: verifica que la app habla con la base de datos.
class ConnectionCheckScreen extends StatefulWidget {
  const ConnectionCheckScreen({super.key});

  @override
  State<ConnectionCheckScreen> createState() => _ConnectionCheckScreenState();
}

class _ConnectionCheckScreenState extends State<ConnectionCheckScreen> {
  List<_Check> _checks = [];
  int? _householdSize;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _runChecks();
  }

  Future<void> _runChecks() async {
    setState(() => _loading = true);
    final checks = <_Check>[];
    final user = db.auth.currentUser;
    checks.add(_Check('Conectado a Supabase', true));
    checks.add(_Check('Sesión iniciada', user != null, user?.email ?? ''));
    try {
      final profiles = await db.from('profiles').select('id, display_name');
      final own = profiles.where((p) => p['id'] == user?.id).toList();
      checks.add(_Check('Perfil creado', own.length == 1,
          own.isNotEmpty ? (own.first['display_name'] ?? '').toString() : ''));
      checks.add(_Check('Solo veo mi perfil', profiles.length == 1, '${profiles.length} visible(s)'));
    } catch (e) {
      checks.add(_Check('Perfil creado', false, '$e'));
    }
    try {
      final pref = await db.from('preferences').select('household_size').single();
      _householdSize = pref['household_size'] as int?;
      checks.add(_Check('Preferencias leídas', true, 'Personas en casa: $_householdSize'));
    } catch (e) {
      checks.add(_Check('Preferencias leídas', false, '$e'));
    }
    if (mounted) {
      setState(() {
        _checks = checks;
        _loading = false;
      });
    }
  }

  Future<void> _setHousehold(int value) async {
    final uid = db.auth.currentUser!.id;
    await db.from('preferences').update({'household_size': value}).eq('user_id', uid);
    await _runChecks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prueba de conexión'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => db.auth.signOut(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _runChecks,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final c in _checks)
                    ListTile(
                      leading: Icon(
                        c.ok ? Icons.check_circle : Icons.cancel,
                        color: c.ok ? Colors.green : Colors.red,
                      ),
                      title: Text(c.label),
                      subtitle: c.detail.isEmpty ? null : Text(c.detail),
                    ),
                  const Divider(height: 32),
                  Text('Personas en casa', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: (_householdSize ?? 1) > 1 ? () => _setHousehold(_householdSize! - 1) : null,
                        icon: const Icon(Icons.remove),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text('${_householdSize ?? '-'}', style: Theme.of(context).textTheme.headlineSmall),
                      ),
                      IconButton.filledTonal(
                        onPressed: (_householdSize ?? 1) < 12 ? () => _setHousehold((_householdSize ?? 1) + 1) : null,
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
