import '../auth/auth_service.dart';
import '../safety/safety_logic.dart';
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

    final consent =
        await db.from('health_consents').select('granted, policy_version').eq('user_id', _uid).maybeSingle();
    data.healthConsent = consent?['granted'] == true;
    data.consentVersion = consent?['policy_version'] as String?;
    data.screeningConsent = data.hasScreeningConsentOnServer;

    // Resultado del cribado (dato de salud). Sin fila = modo general.
    final screening =
        await db.from('health_screening').select('safety_mode, safety_referral').eq('user_id', _uid).maybeSingle();
    data.safetyMode = safetyModeFromDb(screening?['safety_mode'] as String?);
    data.safetyReferral = screening?['safety_referral'] as String?;

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

  /// Paso 6. La base de datos rechaza perder peso / ganar músculo sin cribado "standard"
  /// y ganar músculo sin la actividad física confirmada.
  Future<void> saveGoal(OnboardingData d) => _updatePreferences({
        'goal': d.goal,
        'goal_modifiers': [for (final m in kGoalModifiers) if (d.goalModifiers.contains(m.code)) m.code],
        'confirmed_physical_activity': d.goal == 'gain_muscle' && d.confirmedActivity,
      });

  Future<void> saveTastes(OnboardingData d) => _updatePreferences({
        'favorite_dishes': d.dishesToSave,
        'preferred_ingredients': d.favoritesToSave,
        'disliked_ingredients': d.avoidToSave,
      });

  /// Paso 4. Las alergias son datos de salud: solo se guardan con permiso expreso.
  Future<void> saveAllergies(OnboardingData d) async {
    if (d.willSaveAllergies) {
      // 1) Permiso primero: la base de datos rechaza alergias sin consentimiento vigente.
      // Si el permiso guardado ya cubre el cribado (v1.1), no se rebaja a v1.0.
      final version = d.hasScreeningConsentOnServer ? kHealthScreeningPolicyVersion : kHealthPolicyVersion;
      await db.from('health_consents').upsert({
        'user_id': _uid,
        'granted': true,
        'policy_version': version,
      });
      d.consentVersion = version;
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
    // (la base de datos borra automáticamente las alergias y el resultado del cribado).
    await db.from('health_consents').update({'granted': false}).eq('user_id', _uid).eq('granted', true);
    d.consentVersion = null;
    d.screeningConsent = false;
    d.safetyMode = SafetyMode.general;
    d.safetyReferral = null;
  }

  /// Paso 5 · Cribado de seguridad. Solo se guarda el RESULTADO y solo con permiso (v1.1).
  /// Las respuestas individuales no salen nunca del móvil.
  Future<ScreeningOutcome> saveScreening(OnboardingData d) async {
    final outcome = evaluateScreening(d.screeningAnswers, consent: d.screeningConsent);
    if (outcome.store) {
      // 1) Permiso primero: la base de datos rechaza el cribado sin consentimiento vigente.
      await db.from('health_consents').upsert({
        'user_id': _uid,
        'granted': true,
        'policy_version': kHealthScreeningPolicyVersion,
      });
      d.healthConsent = true;
      d.consentVersion = kHealthScreeningPolicyVersion;
      // 2) Resultado (la fecha la pone el servidor).
      await db.from('health_screening').upsert({
        'user_id': _uid,
        'safety_mode': outcome.mode.name,
        'safety_referral': outcome.referral,
        'screening_version': kScreeningVersion,
      });
    } else {
      // Sin permiso no se guarda nada: si había un resultado anterior se borra (→ modo general).
      await db.from('health_screening').delete().eq('user_id', _uid);
    }
    // Que el cribado se ha respondido (no su resultado) no es dato de salud.
    await db.from('profiles').update({'safety_screening_version': kScreeningVersion}).eq('id', _uid);

    d.safetyMode = outcome.mode;
    d.safetyReferral = outcome.store ? outcome.referral : null;
    if (outcome.mode == SafetyMode.general && kGoalsNeedingStandard.contains(d.goal)) {
      // La base de datos ya lo ha quitado; se refleja también en pantalla.
      d.goal = null;
      d.confirmedActivity = false;
    }
    return outcome;
  }

  Future<void> completeOnboarding() =>
      db.from('profiles').update({'onboarding_completed': true}).eq('id', _uid);
}
