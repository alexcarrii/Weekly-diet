import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'onboarding_logic.dart';
import 'onboarding_repository.dart';
import 'onboarding_steps.dart';
import 'preparing_screen.dart';

/// Onboarding de preferencias: 6 pasos + transición "Preparando tu menú".
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key, required this.onFinished, this.editing = false});

  /// Se llama al terminar (tras la pantalla de transición).
  final VoidCallback onFinished;

  /// true = abierto desde "Editar mis preferencias" (permite volver atrás en el paso 1).
  final bool editing;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  static const _total = 6;
  final _repo = const OnboardingRepository();
  final _scroll = ScrollController();

  OnboardingData? _data;
  int _step = 1;
  bool _saving = false;
  bool _preparing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final data = await _repo.load();
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyAuthError(e));
    }
  }

  void _goTo(int step) {
    setState(() {
      _step = step;
      _error = null;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  bool get _canContinue {
    final d = _data!;
    return switch (_step) {
      3 => d.diet != null,
      4 => d.hasAllergies == false || (d.hasAllergies == true && d.allergens.isNotEmpty),
      5 => d.goal != null,
      _ => true,
    };
  }

  Future<void> _next() async {
    final d = _data!;
    if (_step == 4 && d.hasAllergies == true && !d.healthConsent) {
      final continueWithout = await confirmContinueWithoutAllergies(context);
      if (!continueWithout || !mounted) return; // vuelve a la pantalla para dar el permiso
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      switch (_step) {
        case 1:
          await _repo.saveHousehold(d);
        case 2:
          await _repo.saveBudget(d);
        case 3:
          await _repo.saveDiet(d);
        case 4:
          await _repo.saveAllergies(d);
          if (!d.willSaveAllergies) {
            // Sin permiso no se guardan: tampoco se usan para filtrar platos.
            d.allergens.clear();
            if (d.hasAllergies == true) d.hasAllergies = null;
          }
        case 5:
          await _repo.saveGoal(d);
        case 6:
          await _repo.saveTastes(d);
      }
      if (_step < _total) {
        _goTo(_step + 1);
      } else {
        await _finish();
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _skip() async {
    if (_step < _total) {
      _goTo(_step + 1);
      return;
    }
    setState(() => _saving = true);
    try {
      await _finish();
    } catch (e) {
      if (mounted) setState(() => _error = friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _finish() async {
    if (!widget.editing) await _repo.completeOnboarding();
    if (mounted) setState(() => _preparing = true);
  }

  void _back() {
    if (_step > 1) {
      _goTo(_step - 1);
    } else if (widget.editing) {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data == null) {
      return AppPage(
        child: Center(
          child: _error == null
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ErrorLine(_error!),
                    const SizedBox(height: 16),
                    AppButton(label: 'Reintentar', onPressed: _load),
                  ],
                ),
        ),
      );
    }

    if (_preparing) {
      return PreparingScreen(data: data, editing: widget.editing, onDone: widget.onFinished);
    }

    void changed() => setState(() {});
    final Widget body = switch (_step) {
      1 => PeopleStep(data: data, onChanged: changed),
      2 => BudgetStep(data: data, onChanged: changed),
      3 => DietStep(data: data, onChanged: changed),
      4 => AllergiesStep(data: data, onChanged: changed),
      5 => GoalStep(data: data, onChanged: changed),
      _ => TastesStep(data: data, onChanged: changed),
    };
    // El paso 4 no se puede saltar: hay que responder (aunque sea "No, nadie").
    final canSkip = _step != 4;
    final footerNote = switch (_step) {
      4 => null,
      6 => data.tasteSummary,
      _ => 'Podrás cambiarlo cuando quieras en Ajustes.',
    };

    return PopScope(
      canPop: _step == 1 && widget.editing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step > 1) _goTo(_step - 1);
      },
      child: AppPage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StepHeader(
              step: _step,
              total: _total,
              onBack: _step > 1 || widget.editing ? _back : null,
              onSkip: canSkip && !_saving ? _skip : null,
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _scroll,
                padding: const EdgeInsets.only(top: 24, bottom: 20),
                child: body,
              ),
            ),
            if (_error != null) ...[ErrorLine(_error!), const SizedBox(height: 12)],
            if (footerNote != null) ...[
              Text(footerNote, textAlign: TextAlign.center, style: AppText.smallMuted),
              const SizedBox(height: 12),
            ],
            AppButton(
              label: _step == _total ? (widget.editing ? 'Guardar cambios' : 'Crear mi menú') : 'Siguiente',
              loading: _saving,
              onPressed: _canContinue ? _next : null,
            ),
          ],
        ),
      ),
    );
  }
}
