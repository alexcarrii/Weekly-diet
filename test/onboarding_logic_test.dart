import 'package:flutter_test/flutter_test.dart';
import 'package:weekly_diet/onboarding/onboarding_logic.dart';

void main() {
  group('Presupuesto', () {
    test('sugiere 30 € por persona, en pasos de 5 y dentro de 20–300', () {
      expect(suggestedBudget(1), 30);
      expect(suggestedBudget(2), 60);
      expect(suggestedBudget(12), 300); // tope
    });

    test('redondea el deslizador al paso de 5 €', () {
      expect(clampBudget(62.4), 60);
      expect(clampBudget(63), 65);
      expect(clampBudget(5), 20);
      expect(clampBudget(999), 300);
    });
  });

  group('Frase de alergias', () {
    test('une con "ni" en el orden oficial', () {
      expect(allergySentence({'tree_nuts', 'eggs'}), 'Sin huevos ni frutos de cáscara');
      expect(allergySentence({'sesame'}), 'Sin sésamo');
      expect(allergySentence({'sesame', 'eggs', 'celery'}), 'Sin huevos, apio ni sésamo');
      expect(allergySentence(<String>{}), '');
    });
  });

  group('Platos e ingredientes filtrados', () {
    test('vegano no ve carne, pescado, huevo ni lácteos', () {
      final d = OnboardingData()..diet = 'vegan';
      final names = d.visibleDishes.map((x) => x.name);
      expect(names, isNot(contains('Pollo al horno')));
      expect(names, isNot(contains('Salmón al horno')));
      expect(names, isNot(contains('Tortilla de patatas')));
      expect(names, isNot(contains('Crema de calabaza')));
      expect(names, contains('Gazpacho'));
    });

    test('una alergia quita los platos que la contienen', () {
      final d = OnboardingData()
        ..diet = 'omnivore'
        ..allergens = {'gluten'};
      final names = d.visibleDishes.map((x) => x.name);
      expect(names, isNot(contains('Gazpacho')));
      expect(names, isNot(contains('Fajitas de pollo')));
      expect(names, contains('Pollo al horno'));
    });

    test('sin dieta elegida (paso saltado) se trata como "como de todo"', () {
      final d = OnboardingData();
      expect(d.visibleDishes.length, kDishes.length);
    });

    test('al guardar se descartan platos que ya no encajan', () {
      final d = OnboardingData()
        ..dishes = {'Pollo al horno', 'Gazpacho'}
        ..diet = 'vegetarian';
      expect(d.dishesToSave, ['Gazpacho']);
    });
  });

  group('Datos guardados', () {
    test('se cargan las preferencias y los ingredientes escritos a mano', () {
      final d = OnboardingData()
        ..loadFromPreferences({
          'household_size': 3,
          'weekly_budget_eur': 91,
          'diets': ['pescatarian'],
          'goal': 'gain_muscle',
          'favorite_dishes': ['Paella'],
          'preferred_ingredients': ['Tomate', 'Brócoli'],
          'disliked_ingredients': ['Cilantro', 'Nabo'],
        });
      expect(d.householdSize, 3);
      expect(d.budget, 90);
      expect(d.diet, 'pescatarian');
      expect(d.goal, 'gain_muscle');
      expect(d.customFavorites, ['Brócoli']);
      expect(d.customAvoid, ['Nabo']);
      expect(d.favoritesToSave, containsAll(['Tomate', 'Brócoli']));
    });

    test('presupuesto vacío = sugerido según personas', () {
      final d = OnboardingData()..loadFromPreferences({'household_size': 4, 'weekly_budget_eur': null});
      expect(d.budget, 120);
      expect(d.budgetTouched, isFalse);
    });

    test('las alergias solo se guardan con permiso', () {
      final d = OnboardingData()
        ..hasAllergies = true
        ..allergens = {'eggs'};
      expect(d.willSaveAllergies, isFalse);
      d.healthConsent = true;
      expect(d.willSaveAllergies, isTrue);
    });
  });

  test('limpia ingredientes escritos a mano', () {
    expect(cleanCustomItem('  brócoli   tierno '), 'Brócoli tierno');
    expect(cleanCustomItem('   '), isNull);
    expect(cleanCustomItem('a' * 60)!.length, 40);
  });

  test('resumen de gustos', () {
    final d = OnboardingData()
      ..dishes = {'Gazpacho'}
      ..favorites = {'Tomate', 'Arroz'}
      ..avoid = {'Cilantro', 'Hígado'};
    expect(d.tasteSummary, '1 plato · 2 favoritos · 2 a evitar');
  });
}
