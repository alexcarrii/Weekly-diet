import '../auth/auth_service.dart';
import 'onboarding_logic.dart';

/// Lectura y guardado del onboarding en Supabase. Cada paso se guarda al pulsar
/// "Siguiente", así el usuario puede cerrar la app y seguir donde lo dejó.
class OnboardingRepository {
  const OnboardingRepository();

  String get _uid => db.auth.currentUser!.id;

  Future<OnboardingData> load() async {
    final data = OnboardingData();
    final prefs = await db.from('preferences').select().eq('user_id', _uid).maybeSingle();
    if (prefs != null) data.loadFromPreferences(prefs);

    final consent = await db.from('health_consents').select('granted').eq('user_id', _uid).maybeSingle();
    data.healthConsent = consent?['granted'] == true;

    final allergies = await db.from('user_allergies').select('allergen_code').eq('user_id', _uid);
    data.allergens = {for (final row in allergies) row['allergen_code'] as String};
    if (data.allergens.isNotEmpty) data.hasAllergies = true;
    return data;
  }

  Future<void> _updatePreferences(Map<String, dynamic> values) =>
      db.from('preferences').update(values).eq('user_id', _uid);

  Future<void> saveHousehold(OnboardingData d) => _updatePreferences({'household_size': d.householdSize});

  Future<void> saveBudget(OnboardingData d) => _updatePreferences({'weekly_budget_eur': d.budget});

  Future<void> saveDiet(OnboardingData d) => _updatePreferences({'diets': d.diet == null ? <String>[] : <String>[d.diet!]});

  Future<void> saveGoal(OnboardingData d) => _updatePreferences({'goal': d.goal});

  Future<void> saveTastes(OnboardingData d) => _updatePreferences({
        'favorite_dishes': d.dishesToSave,
        'preferred_ingredients': d.favoritesToSave,
        'disliked_ingredients': d.avoidToSave,
      });

  /// Paso 4. Las alergias son datos de salud: solo se guardan con permiso expreso.
  Future<void> saveAllergies(OnboardingData d) async {
    if (d.willSaveAllergies) {
      // 1) Permiso primero: la base de datos rechaza alergias sin consentimiento vigente.
      await db.from('health_consents').upsert({
        'user_id': _uid,
        'granted': true,
        'policy_version': kHealthPolicyVersion,
      });
      // 2) Sustituye la lista anterior por la nueva.
      await db.from('user_allergies').delete().eq('user_id', _uid);
      await db.from('user_allergies').insert([
        for (final code in d.allergens) {'user_id': _uid, 'allergen_code': code},
      ]);
      return;
    }

    if (d.hasAllergies == false) {
      // "No, nadie": se borran alergias anteriores si las hubiera. El permiso no se toca.
      await db.from('user_allergies').delete().eq('user_id', _uid);
      return;
    }

    // "Sí" pero sin permiso: si había un permiso anterior, se retira
    // (la base de datos borra automáticamente las alergias guardadas).
    await db.from('health_consents').update({'granted': false}).eq('user_id', _uid).eq('granted', true);
  }

  Future<void> completeOnboarding() =>
      db.from('profiles').update({'onboarding_completed': true}).eq('id', _uid);
}
