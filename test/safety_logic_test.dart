import 'package:flutter_test/flutter_test.dart';
import 'package:weekly_diet/onboarding/onboarding_logic.dart';
import 'package:weekly_diet/safety/messages.dart';
import 'package:weekly_diet/safety/safety_logic.dart';

Map<String, bool?> answers({Set<String> yes = const {}}) =>
    {for (final q in kScreeningQuestions) q.id: yes.contains(q.id)};

void main() {
  group('Cribado (HU-3)', () {
    test('hay 5 preguntas (S2–S6) y empiezan sin responder', () {
      expect(kScreeningQuestions.map((q) => q.id), ['S2', 'S3', 'S4', 'S5', 'S6']);
      final empty = emptyScreeningAnswers();
      expect(allScreeningAnswered(empty), isFalse);
      expect(allScreeningAnswered(answers()), isTrue);
    });

    test('todo «No» con permiso → standard, se guarda y sin aviso', () {
      final r = evaluateScreening(answers(), consent: true);
      expect(r.mode, SafetyMode.standard);
      expect(r.referral, isNull);
      expect(r.message, isNull);
      expect(r.store, isTrue);
    });

    test('todo «No» sin permiso → general por defecto y no se guarda nada', () {
      final r = evaluateScreening(answers(), consent: false);
      expect(r.mode, SafetyMode.general);
      expect(r.message, isNull);
      expect(r.store, isFalse);
    });

    test('embarazo → general con derivación pregnancy y aviso M2', () {
      final r = evaluateScreening(answers(yes: {'S2'}), consent: true);
      expect(r.mode, SafetyMode.general);
      expect(r.referral, 'pregnancy');
      expect(r.message, ReferralMessage.pregnancy);
    });

    test('enfermedad o medicación → M3; peso → M4', () {
      expect(evaluateScreening(answers(yes: {'S3'}), consent: true).message, ReferralMessage.condition);
      expect(evaluateScreening(answers(yes: {'S4'}), consent: true).message, ReferralMessage.condition);
      expect(evaluateScreening(answers(yes: {'S5'}), consent: true).message, ReferralMessage.weight);
      expect(evaluateScreening(answers(yes: {'S3'}), consent: true).referral, 'general');
    });

    test('varios «Sí»: prioridad M5 > M2 > M4 > M3, y el embarazo se conserva en la derivación', () {
      final all = evaluateScreening(answers(yes: {'S2', 'S3', 'S5', 'S6'}), consent: true);
      expect(all.message, ReferralMessage.eating);
      expect(all.referral, 'pregnancy');
      expect(evaluateScreening(answers(yes: {'S2', 'S5'}), consent: true).message, ReferralMessage.pregnancy);
      expect(evaluateScreening(answers(yes: {'S3', 'S5'}), consent: true).message, ReferralMessage.weight);
    });

    test('con «Sí» y sin permiso se muestra el aviso igualmente, pero no se guarda', () {
      final r = evaluateScreening(answers(yes: {'S6'}), consent: false);
      expect(r.message, ReferralMessage.eating);
      expect(r.store, isFalse);
    });
  });

  group('Objetivos bloqueados (HU-2)', () {
    test('en modo general no se puede perder peso ni ganar músculo', () {
      final d = OnboardingData()
        ..safetyMode = SafetyMode.general
        ..screeningConsent = true
        ..screeningAnswers = answers(yes: {'S3'});
      expect(d.lockedReasonFor('lose_weight'), 'No disponible con tus respuestas de salud');
      expect(d.lockedReasonFor('gain_muscle'), isNotNull);
      expect(d.lockedReasonFor('eat_healthier'), isNull);
      expect(d.lockedReasonFor('maintain_weight'), isNull);
    });

    test('si solo falta el permiso, el motivo lo explica', () {
      final d = OnboardingData()
        ..safetyMode = SafetyMode.general
        ..screeningConsent = false
        ..screeningAnswers = answers();
      expect(d.lockedReasonFor('lose_weight'), contains('permiso'));
    });

    test('en modo standard todo está disponible', () {
      final d = OnboardingData()..safetyMode = SafetyMode.standard;
      for (final g in kGoals) {
        expect(d.lockedReasonFor(g.code), isNull);
      }
    });

    test('se cargan los modificadores y la actividad física guardados', () {
      final d = OnboardingData()
        ..loadFromPreferences({
          'goal': 'gain_muscle',
          'goal_modifiers': ['save_time'],
          'confirmed_physical_activity': true,
        });
      expect(d.goalModifiers, {'save_time'});
      expect(d.confirmedActivity, isTrue);
    });

    test('el permiso v1.0 (solo alergias) no cubre el cribado; v1.1 sí', () {
      final d = OnboardingData()
        ..healthConsent = true
        ..consentVersion = 'v1.0';
      expect(d.hasScreeningConsentOnServer, isFalse);
      d.consentVersion = kHealthScreeningPolicyVersion;
      expect(d.hasScreeningConsentOnServer, isTrue);
    });
  });

  group('Lactosa separada de la leche (HU-7)', () {
    test('hay dos opciones distintas', () {
      final codes = kAllergens.map((a) => a.code);
      expect(codes, containsAll(['milk', 'lactose']));
      expect(allergySentence({'lactose'}), 'Sin lactosa');
    });

    test('la intolerancia a la lactosa también quita la crema de calabaza', () {
      final d = OnboardingData()
        ..diet = 'omnivore'
        ..allergens = {'lactose'};
      expect(d.visibleDishes.map((x) => x.name), isNot(contains('Crema de calabaza')));
    });
  });

  test('tono de los mensajes (SEC-08): sin culpa, prohibiciones ni promesas', () {
    const banned = ['prohibid', 'culpa', 'compensa', 'pecado', 'quemar', 'kilos', 'kcal', 'caloría', 'garantiza'];
    for (final text in SafetyMessages.all) {
      for (final word in banned) {
        expect(text.toLowerCase().contains(word), isFalse, reason: '"$word" en: $text');
      }
    }
  });
}
