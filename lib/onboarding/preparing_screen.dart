import 'dart:async';

import 'package:flutter/material.dart';

import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'onboarding_logic.dart';

/// Transición · "Preparando tu primer menú…"
/// Las líneas se marcan una a una y después se continúa. La generación real del menú
/// con IA llegará en el siguiente sprint; de momento es una transición visual.
class PreparingScreen extends StatefulWidget {
  const PreparingScreen({super.key, required this.data, required this.onDone, this.editing = false});

  final OnboardingData data;
  final VoidCallback onDone;
  final bool editing;

  @override
  State<PreparingScreen> createState() => _PreparingScreenState();
}

class _PreparingScreenState extends State<PreparingScreen> {
  static const _tick = Duration(milliseconds: 800);
  late final List<String> _items = _buildItems();
  int _done = 0;
  Timer? _timer;

  List<String> _buildItems() {
    final d = widget.data;
    return [
      'Raciones para ${peopleLabel(d.householdSize)}',
      if (d.willSaveAllergies) allergySentence(d.allergens),
      if (d.diet != null && d.diet != 'omnivore') 'Dieta ${kDiets.firstWhere((x) => x.code == d.diet).title.toLowerCase()}',
      if (d.budget != null) 'Dentro de ${d.budget} € a la semana',
    ];
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_tick, (t) {
      if (!mounted) return t.cancel();
      if (_done < _items.length) {
        setState(() => _done++);
      } else {
        t.cancel();
        widget.onDone();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 72,
                height: 72,
                child: CircularProgressIndicator(
                  strokeWidth: 7,
                  color: AppColors.primary,
                  backgroundColor: AppColors.primaryLight,
                  semanticsLabel: 'Cargando',
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              widget.editing ? 'Guardando tus preferencias…' : 'Preparando tu primer menú…',
              style: AppText.hero,
            ),
            const SizedBox(height: 32),
            for (var i = 0; i < _items.length; i++) ...[
              _Line(text: _items[i], done: i < _done),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.text, required this.done});

  final String text;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$text, ${done ? 'hecho' : 'en curso'}',
      excludeSemantics: true,
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? AppColors.primary : null,
              border: done ? null : Border.all(color: AppColors.borderStrong, width: 2),
            ),
            child: done ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppText.body.copyWith(color: done ? AppColors.text : AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}
