import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Versión de los Términos y la Política de privacidad que acepta el usuario.
/// Al cambiar los textos legales se sube la versión y todos vuelven a aceptarlos.
const kTermsVersion = 'v1.0';

/// Versión del texto de consentimiento de datos de salud (alergias).
const kHealthPolicyVersion = 'v1.0';

const kMinPasswordLength = 8;

SupabaseClient get db => Supabase.instance.client;

/// Dirección de la app sin parámetros ni fragmento (para los enlaces de los emails).
String appBaseUrl() {
  final base = Uri.base;
  return Uri(scheme: base.scheme, host: base.host, port: base.hasPort ? base.port : null, path: base.path)
      .toString();
}

/// La app se abrió desde el enlace de "recuperar contraseña" (versión web).
/// Se marca con ?reset=1 en la dirección a la que vuelve el enlace del email.
bool openedFromPasswordReset() => kIsWeb && Uri.base.queryParameters['reset'] == '1';

class AuthService {
  const AuthService();

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required bool marketingOptIn,
  }) {
    return db.auth.signUp(
      email: email.trim(),
      password: password,
      // El servidor copia estos datos al perfil y pone la fecha de aceptación.
      data: {'terms_version': kTermsVersion, 'marketing_opt_in': marketingOptIn},
      emailRedirectTo: kIsWeb ? appBaseUrl() : null,
    );
  }

  Future<void> signIn({required String email, required String password}) {
    return db.auth.signInWithPassword(email: email.trim(), password: password);
  }

  /// En la web abre la página de Google y vuelve a la app con la sesión iniciada.
  Future<void> signInWithGoogle() async {
    await db.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? appBaseUrl() : null,
    );
  }

  Future<void> sendPasswordReset(String email) {
    final redirect = kIsWeb ? Uri.parse(appBaseUrl()).replace(queryParameters: {'reset': '1'}).toString() : null;
    return db.auth.resetPasswordForEmail(email.trim(), redirectTo: redirect);
  }

  Future<void> resendSignUpEmail(String email) {
    return db.auth.resend(
      type: OtpType.signup,
      email: email.trim(),
      emailRedirectTo: kIsWeb ? appBaseUrl() : null,
    );
  }

  Future<void> updatePassword(String password) async {
    await db.auth.updateUser(UserAttributes(password: password));
  }

  /// Aceptación de términos tras entrar con Google (pantalla A3).
  Future<void> acceptTerms({required bool marketingOptIn}) async {
    final uid = db.auth.currentUser!.id;
    await db
        .from('profiles')
        .update({'terms_version': kTermsVersion, 'marketing_opt_in': marketingOptIn})
        .eq('id', uid);
  }

  Future<void> signOut() => db.auth.signOut();
}

/// Validación de email sencilla (la definitiva la hace Supabase).
bool looksLikeEmail(String value) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());

/// Traduce los errores de Supabase (en inglés) a mensajes claros en español.
String friendlyAuthError(Object error) {
  if (error is AuthException) {
    final msg = error.message.toLowerCase();
    if (error.statusCode == '429' || msg.contains('rate limit') || msg.contains('security purposes')) {
      return 'Demasiados intentos. Espera un minuto y vuelve a probar.';
    }
    if (msg.contains('invalid login credentials')) return 'El email o la contraseña no son correctos.';
    if (msg.contains('already registered') || msg.contains('already been registered')) {
      return 'Ya existe una cuenta con este email. Inicia sesión.';
    }
    if (msg.contains('email not confirmed')) return 'Confirma tu email antes de entrar (revisa tu bandeja de entrada).';
    if (msg.contains('password') && (msg.contains('at least') || msg.contains('weak'))) {
      return 'La contraseña necesita al menos $kMinPasswordLength caracteres.';
    }
    if (msg.contains('same') && msg.contains('password')) return 'La contraseña nueva debe ser distinta de la anterior.';
    if (msg.contains('provider is not enabled') || msg.contains('unsupported provider')) {
      return 'El acceso con Google aún no está activado. Usa tu email de momento.';
    }
    if (msg.contains('expired') || msg.contains('invalid')) return 'El enlace ha caducado. Pide uno nuevo.';
    return error.message;
  }
  if (error is PostgrestException) return 'No se ha podido guardar. Inténtalo de nuevo.';
  final text = error.toString().toLowerCase();
  if (text.contains('socket') || text.contains('network') || text.contains('failed to fetch')) {
    return 'Sin conexión. Revisa tu Internet y vuelve a intentarlo.';
  }
  return 'Algo ha fallado. Inténtalo de nuevo.';
}
