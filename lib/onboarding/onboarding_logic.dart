// Lógica pura del onboarding (sin Flutter ni Supabase) para poder probarla con tests.

/// Dietas del paso 3. El código coincide con preferences.diets en la base de datos.
class DietOption {
  const DietOption(this.code, this.title, this.subtitle);
  final String code;
  final String title;
  final String subtitle;
}

const kDiets = [
  DietOption('omnivore', 'Como de todo', 'Sin restricciones'),
  DietOption('flexitarian', 'Flexitariana', 'Poca carne'),
  DietOption('pescatarian', 'Pescetariana', 'Sin carne, con pescado'),
  DietOption('vegetarian', 'Vegetariana', 'Sin carne ni pescado'),
  DietOption('vegan', 'Vegana', 'Nada de origen animal'),
];

/// Objetivos del paso 5. El código coincide con preferences.goal.
class GoalOption {
  const GoalOption(this.code, this.title, this.subtitle);
  final String code;
  final String title;
  final String subtitle;
}

const kGoals = [
  GoalOption('eat_healthier', 'Comer más sano', 'Más verdura, legumbre y cocina casera'),
  GoalOption('maintain_weight', 'Mantener mi peso', 'Menús equilibrados, sin contar calorías'),
  GoalOption('lose_weight', 'Perder peso con calma', 'Raciones algo más ligeras, sin dietas extremas'),
  GoalOption('gain_muscle', 'Ganar músculo', 'Más proteína en cada comida'),
];

/// Los 14 alérgenos de la UE (códigos de la tabla public.allergens), en el orden del diseño.
class AllergenOption {
  const AllergenOption(this.code, this.label, this.short);
  final String code;
  final String label;
  final String short; // para frases: "Sin huevos ni sésamo"
}

const kAllergens = [
  AllergenOption('gluten', 'Cereales con gluten', 'gluten'),
  AllergenOption('crustaceans', 'Crustáceos', 'crustáceos'),
  AllergenOption('eggs', 'Huevos', 'huevos'),
  AllergenOption('fish', 'Pescado', 'pescado'),
  AllergenOption('peanuts', 'Cacahuetes', 'cacahuetes'),
  AllergenOption('soy', 'Soja', 'soja'),
  // El diseño une leche y lactosa en una sola opción. Se guarda como "milk",
  // que es lo más estricto (excluye todos los lácteos). Pendiente de validar con el nutricionista.
  AllergenOption('milk', 'Leche (incluida la lactosa)', 'leche'),
  AllergenOption('tree_nuts', 'Frutos de cáscara', 'frutos de cáscara'),
  AllergenOption('celery', 'Apio', 'apio'),
  AllergenOption('mustard', 'Mostaza', 'mostaza'),
  AllergenOption('sesame', 'Sésamo', 'sésamo'),
  AllergenOption('sulphites', 'Sulfitos', 'sulfitos'),
  AllergenOption('lupin', 'Altramuces', 'altramuces'),
  AllergenOption('molluscs', 'Moluscos', 'moluscos'),
];

const _all = {'omnivore', 'flexitarian', 'pescatarian', 'vegetarian', 'vegan'};
const _withMeat = {'omnivore', 'flexitarian'};
const _withFish = {'omnivore', 'flexitarian', 'pescatarian'};
const _vegetarianOk = {'omnivore', 'flexitarian', 'pescatarian', 'vegetarian'};

/// Plato o ingrediente sugerido en el paso 6, con las dietas en las que encaja
/// y los alérgenos que suele llevar.
class CatalogItem {
  const CatalogItem(this.name, this.diets, [this.allergens = const {}]);
  final String name;
  final Set<String> diets;
  final Set<String> allergens;

  bool fits(String? diet, Set<String> userAllergens) =>
      diets.contains(diet ?? 'omnivore') && allergens.intersection(userAllergens).isEmpty;
}

// Etiquetado conservador (si una receta habitual puede llevarlo, se marca).
// PENDIENTE: revisión del nutricionista.
const kDishes = [
  CatalogItem('Lentejas estofadas', _all),
  CatalogItem('Pollo al horno', _withMeat),
  CatalogItem('Paella', _withMeat, {'crustaceans', 'molluscs', 'fish'}),
  CatalogItem('Gazpacho', _all, {'gluten', 'sulphites'}),
  CatalogItem('Merluza en salsa verde', _withFish, {'fish', 'molluscs', 'gluten'}),
  CatalogItem('Crema de calabaza', _vegetarianOk, {'milk'}),
  CatalogItem('Ensalada de garbanzos', _all),
  CatalogItem('Fajitas de pollo', _withMeat, {'gluten'}),
  CatalogItem('Tortilla de patatas', _vegetarianOk, {'eggs'}),
  CatalogItem('Pisto', _all),
  CatalogItem('Salmón al horno', _withFish, {'fish'}),
  CatalogItem('Garbanzos con espinacas', _all),
];

const kFavoriteIngredients = [
  CatalogItem('Pollo', _withMeat),
  CatalogItem('Garbanzos', _all),
  CatalogItem('Tomate', _all),
  CatalogItem('Salmón', _withFish, {'fish'}),
  CatalogItem('Arroz', _all),
  CatalogItem('Calabacín', _all),
  CatalogItem('Espinacas', _all),
  CatalogItem('Setas', _all),
  CatalogItem('Lentejas', _all),
  CatalogItem('Huevo', _vegetarianOk, {'eggs'}),
  CatalogItem('Tofu', _all, {'soy'}),
];

const kAvoidIngredients = [
  'Cilantro',
  'Berenjena',
  'Coliflor',
  'Aceitunas',
  'Picante',
  'Hígado',
  'Pimiento',
];

/// Presupuesto: deslizador de 20 a 300 € en pasos de 5.
const kBudgetMin = 20;
const kBudgetMax = 300;
const kBudgetStep = 5;
const kBudgetPerPerson = 30;

int suggestedBudget(int people) {
  final raw = (kBudgetPerPerson * people).clamp(kBudgetMin, kBudgetMax);
  return (raw / kBudgetStep).round() * kBudgetStep;
}

int clampBudget(num value) {
  final stepped = (value / kBudgetStep).round() * kBudgetStep;
  return stepped.clamp(kBudgetMin, kBudgetMax).toInt();
}

/// "Sin huevos", "Sin huevos ni sésamo", "Sin huevos, apio ni sésamo".
String allergySentence(Iterable<String> codes) {
  final names = [
    for (final a in kAllergens)
      if (codes.contains(a.code)) a.short,
  ];
  if (names.isEmpty) return '';
  if (names.length == 1) return 'Sin ${names.first}';
  return 'Sin ${names.sublist(0, names.length - 1).join(', ')} ni ${names.last}';
}

String peopleLabel(int n) => n == 1 ? '1 persona' : '$n personas';

/// Limpia un ingrediente escrito a mano: sin espacios de más, primera letra en mayúscula, máx. 40 caracteres.
String? cleanCustomItem(String raw) {
  final t = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (t.isEmpty) return null;
  final cut = t.length > 40 ? t.substring(0, 40) : t;
  return cut[0].toUpperCase() + cut.substring(1);
}

/// Todo lo que el usuario elige en el onboarding.
class OnboardingData {
  int householdSize = 2;
  int? budget = suggestedBudget(2); // null = "Sin límite fijo"
  bool budgetTouched = false;
  String? diet;
  bool? hasAllergies; // null = sin responder
  Set<String> allergens = {};
  bool healthConsent = false;
  String? goal;
  Set<String> dishes = {};
  Set<String> favorites = {};
  Set<String> avoid = {};
  List<String> customFavorites = [];
  List<String> customAvoid = [];

  /// Rellena con lo que ya había guardado (si el usuario vuelve a entrar a mitad).
  void loadFromPreferences(Map<String, dynamic> p) {
    final hs = p['household_size'];
    if (hs is int && hs >= 1) householdSize = hs;
    final b = p['weekly_budget_eur'];
    if (b is num) {
      budget = clampBudget(b);
      budgetTouched = true;
    } else {
      budget = suggestedBudget(householdSize);
    }
    final diets = (p['diets'] as List?)?.cast<String>() ?? const [];
    diet = diets.isEmpty ? null : diets.first;
    goal = p['goal'] as String?;
    dishes = {...?(p['favorite_dishes'] as List?)?.cast<String>()};
    final fav = (p['preferred_ingredients'] as List?)?.cast<String>() ?? const [];
    final av = (p['disliked_ingredients'] as List?)?.cast<String>() ?? const [];
    favorites = {...fav};
    avoid = {...av};
    final knownFav = kFavoriteIngredients.map((e) => e.name).toSet();
    customFavorites = [for (final f in fav) if (!knownFav.contains(f)) f];
    customAvoid = [for (final a in av) if (!kAvoidIngredients.contains(a)) a];
  }

  /// Platos e ingredientes visibles según la dieta y las alergias elegidas.
  List<CatalogItem> get visibleDishes => [for (final d in kDishes) if (d.fits(diet, allergens)) d];
  List<CatalogItem> get visibleFavorites =>
      [for (final i in kFavoriteIngredients) if (i.fits(diet, allergens)) i];

  /// Al guardar el paso 6 se descartan selecciones que ya no encajan (p. ej. cambió la dieta).
  List<String> get dishesToSave {
    final visible = visibleDishes.map((d) => d.name).toSet();
    return [for (final d in dishes) if (visible.contains(d)) d];
  }

  List<String> get favoritesToSave {
    final visible = {...visibleFavorites.map((i) => i.name), ...customFavorites};
    return [for (final f in favorites) if (visible.contains(f)) f];
  }

  List<String> get avoidToSave => avoid.toList();

  /// Resumen del paso 6: "3 platos · 2 favoritos · 2 a evitar".
  String get tasteSummary {
    final d = dishesToSave.length;
    final f = favoritesToSave.length;
    final a = avoid.length;
    return '$d ${d == 1 ? 'plato' : 'platos'} · $f ${f == 1 ? 'favorito' : 'favoritos'} · $a a evitar';
  }

  /// Alergias que de verdad se van a guardar (hay que tener permiso).
  bool get willSaveAllergies => hasAllergies == true && allergens.isNotEmpty && healthConsent;
}
