// Tests del motor de reglas (HU-6). Ejecutar con:
//   node --test supabase/functions/_shared/nutrition/   (Node 22.18 o superior)
//   deno test supabase/functions/_shared/nutrition/      (también funciona)
import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  type MenuItem,
  type Recipe,
  type UserContext,
  defaultRules,
  resolveRules,
  scoreRecipe,
  validateMenu,
} from './engine.ts';

// ---------- Recetas de prueba ----------
const r = (id: string, groups: Record<string, number>, extra: Partial<Recipe> = {}): Recipe => ({
  id, title: id, groups, allergensReviewed: true, ingredients: [], minutes: 25, costPerPortionEur: 2, ...extra,
});
const lentejas = r('Lentejas con verduras', { legumes: 1, veg: 1, grains: 1, grains_whole: 1 }, { ingredients: ['lentejas', 'zanahoria'] });
const garbanzos = r('Garbanzos con espinacas', { legumes: 1, veg: 1 }, { ingredients: ['garbanzos', 'espinacas'] });
const salmon = r('Salmón con verduras', { fish: 1, fish_oily: 1, veg: 1 }, { allergens: ['fish'] });
const merluza = r('Merluza al horno', { fish: 1, veg: 1, tubers: 1 }, { allergens: ['fish'] });
const pollo = r('Pollo con ensalada', { meat_white: 1, veg: 1, grains: 1, grains_whole: 1 });
const tortilla = r('Tortilla con ensalada', { eggs: 2, veg: 1, tubers: 1 }, { allergens: ['eggs'] });
const tofu = r('Tofu salteado', { legumes: 1, veg: 1, grains: 1, grains_whole: 1, nuts: 1 }, { allergens: ['soy'] });
const ternera = r('Ternera guisada', { meat_red: 1, veg: 1 });
const pizza = r('Pizza precocinada', { grains: 2, dairy: 1, meat_processed: 1 }, { isUltraprocessed: true, allergens: ['gluten', 'milk'] });
const nuecesYogur = r('Yogur con nueces', { dairy: 1, nuts: 1, fruit: 1 }, { allergens: ['milk', 'tree_nuts'] });

/** Semana equilibrada (14 comidas y cenas) que cumple la base de rules_v0.1. */
function balancedWeek(): MenuItem[] {
  const plan: Recipe[] = [
    lentejas, salmon, pollo, tortilla, garbanzos, merluza, tofu,
    salmon, lentejas, pollo, garbanzos, merluza, tofu, tortilla,
  ];
  const week: MenuItem[] = [];
  plan.forEach((recipe, k) => week.push({ day: Math.floor(k / 2) + 1, meal: k % 2 === 0 ? 'lunch' : 'dinner', recipe }));
  return week;
}
const base: UserContext = { goal: 'eat_healthier', safetyMode: 'standard', diets: ['omnivore'] };
const ids = (res: ReturnType<typeof validateMenu>) => res.violations.map((v) => v.ruleId);

// ---------- La semana de referencia ----------
test('semana equilibrada: sin violaciones de la base (salvo frutos secos, que se cubren en la merienda)', () => {
  const res = validateMenu(balancedWeek(), base);
  assert.equal(res.ok, true);
  assert.deepEqual(ids(res).filter((x) => !['nuts_min'].includes(x)), []);
});

// ---------- Una prueba por regla del JSON ----------
test('veg_each_main: verdura en al menos 12 de 14', () => {
  const week = balancedWeek();
  for (const k of [0, 1, 2]) week[k] = { ...week[k], recipe: r(`sinverdura${k}`, { legumes: 1 }) };
  assert.ok(ids(validateMenu(week, base)).includes('veg_each_main'));
});

test('fruit_daily: solo se exige el mínimo en días completos; el máximo siempre', () => {
  const week = balancedWeek();
  assert.ok(!ids(validateMenu(week, base)).includes('fruit_daily')); // sin desayunos: no se evalúa el mínimo
  const full = [...week, { day: 1, meal: 'breakfast' as const, recipe: r('Tostada', { grains: 1 }) }];
  assert.ok(ids(validateMenu(full, base)).includes('fruit_daily'));
  const tooMuch = [...week, { day: 2, meal: 'snack' as const, recipe: r('Macedonia', { fruit: 4 }) }];
  assert.ok(ids(validateMenu(tooMuch, base)).includes('fruit_daily'));
});

test('legumes_min, fish_min y fish_oily_min', () => {
  const week = balancedWeek().map((i) =>
    i.recipe.groups.legumes || i.recipe.groups.fish ? { ...i, recipe: pollo } : i);
  const v = ids(validateMenu(week, base));
  for (const id of ['legumes_min', 'fish_min', 'fish_oily_min']) assert.ok(v.includes(id), id);
});

test('eggs_max (hard): más de 4 huevos', () => {
  const week = balancedWeek();
  week[0] = { ...week[0], recipe: tortilla };
  week[4] = { ...week[4], recipe: tortilla };
  week[6] = { ...week[6], recipe: tortilla }; // 4 tortillas × 2 huevos
  const res = validateMenu(week, base);
  assert.ok(ids(res).includes('eggs_max'));
  assert.equal(res.ok, false);
});

test('meat_max, meat_red_max y meat_proc_max (hard)', () => {
  const week = balancedWeek();
  week[0] = { ...week[0], recipe: ternera };
  week[4] = { ...week[4], recipe: ternera };
  week[6] = { ...week[6], recipe: pizza };
  week[8] = { ...week[8], recipe: pizza };
  const v = ids(validateMenu(week, base));
  for (const id of ['meat_max', 'meat_red_max', 'meat_proc_max']) assert.ok(v.includes(id), id);
});

test('nuts_min', () => {
  assert.ok(ids(validateMenu(balancedWeek(), base)).includes('nuts_min')); // solo 2 raciones (tofu)
  const week = [...balancedWeek(), { day: 3, meal: 'snack' as const, recipe: nuecesYogur }];
  assert.ok(!ids(validateMenu(week, base)).includes('nuts_min'));
});

test('grains_daily: máximo diario', () => {
  const week = [...balancedWeek(), { day: 1, meal: 'snack' as const, recipe: r('Bocadillo grande', { grains: 6 }) }];
  assert.ok(ids(validateMenu(week, base)).includes('grains_daily'));
});

test('grains_whole_ratio: al menos la mitad integral', () => {
  const week = balancedWeek().map((i) => i.recipe.groups.grains ? { ...i, recipe: r(`${i.recipe.id}-blanco`, { ...i.recipe.groups, grains_whole: 0 }) } : i);
  assert.ok(ids(validateMenu(week, base)).includes('grains_whole_ratio'));
});

test('dairy_max: más de 3 lácteos en un día', () => {
  const week = [...balancedWeek(), { day: 2, meal: 'snack' as const, recipe: r('Batido', { dairy: 4 }) }];
  assert.ok(ids(validateMenu(week, base)).includes('dairy_max'));
});

test('fried_max y ultra_max', () => {
  const week = balancedWeek();
  for (const k of [0, 3, 5]) week[k] = { ...week[k], recipe: r(`frito${k}`, { veg: 1, fish: 1 }, { isFried: true }) };
  week[7] = { ...week[7], recipe: pizza };
  week[9] = { ...week[9], recipe: r('Lasaña precocinada', { grains: 1, veg: 1, dairy: 1 }, { isUltraprocessed: true }) };
  const v = ids(validateMenu(week, base));
  assert.ok(v.includes('fried_max'));
  assert.ok(v.includes('ultra_max'));
});

test('protein_each_main: cada comida y cena con proteína', () => {
  const week = balancedWeek();
  week[3] = { ...week[3], recipe: r('Ensalada verde', { veg: 2 }) };
  assert.ok(ids(validateMenu(week, base)).includes('protein_each_main'));
});

test('repeat_max: más de 2 veces o en dos tomas seguidas', () => {
  const week = balancedWeek();
  week[1] = { ...week[1], recipe: lentejas }; // comida y cena del lunes: seguidas y 3 veces
  const v = validateMenu(week, base).violations.filter((x) => x.ruleId === 'repeat_max');
  assert.ok(v.length >= 2);
});

// ---------- Objetivos, modificadores y dietas ----------
test('lose_weight: ultraprocesados 0 → una pizza precocinada se rechaza', () => {
  const week = balancedWeek();
  week[2] = { ...week[2], recipe: pizza };
  const ctx: UserContext = { ...base, goal: 'lose_weight' };
  const res = validateMenu(week, ctx);
  assert.ok(ids(res).includes('ultra_max'));
  assert.ok(ids(res).includes('meat_proc_max'));
  assert.equal(res.ok, false); // meat_proc_max es hard
  assert.equal(resolveRules(ctx).portionFactor.grains, 0.75);
});

test('lose_weight: verdura pasa a ser hard', () => {
  const rules = resolveRules({ ...base, goal: 'lose_weight' }).rules;
  assert.equal(rules.find((x) => x.id === 'veg_each_main')!.severity, 'hard');
});

test('modo general: el objetivo de perder peso se ignora (sin factores de ración)', () => {
  const resolved = resolveRules({ ...base, goal: 'lose_weight', safetyMode: 'general' });
  assert.equal(resolved.effectiveGoal, 'eat_healthier');
  assert.equal(resolved.portionFactor.grains, undefined);
  assert.equal(resolved.rules.find((x) => x.id === 'ultra_max')!.value, 1);
});

test('gain_muscle sin actividad confirmada → comer más sano; con ella, reglas propias', () => {
  assert.equal(resolveRules({ ...base, goal: 'gain_muscle' }).effectiveGoal, 'eat_healthier');
  const resolved = resolveRules({ ...base, goal: 'gain_muscle', confirmedActivity: true });
  assert.equal(resolved.effectiveGoal, 'gain_muscle');
  assert.equal(resolved.rules.find((x) => x.id === 'legumes_min')!.value, 5);
  assert.ok(resolved.rules.some((x) => x.id === 'protein_breakfast'));
  assert.equal(resolved.rules.find((x) => x.id === 'meat_max')!.value, 3); // el límite de carne se mantiene
});

test('vegano sin pescado no da error en fish_min; carne o huevo sí (hard)', () => {
  const vegan: UserContext = { goal: 'eat_healthier', safetyMode: 'standard', diets: ['vegan'] };
  const week: MenuItem[] = [];
  for (let d = 1; d <= 7; d++) {
    week.push({ day: d, meal: 'lunch', recipe: d % 2 ? lentejas : garbanzos });
    week.push({ day: d, meal: 'dinner', recipe: tofu });
  }
  const res = validateMenu(week, vegan);
  assert.ok(!ids(res).includes('fish_min'));
  assert.ok(!ids(res).includes('fish_oily_min'));
  assert.ok(resolveRules(vegan).notices.includes('vegan_b12'));
  week[0] = { ...week[0], recipe: tortilla };
  const bad = validateMenu(week, vegan);
  assert.equal(bad.ok, false);
  assert.ok(ids(bad).includes('DIET'));
});

test('dietas: en los máximos hard gana el más restrictivo; en el resto manda la dieta', () => {
  const flexi = resolveRules({ ...base, diets: ['flexitarian'] });
  assert.equal(flexi.rules.find((x) => x.id === 'meat_max')!.value, 2);
  const lowCarbMuscle = resolveRules({ ...base, goal: 'gain_muscle', confirmedActivity: true, diets: ['low_carb'] });
  assert.equal(lowCarbMuscle.rules.find((x) => x.id === 'grains_daily')!.max, 3);
  const lowCarbGeneral = resolveRules({ ...base, safetyMode: 'general', diets: ['low_carb'] });
  assert.equal(lowCarbGeneral.rules.find((x) => x.id === 'grains_daily')!.max, 6); // low_carb ignorada en modo general
  const highProtein = resolveRules({ ...base, diets: ['high_protein'] });
  assert.ok(highProtein.rules.some((x) => x.id === 'protein_snack'));
});

test('save_time: hasta 3 repeticiones y cena → comida siguiente permitida; recetas largas avisan', () => {
  const ctx: UserContext = { ...base, modifiers: ['save_time'] };
  const week = balancedWeek();
  week[1] = { ...week[1], recipe: pollo }; // cena del lunes
  week[2] = { ...week[2], recipe: pollo }; // comida del martes (batch)
  const v = validateMenu(week, ctx).violations.filter((x) => x.ruleId === 'repeat_max');
  assert.equal(v.filter((x) => x.actual.includes('seguido')).length, 0);
  const slow = balancedWeek().map((i) => ({ ...i, recipe: { ...i.recipe, minutes: 60 } }));
  assert.ok(ids(validateMenu(slow, ctx)).includes('time_max'));
  assert.ok(!ids(validateMenu(slow, base)).includes('time_max'));
});

test('presupuesto: avisa si se pasa; un presupuesto bajo no rebaja legumes_min', () => {
  const ctx: UserContext = { ...base, modifiers: ['save_money'], budgetEur: 20, householdSize: 2 };
  const res = validateMenu(balancedWeek(), ctx); // 14 × 2 € × 2 personas = 56 €
  assert.ok(ids(res).includes('budget_max'));
  assert.equal(resolveRules(ctx).rules.find((x) => x.id === 'legumes_min')!.value, 4);
});

test('grupo rechazado entero: sin pescado la regla no aplica y se compensa con legumbre', () => {
  const ctx: UserContext = { ...base, rejectedGroups: ['fish'] };
  const resolved = resolveRules(ctx);
  assert.ok(resolved.notApplicable.includes('fish_min'));
  assert.ok(resolved.notApplicable.includes('fish_oily_min'));
  assert.equal(resolved.rules.find((x) => x.id === 'legumes_min')!.value, 5);
  assert.ok(!resolved.rules.find((x) => x.id === 'protein_each_main')!.group!.includes('fish'));
});

// ---------- Seguridad ----------
test('SEC-01: alergia al huevo bloquea una receta con «puede contener trazas de huevo»', () => {
  const ctx: UserContext = { ...base, allergens: ['eggs'] };
  const week = balancedWeek().map((i) => (i.recipe.groups.eggs ? { ...i, recipe: pollo } : i));
  week[0] = { ...week[0], recipe: r('Croquetas de espinacas', { veg: 1, legumes: 1 }, { traces: ['eggs'] }) };
  const res = validateMenu(week, ctx);
  assert.equal(res.ok, false);
  assert.ok(ids(res).includes('SEC-01'));
});

test('SEC-02: la intolerancia excluye lo que la contiene, no las trazas', () => {
  const ctx: UserContext = { ...base, intolerances: ['lactose'] };
  assert.equal(scoreRecipe(r('Crema', { veg: 1, dairy: 1 }, { allergens: ['lactose'] }), ctx), -Infinity);
  assert.notEqual(scoreRecipe(r('Pan', { grains: 1 }, { traces: ['lactose'] }), ctx), -Infinity);
});

test('SEC-03: con alergias, una receta sin alérgenos revisados no se sirve', () => {
  const ctx: UserContext = { ...base, allergens: ['peanuts'] };
  assert.equal(scoreRecipe(r('Receta IA', { veg: 1 }, { allergensReviewed: false }), ctx), -Infinity);
  assert.notEqual(scoreRecipe(r('Receta IA', { veg: 1 }, { allergensReviewed: false }), base), -Infinity);
});

test('SEC-05: exclusiones de embarazo y lactancia', () => {
  const ctx: UserContext = { ...base, safetyMode: 'general', safetyReferral: 'pregnancy' };
  const sushi = r('Sushi', { fish: 1, grains: 1 }, { safetyTags: ['raw_or_undercooked_animal'] });
  assert.equal(scoreRecipe(sushi, ctx), -Infinity);
  assert.notEqual(scoreRecipe(sushi, base), -Infinity);
});

test('ingrediente que no le gusta: excluido (sin tildes ni mayúsculas)', () => {
  const ctx: UserContext = { ...base, disliked: ['Brócoli'] };
  assert.equal(scoreRecipe(r('Pasta', { grains: 1, veg: 1 }, { ingredients: ['brocoli', 'pasta'] }), ctx), -Infinity);
});

// ---------- Puntuación ----------
test('scoreRecipe: favoritos, preferidos, mínimos pendientes y repetición', () => {
  const ctx: UserContext = { ...base, favoriteDishes: ['lentejas con verduras'], preferredIngredients: ['Zanahoria'] };
  const s = scoreRecipe(lentejas, ctx, { pendingGroups: new Set(['legumes']) });
  assert.equal(s, 3 + 1 + 1.5);
  const used = scoreRecipe(lentejas, ctx, { usedRecipeIds: new Set([lentejas.id]), previousProteinGroup: 'legumes' });
  assert.equal(used, 3 + 1 - 2 - 1);
});

test('el JSON cargado es la versión aprobada', () => {
  assert.equal(defaultRules.version, 'rules_v0.1');
  assert.equal(defaultRules.base.rules.length, 17);
});
