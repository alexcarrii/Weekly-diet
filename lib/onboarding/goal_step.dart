import 'package:flutter/material.dart';

import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'onboarding_logic.dart';
import 'onboarding_steps.dart' show StepTitle;

/// Paso 6 · Objetivo nutricional (uno) + «¿Y además…?» (ahorrar dinero / tiempo, opcionales).
/// Sustituye a GoalStep de onboarding_steps.dart (HU-2).
class GoalAndModifiersStep extends StatelessWidget {
  const GoalAndModifiersStep({super.key, required this.data, required this.onChanged});

  final OnboardingData data;
  final VoidCallback onChanged;

  static const _icons = {
    'eat_healthier': Icons.favorite_border,
    'maintain_weight': Icons.balance,
    'lose_weight': Icons.trending_down,
    'gain_muscle': Icons.fitness_center,
  };

  Future<void> _select(BuildContext context, String code) async {
    if (code == 'gain_muscle' && !data.confirmedActivity) {
      final trains = await _askStrengthTraining(context);
      if (trains == null) return;
      if (!trains) {
        if (context.mounted) await _explainGainMuscle(context);
        data.goal = 'eat_healthier';
        data.confirmedActivity = false;
        onChanged();
        return;
      }
      data.confirmedActivity = true;
    }
    data.goal = code;
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const StepTitle('¿Qué buscas con tu alimentación?', 'Elige uno. Ajustaremos los platos y las raciones.'),
        const SizedBox(height: 20),
        for (final g in kGoals) ...[
          _goalCard(context, g),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 18),
        Semantics(header: true, child: const Text('¿Y además…?', style: AppText.h2)),
        const SizedBox(height: 4),
        const Text('Opcional. Puedes elegir los dos.', style: AppText.smallMuted),
        const SizedBox(height: 8),
        for (final m in kGoalModifiers)
          CheckRow(
            value: data.goalModifiers.contains(m.code),
            onChanged: (v) {
              if (v) {
                data.goalModifiers.add(m.code);
              } else {
                data.goalModifiers.remove(m.code);
              }
              onChanged();
            },
            label: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: m.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(text: '\n${m.subtitle}', style: const TextStyle(color: AppColors.textMuted)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _goalCard(BuildContext context, GoalOption g) {
    final locked = data.lockedReasonFor(g.code);
    final card = ChoiceCard(
      icon: locked == null ? (_icons[g.code] ?? Icons.flag_outlined) : Icons.lock_outline,
      title: g.title,
      subtitle: locked ?? g.subtitle,
      selected: locked == null && data.goal == g.code,
      onTap: () => _select(context, g.code),
    );
    if (locked == null) return card;
    return Semantics(
      enabled: false,
      child: IgnorePointer(child: Opacity(opacity: 0.55, child: card)),
    );
  }
}

/// «¿Haces actividad física de fuerza con regularidad?» → true / false / null (cerrado).
Future<bool?> _askStrengthTraining(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Una pregunta rápida'),
      content: const Text('¿Haces actividad física de fuerza con regularidad?', style: AppText.body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sí')),
      ],
    ),
  );
}

Future<void> _explainGainMuscle(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surface,
      content: const Text(
        'Para ganar músculo, la alimentación tiene que ir acompañada de entrenamiento de fuerza. '
        'De momento te proponemos «Comer más sano»; puedes cambiarlo cuando empieces a entrenar.',
        style: AppText.body,
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido'))],
    ),
  );
}
