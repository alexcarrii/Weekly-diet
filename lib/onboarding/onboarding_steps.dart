import 'package:flutter/material.dart';

import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'onboarding_logic.dart';

/// Título y subtítulo de cada paso.
class StepTitle extends StatelessWidget {
  const StepTitle(this.title, this.subtitle, {super.key});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(header: true, child: Text(title, style: AppText.h1)),
        const SizedBox(height: 12),
        Text(subtitle, style: AppText.bodyMuted),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// O1 · Personas
// ---------------------------------------------------------------------------
class PeopleStep extends StatelessWidget {
  const PeopleStep({super.key, required this.data, required this.onChanged});

  final OnboardingData data;
  final VoidCallback onChanged;

  void _set(int value) {
    data.householdSize = value.clamp(1, 12);
    if (!data.budgetTouched && data.budget != null) data.budget = suggestedBudget(data.householdSize);
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final n = data.householdSize;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const StepTitle('¿Para cuántas personas cocinas?', 'Así ajustamos las raciones y la lista de la compra.'),
        const SizedBox(height: 120),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _RoundButton(icon: Icons.remove, tooltip: 'Quitar una persona', onPressed: n > 1 ? () => _set(n - 1) : null),
            const SizedBox(width: 36),
            SizedBox(
              width: 72,
              child: Semantics(
                liveRegion: true,
                label: peopleLabel(n),
                child: ExcludeSemantics(
                  child: Text(
                    '$n',
                    textAlign: TextAlign.center,
                    style: AppText.hero.copyWith(fontSize: 64, height: 72 / 64),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 36),
            _RoundButton(icon: Icons.add, tooltip: 'Añadir una persona', onPressed: n < 12 ? () => _set(n + 1) : null),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          n == 1 ? 'persona' : 'personas',
          textAlign: TextAlign.center,
          style: AppText.bodyMuted.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return SizedBox(
      width: 64,
      height: 64,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: AppColors.surface,
          disabledBackgroundColor: AppColors.surface,
          side: BorderSide(color: enabled ? AppColors.primary : AppColors.border, width: 2),
        ),
        icon: Icon(icon, size: 26, color: enabled ? AppColors.primary : AppColors.borderStrong),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// O2 · Presupuesto
// ---------------------------------------------------------------------------
class BudgetStep extends StatelessWidget {
  const BudgetStep({super.key, required this.data, required this.onChanged});

  final OnboardingData data;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final budget = data.budget;
    final noLimit = budget == null;
    final people = data.householdSize;
    final suggested = suggestedBudget(people);
    String hint = '';
    if (budget != null) {
      final perPerson = (budget / people).round();
      hint = '≈ $perPerson € por persona';
      if (budget == suggested) hint += ' · sugerido para ${peopleLabel(people)}';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const StepTitle(
          '¿Cuánto quieres gastar en la compra a la semana?',
          'Es orientativo: lo usamos para proponerte recetas y productos que encajen.',
        ),
        const SizedBox(height: 72),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              noLimit ? 'Sin límite' : '$budget €',
              style: AppText.hero.copyWith(
                fontSize: noLimit ? 40 : 56,
                height: 64 / 56,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (!noLimit) ...[
              const SizedBox(width: 8),
              Text('/ semana', style: AppText.bodyMuted.copyWith(fontSize: 18, fontWeight: FontWeight.w600)),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(noLimit ? 'Te propondremos menús sin tope de gasto.' : hint,
            textAlign: TextAlign.center, style: AppText.bodyMuted),
        const SizedBox(height: 20),
        const Text('Presupuesto semanal', style: AppText.label),
        SizedBox(
          height: 44,
          child: Slider(
            value: (budget ?? suggested).toDouble(),
            min: kBudgetMin.toDouble(),
            max: kBudgetMax.toDouble(),
            divisions: (kBudgetMax - kBudgetMin) ~/ kBudgetStep,
            label: '${budget ?? suggested} €',
            semanticFormatterCallback: (v) => '${v.round()} euros por semana',
            onChanged: noLimit
                ? null
                : (v) {
                    data.budget = clampBudget(v);
                    data.budgetTouched = true;
                    onChanged();
                  },
          ),
        ),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$kBudgetMin €', style: AppText.smallMuted),
            Text('$kBudgetMax €', style: AppText.smallMuted),
          ],
        ),
        const SizedBox(height: 20),
        Center(
          child: PillChip(
            label: 'Sin límite fijo',
            selected: noLimit,
            onTap: () {
              data.budget = noLimit ? suggested : null;
              data.budgetTouched = true;
              onChanged();
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// O3 · Dieta  /  O5 · Objetivo
// ---------------------------------------------------------------------------
const _dietIcons = {
  'omnivore': Icons.restaurant,
  'flexitarian': Icons.eco_outlined,
  'pescatarian': Icons.set_meal_outlined,
  'vegetarian': Icons.local_florist_outlined,
  'vegan': Icons.spa_outlined,
};

class DietStep extends StatelessWidget {
  const DietStep({super.key, required this.data, required this.onChanged});

  final OnboardingData data;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const StepTitle('¿Cómo comes?', 'Elige una.'),
        const SizedBox(height: 20),
        for (final d in kDiets) ...[
          ChoiceCard(
            icon: _dietIcons[d.code] ?? Icons.restaurant,
            title: d.title,
            subtitle: d.subtitle,
            selected: data.diet == d.code,
            onTap: () {
              data.diet = d.code;
              onChanged();
            },
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

const _goalIcons = {
  'eat_healthier': Icons.favorite_border,
  'maintain_weight': Icons.balance,
  'lose_weight': Icons.trending_down,
  'gain_muscle': Icons.fitness_center,
};

class GoalStep extends StatelessWidget {
  const GoalStep({super.key, required this.data, required this.onChanged});

  final OnboardingData data;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const StepTitle('¿Qué te gustaría conseguir?', 'Ajustaremos los platos y las raciones a lo que buscas.'),
        const SizedBox(height: 20),
        for (final g in kGoals) ...[
          ChoiceCard(
            icon: _goalIcons[g.code] ?? Icons.flag_outlined,
            title: g.title,
            subtitle: g.subtitle,
            selected: data.goal == g.code,
            onTap: () {
              data.goal = g.code;
              onChanged();
            },
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// O4 · Alergias (dato de salud: requiere permiso expreso)
// ---------------------------------------------------------------------------
class AllergiesStep extends StatelessWidget {
  const AllergiesStep({super.key, required this.data, required this.onChanged});

  final OnboardingData data;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final yes = data.hasAllergies == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const StepTitle(
          '¿Alguien en casa tiene alergias o intolerancias?',
          'Las tendremos en cuenta en todas las recetas.',
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _ToggleBox(
                label: 'No, nadie',
                selected: data.hasAllergies == false,
                onTap: () {
                  data.hasAllergies = false;
                  onChanged();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ToggleBox(
                label: 'Sí',
                selected: yes,
                onTap: () {
                  data.hasAllergies = true;
                  onChanged();
                },
              ),
            ),
          ],
        ),
        if (yes) ...[
          const SizedBox(height: 20),
          const Text('Marca todas las que haya (los 14 alérgenos de la UE)', style: AppText.label),
          const SizedBox(height: 10),
          for (var i = 0; i < kAllergens.length; i += 2) ...[
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _allergenChip(kAllergens[i])),
                  const SizedBox(width: 8),
                  Expanded(child: i + 1 < kAllergens.length ? _allergenChip(kAllergens[i + 1]) : const SizedBox()),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 12),
          _ConsentCard(data: data, onChanged: onChanged),
          const SizedBox(height: 20),
          const InfoBox(text: 'Revisa siempre la etiqueta: los fabricantes pueden cambiar los ingredientes.', warning: true),
        ],
      ],
    );
  }

  Widget _allergenChip(AllergenOption a) {
    return PillChip(
      label: a.label,
      expand: true,
      selected: data.allergens.contains(a.code),
      onTap: () {
        if (!data.allergens.remove(a.code)) data.allergens.add(a.code);
        onChanged();
      },
    );
  }
}

class _ToggleBox extends StatelessWidget {
  const _ToggleBox({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: Material(
        color: selected ? AppColors.primaryLight : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: selected ? AppColors.primary : AppColors.borderStrong, width: selected ? 2 : 1.5),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 52,
            child: Center(child: Text(label, style: AppText.body.copyWith(fontWeight: FontWeight.w600))),
          ),
        ),
      ),
    );
  }
}

class _ConsentCard extends StatelessWidget {
  const _ConsentCard({required this.data, required this.onChanged});

  final OnboardingData data;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_outlined, size: 22, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(child: Text('Tu permiso para usar estos datos', style: AppText.h2)),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Las alergias e intolerancias son datos de salud. Para tenerlas en cuenta en tus menús '
            'necesitamos tu permiso expreso. Solo las usamos para eso, no las compartimos con '
            'supermercados ni con terceros, y puedes retirar el permiso cuando quieras en '
            'Ajustes > Privacidad.',
            style: AppText.small,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: LinkButton(label: 'Más información', fontSize: 14, onPressed: () => _showMoreInfo(context)),
          ),
          CheckRow(
            value: data.healthConsent,
            onChanged: (v) {
              data.healthConsent = v;
              onChanged();
            },
            label: const Text(
              'Doy mi consentimiento para que guardéis y uséis estas alergias e intolerancias '
              'para adaptar mis menús.',
            ),
          ),
        ],
      ),
    );
  }

  void _showMoreInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cómo tratamos tus alergias'),
        content: const SingleChildScrollView(
          child: Text(
            '• Para qué: solo para quitar de tus menús y de tu lista de la compra los alimentos que no puedes tomar.\n\n'
            '• Base legal: tu consentimiento expreso (art. 9.2.a del RGPD).\n\n'
            '• Dónde: en servidores de la Unión Europea, protegidos para que solo tu cuenta pueda verlos.\n\n'
            '• Con quién: no las compartimos con supermercados, anunciantes ni terceros.\n\n'
            '• Cuánto tiempo: hasta que retires el permiso o borres tu cuenta; en ese momento se eliminan.\n\n'
            '• Tus derechos: puedes ver, corregir o borrar estos datos y retirar el permiso en cualquier momento, '
            'sin que afecte al resto de la app.',
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido'))],
      ),
    );
  }
}

/// O4 · Diálogo "¿Seguimos sin tus alergias?". Devuelve true si el usuario sigue sin guardarlas.
Future<bool> confirmContinueWithoutAllergies(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: AppColors.scrim,
    builder: (context) => Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('¿Seguimos sin tus alergias?', style: AppText.h1.copyWith(fontSize: 20, height: 26 / 20)),
            const SizedBox(height: 12),
            const Text(
              'Sin tu permiso no podemos guardarlas, así que los menús no las tendrán en cuenta.',
              style: AppText.bodyMuted,
            ),
            const SizedBox(height: 20),
            AppButton(label: 'Dar mi permiso', onPressed: () => Navigator.pop(context, false)),
            const SizedBox(height: 4),
            AppButton(
              label: 'Seguir sin guardarlas',
              style: AppButtonStyle.ghost,
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}

// ---------------------------------------------------------------------------
// O6 · Gustos (opcional)
// ---------------------------------------------------------------------------
class TastesStep extends StatelessWidget {
  const TastesStep({super.key, required this.data, required this.onChanged});

  final OnboardingData data;
  final VoidCallback onChanged;

  void _toggle(Set<String> set, String value) {
    if (!set.remove(value)) set.add(value);
    onChanged();
  }

  Future<void> _addCustom(BuildContext context, {required bool avoid}) async {
    final value = await _askForIngredient(
      context,
      avoid ? 'Ingrediente que prefieres evitar' : 'Otro ingrediente favorito',
    );
    if (value == null) return;
    if (avoid) {
      if (!kAvoidIngredients.contains(value) && !data.customAvoid.contains(value)) data.customAvoid.add(value);
      data.avoid.add(value);
    } else {
      final known = kFavoriteIngredients.any((i) => i.name == value);
      if (!known && !data.customFavorites.contains(value)) data.customFavorites.add(value);
      data.favorites.add(value);
    }
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final dishes = data.visibleDishes;
    final favorites = [...data.visibleFavorites.map((i) => i.name), ...data.customFavorites];
    final avoid = [...kAvoidIngredients, ...data.customAvoid];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const StepTitle('¿Qué te gusta comer?', 'Opcional: así te propondremos más de lo que te gusta.'),
        const SizedBox(height: 24),
        Semantics(header: true, child: const Text('Platos que te gustan', style: AppText.h2)),
        const SizedBox(height: 10),
        const Text('Solo te mostramos platos que encajan con tu dieta y tus alergias.', style: AppText.smallMuted),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final d in dishes)
              PillChip(label: d.name, selected: data.dishes.contains(d.name), onTap: () => _toggle(data.dishes, d.name)),
          ],
        ),
        const SizedBox(height: 28),
        Semantics(header: true, child: const Text('Ingredientes favoritos', style: AppText.h2)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final name in favorites)
              PillChip(label: name, selected: data.favorites.contains(name), onTap: () => _toggle(data.favorites, name)),
            AddPill(
              semanticLabel: 'Añadir otro ingrediente favorito',
              onTap: () => _addCustom(context, avoid: false),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Semantics(header: true, child: const Text('Prefiero evitar', style: AppText.h2)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final name in avoid)
              PillChip(
                label: name,
                avoid: true,
                selected: data.avoid.contains(name),
                onTap: () => _toggle(data.avoid, name),
              ),
            AddPill(
              semanticLabel: 'Añadir otro ingrediente a evitar',
              onTap: () => _addCustom(context, avoid: true),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const InfoBox(text: 'Los quitaremos de tus menús. Si es por salud, márcalo como alergia en el paso 4.'),
      ],
    );
  }
}

Future<String?> _askForIngredient(BuildContext context, String title) async {
  final value = await showDialog<String>(context: context, builder: (_) => _IngredientDialog(title: title));
  return value == null ? null : cleanCustomItem(value);
}

class _IngredientDialog extends StatefulWidget {
  const _IngredientDialog({required this.title});

  final String title;

  @override
  State<_IngredientDialog> createState() => _IngredientDialogState();
}

class _IngredientDialogState extends State<_IngredientDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 40,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'Por ejemplo: brócoli'),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        TextButton(onPressed: () => Navigator.pop(context, _controller.text), child: const Text('Añadir')),
      ],
    );
  }
}
