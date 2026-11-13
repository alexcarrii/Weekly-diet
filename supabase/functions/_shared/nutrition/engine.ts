// =====================================================================
// WEEKLY DIET · Motor de validación de menús (HU-6) · rules_v0.1
// Reglas: sprint1/reglas-nutricionales-y-seguridad.md (secciones 1.5, 2.2 y 3.3).
// TypeScript sin dependencias: funciona en las funciones de Supabase (Deno) y en Node (tests).
// Cambiar una regla = cambiar el JSON, no este código.
// =====================================================================
import defaultRulesJson from './nutrition_rules_v0.1.json' with { type: 'json' };

// ---------- Tipos ----------
export type Severity = 'hard' | 'soft';
export type Meal = 'breakfast' | 'lunch' | 'dinner' | 'snack';

export interface Recipe {
  id: string;
  title: string;
  /** Raciones de cada grupo por porción (recipe_food_groups). Los subgrupos se suman además del padre. */
  groups: Record<string, number>;
  isFried?: boolean;
  isUltraprocessed?: boolean;
  /** Alérgenos que contiene (recipes.allergen_codes). */
  allergens?: string[];
  /** Alérgenos "puede contener" (recipes.trace_allergen_codes). */
  traces?: string[];
  allergensReviewed?: boolean;
  ingredients?: string[];
  /** SEC-05 (recipes.safety_tags). */
  safetyTags?: string[];
  /** prep + cook. */
  minutes?: number;
  costPerPortionEur?: number;
  seasonal?: boolean;
}

export interface MenuItem {
  day: number; // 1 = lunes … 7 = domingo
  meal: Meal;
  recipe: Recipe;
}

export interface UserContext {
  goal: string | null;
  modifiers?: string[];
  diets?: string[];
  confirmedActivity?: boolean;
  /** Sin cribado "standard" = 'general'. */
  safetyMode: 'standard' | 'general';
  safetyReferral?: 'pregnancy' | 'general' | null;
  /** Alérgenos (kind = allergen): exclusión absoluta, trazas incluidas. */
  allergens?: string[];
  /** Intolerancias (lactose, fructose): se excluye lo que las contiene, no las trazas. */
  intolerances?: string[];
  disliked?: string[];
  /** Grupos que el usuario rechaza enteros (p. ej. todo el pescado). */
  rejectedGroups?: string[];
  budgetEur?: number | null;
  householdSize?: number;
  favoriteDishes?: string[];
  preferredIngredients?: string[];
}

export interface Rule {
  id: string;
  op: string;
  scope?: string;
  group?: string | string[];
  flag?: 'is_fried' | 'is_ultraprocessed';
  of?: string;
  value?: number;
  min?: number;
  max?: number;
  target?: number;
  severity: Severity;
  no_consecutive?: boolean;
  [extra: string]: unknown;
}

export interface Violation {
  ruleId: string;
  severity: Severity;
  expected: string;
  actual: string;
  message: string;
  day?: number;
  recipeId?: string;
}

export interface ValidationResult {
  /** true = ninguna violación "hard". Las "soft" se muestran como aviso amable. */
  ok: boolean;
  violations: Violation[];
  /** Reglas que no aplican (p. ej. el usuario rechaza el pescado entero). */
  notApplicable: string[];
  effectiveGoal: string;
}

// deno-lint-ignore no-explicit-any
type RulesFile = any;
export const defaultRules: RulesFile = defaultRulesJson;

// ---------- Utilidades ----------
const MAIN: Meal[] = ['lunch', 'dinner'];
const MEAL_ORDER: Record<Meal, number> = { breakfast: 0, lunch: 1, snack: 2, dinner: 3 };
const groupsOf = (r: Rule): string[] => (r.group == null ? [] : Array.isArray(r.group) ? r.group : [r.group]);
const servingsOf = (recipe: Recipe, groups: string[]) => groups.reduce((s, g) => s + (recipe.groups[g] ?? 0), 0);
const clone = <T>(x: T): T => JSON.parse(JSON.stringify(x));
const fmt = (n: number) => (Number.isInteger(n) ? String(n) : n.toFixed(1));

/** Minúsculas y sin tildes, para comparar ingredientes y platos escritos a mano. */
export function normalize(text: string): string {
  return text.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/\s+/g, ' ').trim();
}

const includesWord = (haystack: string, needle: string) =>
  needle.length > 0 && ` ${normalize(haystack)} `.includes(` ${normalize(needle)} `);

// ---------- Resolución de reglas (base → objetivo → modificadores → dietas) ----------
export interface ResolvedRules {
  effectiveGoal: string;
  rules: Rule[];
  notApplicable: string[];
  portionFactor: Record<string, number>;
  maxMinutes: number | null;
  maxMinutesShare: number;
  batchCooking: boolean;
  respectBudget: boolean;
  notices: string[];
}

const GOALS_NEEDING_STANDARD = new Set(['lose_weight', 'gain_muscle']);
const DIETS_NEEDING_STANDARD = new Set(['low_carb', 'high_protein']);

export function effectiveGoalOf(ctx: UserContext): string {
  const goal = ctx.goal ?? 'eat_healthier';
  if (ctx.safetyMode !== 'standard' && GOALS_NEEDING_STANDARD.has(goal)) return 'eat_healthier';
  if (goal === 'gain_muscle' && !ctx.confirmedActivity) return 'eat_healthier';
  return goal;
}

export function resolveRules(ctx: UserContext, file: RulesFile = defaultRules): ResolvedRules {
  const effectiveGoal = effectiveGoalOf(ctx);
  const byId = new Map<string, Rule>();
  for (const r of file.base.rules as Rule[]) byId.set(r.id, clone(r));

  // Objetivo
  const goalDef = file.goals[effectiveGoal] ?? {};
  for (const o of (goalDef.override ?? []) as Partial<Rule>[]) {
    const current = byId.get(o.id!);
    if (current) byId.set(o.id!, { ...current, ...clone(o) } as Rule);
  }
  for (const a of (goalDef.add ?? []) as Rule[]) byId.set(a.id, clone(a));
  // En modo general no hay factores de ración (ni objetivo de peso/músculo).
  const portionFactor = { ...(ctx.safetyMode === 'standard' ? goalDef.portion_factor : null) ?? file.base.portion_factor };

  // Modificadores
  const modifiers = new Set(ctx.modifiers ?? []);
  let maxMinutes: number | null = null;
  let maxMinutesShare = 1;
  let batchCooking = false;
  if (modifiers.has('save_time')) {
    const t = file.modifiers.save_time;
    maxMinutes = t.max_total_minutes;
    maxMinutesShare = t.max_total_minutes_share;
    batchCooking = true;
    const repeat = byId.get('repeat_max');
    if (repeat) repeat.value = Math.max(repeat.value ?? 0, t.batch_cooking.same_recipe_lte);
  }
  const respectBudget = ctx.budgetEur != null; // con o sin save_money: el presupuesto siempre se respeta

  // Dietas (la dieta manda sobre el objetivo; en los máximos "hard" gana el más restrictivo)
  const notices: string[] = [];
  for (const diet of ctx.diets ?? []) {
    if (ctx.safetyMode !== 'standard' && DIETS_NEEDING_STANDARD.has(diet)) continue;
    const def = file.diets[diet];
    if (!def) continue;
    if (def.notice) notices.push(def.notice);
    for (const [id, v] of Object.entries(def.set ?? {})) {
      const r = byId.get(id);
      if (!r) continue;
      if (typeof v === 'object' && v !== null) {
        Object.assign(r, v);
      } else if (r.op === 'lte' && r.severity === 'hard') {
        r.value = Math.min(r.value ?? Infinity, v as number);
      } else {
        r.value = v as number;
      }
    }
    if (def.apply_rules_from === 'gain_muscle.add') {
      for (const a of (file.goals.gain_muscle.add ?? []) as Rule[]) if (!byId.has(a.id)) byId.set(a.id, clone(a));
    }
  }

  // Grupos rechazados enteros: la regla no aplica y se compensa con equivalentes (sección 3.2)
  const rejected = new Set(ctx.rejectedGroups ?? []);
  const notApplicable: string[] = [];
  const isMinRule = (r: Rule) => r.op === 'gte' || r.op === 'count_meals_with_gte' || r.op === 'between';
  for (const r of byId.values()) {
    const groups = groupsOf(r);
    if (!isMinRule(r) || groups.length === 0) continue;
    const remaining = groups.filter((g) => !rejected.has(g) && !(g === 'fish_oily' && rejected.has('fish')));
    if (remaining.length === 0) notApplicable.push(r.id);
    else if (Array.isArray(r.group)) r.group = remaining;
  }
  const bump = (id: string) => {
    const r = byId.get(id);
    if (r && !notApplicable.includes(id)) r.value = (r.value ?? 0) + 1;
  };
  if (rejected.has('fish')) bump('legumes_min');
  if (rejected.has('legumes')) bump('fish_min');

  return {
    effectiveGoal,
    rules: [...byId.values()].filter((r) => !notApplicable.includes(r.id)),
    notApplicable,
    portionFactor,
    maxMinutes,
    maxMinutesShare,
    batchCooking,
    respectBudget,
    notices,
  };
}

// ---------- Seguridad por receta (HARD: SEC-01, 02, 03, 05, dieta, ingredientes que no le gustan) ----------
const DIET_EXCLUDED_GROUPS: Record<string, string[]> = {
  vegetarian: ['meat_white', 'meat_red', 'meat_processed', 'fish'],
  vegan: ['meat_white', 'meat_red', 'meat_processed', 'fish', 'eggs', 'dairy'],
  pescatarian: ['meat_white', 'meat_red', 'meat_processed'],
};
const PREGNANCY_TAGS = ['raw_or_undercooked_animal', 'raw_milk_cheese', 'liver_or_pate', 'high_mercury_fish', 'alcohol'];

export function checkRecipeSafety(recipe: Recipe, ctx: UserContext): Violation[] {
  const out: Violation[] = [];
  const hard = (ruleId: string, message: string, actual: string): Violation => ({
    ruleId, severity: 'hard', expected: 'no', actual, message, recipeId: recipe.id,
  });
  const contains = new Set(recipe.allergens ?? []);
  const traces = new Set(recipe.traces ?? []);

  for (const a of ctx.allergens ?? []) {
    if (contains.has(a) || traces.has(a)) {
      out.push(hard('SEC-01', `«${recipe.title}» contiene ${a} o puede contener trazas, y lo tienes marcado.`, a));
    }
  }
  for (const i of ctx.intolerances ?? []) {
    if (contains.has(i)) out.push(hard('SEC-02', `«${recipe.title}» lleva ${i}, que tienes marcado como intolerancia.`, i));
  }
  const hasRestrictions = (ctx.allergens?.length ?? 0) + (ctx.intolerances?.length ?? 0) > 0;
  if (hasRestrictions && !recipe.allergensReviewed) {
    out.push(hard('SEC-03', `«${recipe.title}» aún no tiene los alérgenos revisados.`, 'sin revisar'));
  }
  if (ctx.safetyReferral === 'pregnancy') {
    const tags = (recipe.safetyTags ?? []).filter((t) => PREGNANCY_TAGS.includes(t));
    if (tags.length) out.push(hard('SEC-05', `«${recipe.title}» no se recomienda en el embarazo ni en la lactancia.`, tags.join(', ')));
  }
  for (const diet of ctx.diets ?? []) {
    const groups = (DIET_EXCLUDED_GROUPS[diet] ?? []).filter((g) => (recipe.groups[g] ?? 0) > 0);
    if (groups.length) out.push(hard('DIET', `«${recipe.title}» no encaja con tu dieta.`, groups.join(', ')));
  }
  for (const d of ctx.disliked ?? []) {
    if ((recipe.ingredients ?? []).some((ing) => includesWord(ing, d))) {
      out.push(hard('DISLIKED', `«${recipe.title}» lleva ${d}, que prefieres evitar.`, d));
    }
  }
  return out;
}

// ---------- Validación del menú completo ----------
const MESSAGES: Record<string, (expected: string, actual: string) => string> = {
  veg_each_main: (e, a) => `Hay verdura en ${a} de las comidas y cenas; intentamos que esté en ${e}.`,
  fruit_daily: (e, a) => `Ese día hay ${a} raciones de fruta; lo recomendable es ${e}.`,
  legumes_min: (e, a) => `Esta semana hay ${a} platos de legumbre; lo recomendable es ${e} o más. ¿Añadimos unas en otra comida?`,
  fish_min: (e, a) => `Esta semana hay ${a} raciones de pescado; lo recomendable es ${e} o más.`,
  fish_oily_min: () => 'Falta una ración de pescado azul esta semana.',
  eggs_max: (e, a) => `Hay ${a} huevos esta semana; el máximo recomendado es ${e}.`,
  meat_max: (e, a) => `Hay ${a} raciones de carne; el máximo recomendado es ${e}.`,
  meat_red_max: (e, a) => `Hay ${a} raciones de carne roja; el máximo recomendado es ${e}.`,
  meat_proc_max: (e, a) => `Hay ${a} raciones de embutido o carne procesada; el máximo recomendado es ${e}.`,
  nuts_min: (e, a) => `Hay ${a} raciones de frutos secos; lo recomendable es ${e} o más.`,
  grains_daily: (e, a) => `Ese día hay ${a} raciones de cereales; lo recomendable es ${e}.`,
  grains_whole_ratio: (e, a) => `El ${a} de los cereales son integrales; intentamos que sea al menos el ${e}.`,
  dairy_max: (e, a) => `Ese día hay ${a} raciones de lácteos; el máximo recomendado es ${e}.`,
  fried_max: (e, a) => `Hay ${a} fritos esta semana; recomendamos ${e} como máximo.`,
  ultra_max: (e, a) => `Hay ${a} platos precocinados esta semana; recomendamos ${e} como máximo.`,
  protein_each_main: (e, a) => `${a} de ${e} comidas y cenas llevan una fuente de proteína.`,
  protein_breakfast: (e, a) => `${a} de ${e} desayunos llevan proteína.`,
  protein_snack: (e, a) => `${a} de ${e} meriendas llevan proteína.`,
  repeat_max: (e, a) => `Un plato se repite ${a} veces; procuramos que sea ${e} como máximo y no en dos comidas seguidas.`,
  budget_max: (e, a) => `El menú cuesta unos ${a} €, por encima de tu presupuesto de ${e} €.`,
  time_max: (e, a) => `El ${a} de las recetas se hace en 30 minutos o menos; intentamos que sea el ${e}.`,
};
const message = (id: string, expected: string, actual: string) =>
  (MESSAGES[id] ?? ((e: string, a: string) => `Regla ${id}: esperado ${e}, hay ${a}.`))(expected, actual);

export function validateMenu(menu: MenuItem[], ctx: UserContext, file: RulesFile = defaultRules): ValidationResult {
  const resolved = resolveRules(ctx, file);
  const violations: Violation[] = [];
  const push = (r: Rule, expected: string, actual: string, day?: number) =>
    violations.push({ ruleId: r.id, severity: r.severity, expected, actual, message: message(r.id, expected, actual), day });

  // 1) Seguridad de cada plato
  for (const item of menu) violations.push(...checkRecipeSafety(item.recipe, ctx).map((v) => ({ ...v, day: item.day })));

  // 2) Reglas nutricionales
  const days = [...new Set(menu.map((i) => i.day))].sort((a, b) => a - b);
  const itemsIn = (scope: string | undefined) =>
    scope === 'main_meal' ? menu.filter((i) => MAIN.includes(i.meal)) : menu.filter((i) => i.meal === scope);
  const dayIsFull = (d: number) =>
    (['breakfast', 'lunch', 'dinner'] as Meal[]).every((m) => menu.some((i) => i.day === d && i.meal === m));
  const weekTotal = (groups: string[]) => menu.reduce((s, i) => s + servingsOf(i.recipe, groups), 0);

  for (const r of resolved.rules) {
    const groups = groupsOf(r);
    switch (r.op) {
      case 'gte': {
        const total = weekTotal(groups);
        if (total < (r.value ?? 0)) push(r, fmt(r.value!), fmt(total));
        break;
      }
      case 'lte': {
        if (r.scope === 'day') {
          for (const d of days) {
            const t = menu.filter((i) => i.day === d).reduce((s, i) => s + servingsOf(i.recipe, groups), 0);
            if (t > (r.value ?? Infinity)) push(r, fmt(r.value!), fmt(t), d);
          }
        } else {
          const total = r.flag
            ? menu.filter((i) => (r.flag === 'is_fried' ? i.recipe.isFried : i.recipe.isUltraprocessed)).length
            : weekTotal(groups);
          if (total > (r.value ?? Infinity)) push(r, fmt(r.value!), fmt(total));
        }
        break;
      }
      case 'between': {
        // El mínimo diario solo se evalúa en días con desayuno, comida y cena planificados.
        for (const d of days) {
          const t = menu.filter((i) => i.day === d).reduce((s, i) => s + servingsOf(i.recipe, groups), 0);
          const range = `${r.min}–${r.max}`;
          if (t > (r.max ?? Infinity) || (dayIsFull(d) && t < (r.min ?? 0))) push(r, range, fmt(t), d);
        }
        break;
      }
      case 'count_meals_with_gte': {
        const items = itemsIn(r.scope);
        if (items.length === 0 && r.scope !== 'main_meal') break; // no se planifican desayunos/meriendas
        const count = items.filter((i) => servingsOf(i.recipe, groups) > 0).length;
        // Con menos tomas planificadas que la referencia, se exige la parte proporcional.
        const reference = r.scope === 'main_meal' ? file.meals_per_week.main : 7;
        const needed = Math.ceil(((r.value ?? 0) * items.length) / reference);
        if (count < needed) push(r, String(Math.min(r.target ?? r.value ?? 0, items.length)), String(count));
        break;
      }
      case 'ratio_gte': {
        const of = weekTotal([r.of!]);
        if (of > 0) {
          const ratio = weekTotal(groups) / of;
          if (ratio < (r.value ?? 0)) push(r, `${Math.round(r.value! * 100)} %`, `${Math.round(ratio * 100)} %`);
        }
        break;
      }
      case 'same_recipe_lte': {
        const counts = new Map<string, number>();
        for (const i of menu) counts.set(i.recipe.id, (counts.get(i.recipe.id) ?? 0) + 1);
        for (const [, n] of counts) if (n > (r.value ?? Infinity)) push(r, fmt(r.value!), fmt(n));
        if (r.no_consecutive) {
          const mains = itemsIn('main_meal').sort((a, b) => a.day - b.day || MEAL_ORDER[a.meal] - MEAL_ORDER[b.meal]);
          for (let k = 1; k < mains.length; k++) {
            const prev = mains[k - 1];
            const cur = mains[k];
            if (prev.recipe.id !== cur.recipe.id) continue;
            const batch = resolved.batchCooking && prev.meal === 'dinner' && cur.meal === 'lunch' && cur.day === prev.day + 1;
            if (!batch) push(r, 'no seguidas', `«${cur.recipe.title}» seguido`, cur.day);
          }
        }
        break;
      }
    }
  }

  // 3) Presupuesto y tiempo (soft)
  if (resolved.respectBudget) {
    const people = ctx.householdSize ?? 1;
    const cost = menu.reduce((s, i) => s + (i.recipe.costPerPortionEur ?? 0) * people, 0);
    if (cost > (ctx.budgetEur ?? Infinity)) {
      violations.push({ ruleId: 'budget_max', severity: 'soft', expected: fmt(ctx.budgetEur!), actual: cost.toFixed(2),
        message: message('budget_max', fmt(ctx.budgetEur!), cost.toFixed(2)) });
    }
  }
  if (resolved.maxMinutes != null) {
    const mains = itemsIn('main_meal');
    if (mains.length) {
      const share = mains.filter((i) => (i.recipe.minutes ?? Infinity) <= resolved.maxMinutes!).length / mains.length;
      if (share < resolved.maxMinutesShare) {
        const e = `${Math.round(resolved.maxMinutesShare * 100)} %`;
        const a = `${Math.round(share * 100)} %`;
        violations.push({ ruleId: 'time_max', severity: 'soft', expected: e, actual: a, message: message('time_max', e, a) });
      }
    }
  }

  return {
    ok: !violations.some((v) => v.severity === 'hard'),
    violations,
    notApplicable: resolved.notApplicable,
    effectiveGoal: resolved.effectiveGoal,
  };
}

// ---------- Puntuación de recetas candidatas (sección 3.3) ----------
export const DEFAULT_WEIGHTS = {
  favorite: 3.0,
  preferredIngredient: 1.0, // por ingrediente, máximo 3
  helpsPendingMinimum: 1.5,
  usesExpiringInventory: 1.0,
  seasonal: 0.5,
  fitsBudgetOrTime: 0.5,
  alreadyUsedThisWeek: -2.0,
  sameProteinAsPrevious: -1.0,
};
export type Weights = typeof DEFAULT_WEIGHTS;

export interface ScoreState {
  usedRecipeIds?: Set<string>;
  previousProteinGroup?: string | null;
  /** Grupos con mínimos SOFT aún sin cubrir esta semana (p. ej. 'legumes', 'fish'). */
  pendingGroups?: Set<string>;
  /** Ingredientes del inventario que caducan en ≤3 días (normalizados o no). */
  expiringIngredients?: string[];
}

const PROTEIN_GROUPS = ['legumes', 'fish', 'eggs', 'meat_white', 'meat_red', 'dairy'];

export function mainProteinGroup(recipe: Recipe): string | null {
  let best: string | null = null;
  for (const g of PROTEIN_GROUPS) if ((recipe.groups[g] ?? 0) > (best ? recipe.groups[best]! : 0)) best = g;
  return best;
}

/** -Infinity si la receta no pasa los filtros HARD de seguridad. */
export function scoreRecipe(recipe: Recipe, ctx: UserContext, state: ScoreState = {}, w: Weights = DEFAULT_WEIGHTS): number {
  if (checkRecipeSafety(recipe, ctx).length > 0) return -Infinity;
  const ingredients = recipe.ingredients ?? [];
  const isFavorite = (ctx.favoriteDishes ?? []).some(
    (f) => normalize(f) === normalize(recipe.title) || includesWord(recipe.title, f),
  );
  const preferred = (ctx.preferredIngredients ?? []).filter((p) => ingredients.some((i) => includesWord(i, p))).length;
  const helps = [...(state.pendingGroups ?? [])].some((g) => (recipe.groups[g] ?? 0) > 0);
  const expiring = (state.expiringIngredients ?? []).some((e) => ingredients.some((i) => includesWord(i, e)));
  const modifiers = new Set(ctx.modifiers ?? []);
  const fitsTime = modifiers.has('save_time') && (recipe.minutes ?? Infinity) <= 30;
  const fitsMoney = modifiers.has('save_money') && (recipe.costPerPortionEur ?? Infinity) <= 2.5;
  const protein = mainProteinGroup(recipe);

  return (
    (isFavorite ? w.favorite : 0) +
    w.preferredIngredient * Math.min(preferred, 3) +
    (helps ? w.helpsPendingMinimum : 0) +
    (expiring ? w.usesExpiringInventory : 0) +
    (recipe.seasonal ? w.seasonal : 0) +
    (fitsTime || fitsMoney ? w.fitsBudgetOrTime : 0) +
    (state.usedRecipeIds?.has(recipe.id) ? w.alreadyUsedThisWeek : 0) +
    (protein != null && protein === state.previousProteinGroup ? w.sameProteinAsPrevious : 0)
  );
}
