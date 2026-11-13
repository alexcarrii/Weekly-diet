// Lógica pura del cribado de seguridad (sin Flutter ni Supabase) para poder probarla con tests.
// Reglas: sprint1/reglas-nutricionales-y-seguridad.md, sección 2.

/// Versión de las preguntas del cribado. Al cambiarlas se sube y todos lo repiten.
const kScreeningVersion = 's_v0.1';

/// Versión del consentimiento de salud que cubre alergias Y cribado.
/// (v1.0 = solo alergias, el texto del paso 4).
const kHealthScreeningPolicyVersion = 'v1.1';

enum SafetyMode { standard, general }

/// Aviso de derivación que se muestra tras el cribado.
enum ReferralMessage { pregnancy, condition, weight, eating }

class ScreeningQuestion {
  const ScreeningQuestion(this.id, this.text);
  final String id;
  final String text;
}

/// S2–S6 (S1, la mayoría de edad, se pregunta al crear la cuenta).
/// Redacción pendiente de validar por el dietista-nutricionista colegiado.
const kScreeningQuestions = [
  ScreeningQuestion('S2', '¿Estás embarazada o en periodo de lactancia?'),
  ScreeningQuestion(
    'S3',
    '¿Tienes alguna enfermedad para la que te hayan indicado una dieta concreta '
        '(por ejemplo, diabetes, enfermedad renal, cardiovascular o digestiva)?',
  ),
  ScreeningQuestion('S4', '¿Tomas alguna medicación que te hayan dicho que se relaciona con lo que comes?'),
  ScreeningQuestion('S5', '¿Te han dicho que tu peso es bajo o has perdido peso sin buscarlo en los últimos meses?'),
  ScreeningQuestion(
    'S6',
    '¿Tu relación con la comida te genera malestar o preocupación (por ejemplo, sentir que pierdes '
        'el control, o necesidad de compensar lo que comes)?',
  ),
];

/// Respuestas vacías (todas sin contestar).
Map<String, bool?> emptyScreeningAnswers() => {for (final q in kScreeningQuestions) q.id: null};

bool allScreeningAnswered(Map<String, bool?> answers) =>
    kScreeningQuestions.every((q) => answers[q.id] != null);

/// Resultado del cribado.
class ScreeningOutcome {
  const ScreeningOutcome({required this.mode, required this.referral, required this.message, required this.store});

  final SafetyMode mode;

  /// 'pregnancy' | 'general' | null (standard). Solo se guarda si [store].
  final String? referral;

  /// Aviso que hay que mostrar (null = ninguno).
  final ReferralMessage? message;

  /// true = hay permiso y se guarda el resultado en health_screening.
  final bool store;
}

/// Calcula el resultado. Las respuestas individuales nunca se guardan.
///  - Cualquier «Sí» → modo general (con derivación).
///  - Todo «No» con permiso → standard.
///  - Sin permiso → general por defecto, sin guardar nada.
/// Prioridad del aviso si hay varios «Sí»: M5 > M2 > M4 > M3.
ScreeningOutcome evaluateScreening(Map<String, bool?> answers, {required bool consent}) {
  bool yes(String id) => answers[id] == true;
  final anyYes = kScreeningQuestions.any((q) => yes(q.id));

  final ReferralMessage? message;
  if (yes('S6')) {
    message = ReferralMessage.eating;
  } else if (yes('S2')) {
    message = ReferralMessage.pregnancy;
  } else if (yes('S5')) {
    message = ReferralMessage.weight;
  } else if (yes('S3') || yes('S4')) {
    message = ReferralMessage.condition;
  } else {
    message = null;
  }

  if (!anyYes && consent) {
    return const ScreeningOutcome(mode: SafetyMode.standard, referral: null, message: null, store: true);
  }
  return ScreeningOutcome(
    mode: SafetyMode.general,
    referral: anyYes ? (yes('S2') ? 'pregnancy' : 'general') : 'general',
    message: message,
    store: consent,
  );
}

SafetyMode safetyModeFromDb(String? value) => value == 'standard' ? SafetyMode.standard : SafetyMode.general;

/// Objetivos que solo se pueden elegir con cribado "standard".
const kGoalsNeedingStandard = {'lose_weight', 'gain_muscle'};

/// Dietas que solo se pueden elegir con cribado "standard" (no aparecen en el paso 3 del MVP).
const kDietsNeedingStandard = {'low_carb', 'high_protein'};

/// Motivo por el que un objetivo está bloqueado, o null si se puede elegir.
/// [onlyMissingConsent] = respondió «No» a todo pero no dio permiso.
String? goalLockedReason(String goal, {required SafetyMode mode, required bool onlyMissingConsent}) {
  if (!kGoalsNeedingStandard.contains(goal) || mode == SafetyMode.standard) return null;
  return onlyMissingConsent
      ? 'Para elegirlo necesitamos tu permiso de datos de salud (paso anterior)'
      : 'No disponible con tus respuestas de salud';
}
