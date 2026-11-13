import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../safety/safety_logic.dart';
import '../safety/safety_widgets.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'goal_step.dart';
import 'onboarding_logic.dart';
import 'onboarding_repository.dart';
import 'onboarding_steps.dart';
import 'preparing_screen.dart';

/// Pasos del onboarding, en orden. El cribado va justo después de las alergias
/// (comparte el permiso de datos de salud) y antes del objetivo (que depende de él).
enum OnboardingStepId { people, budget, diet, allergies, screening, goal, tastes }

/// Onboarding de preferencias: 7 pasos + transición "Preparando tu menú".
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key, required this.onFinished, this.editing = false, this.screeningOnly = false});

  /// Se llama al terminar (tras la pantalla de transición).
  final VoidCallback onFinished;

  /// true = abierto desde "Editar mis preferencias" (permite volver atrás en el paso 1).
  final bool editing;

  /// true = solo cribado + objetivo (usuarios que terminaron el onboarding antes de que existiera
  /// el cribado, o cuando cambia la versión de las preguntas).
  final bool screeningOnly;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final _repo = const OnboardingRepository();
  final _scroll = ScrollController();

  late final List<OnboardingStepId> _steps = widget.screeningOnly
      ? const [OnboardingStepId.screening, OnboardingStepId.goal]
      : OnboardingStepId.values;

  OnboardingData? _data;
  int _index = 0;
  bool _saving = false;
  bool _preparing = false;
  String? _error;

  OnboardingStepId get _step => _steps[_index];
  bool get _isLast => _index == _steps.length - 1;

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

  void _goTo(int index) {
    setState(() {
      _index = index;
      _error = null;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  bool get _canContinue {
    final d = _data!;
    return switch (_step) {
      OnboardingStepId.diet => d.diet != null,
      OnboardingStepId.allergies => d.hasAllergies == false || (d.hasAllergies == true && d.allergens.isNotEmpty),
      OnboardingStepId.screening => allScreeningAnswered(d.screeningAnswers),
      OnboardingStepId.goal => d.goal != null && d.lockedReasonFor(d.goal!) == null,
      _ => true,
    };
  }

  Future<void> _next() async {
    final d = _data!;
    if (_step == OnboardingStepId.allergies && d.hasAllergies == true && !d.healthConsent) {
      final continueWithout = await confirmContinueWithoutAllergies(context);
      if (!continueWithout || !mounted) return; // vuelve a la pantalla para dar el permiso
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      switch (_step) {
        case OnboardingStepId.people:
          await _repo.saveHousehold(d);
        case OnboardingStepId.budget:
          await _repo.saveBudget(d);
        case OnboardingStepId.diet:
          await _repo.saveDiet(d);
        case OnboardingStepId.allergies:
          await _repo.saveAllergies(d);
          if (!d.willSaveAllergies) {
            // Sin permiso no se guardan: tampoco se usan para filtrar platos.
            d.allergens.clear();
            if (d.hasAllergies == true) d.hasAllergies = null;
          }
        case OnboardingStepId.screening:
          final outcome = await _repo.saveScreening(d);
          if (outcome.message != null && mounted) {
            setState(() => _saving = false);
            await showReferralMessage(context, outcome.message!);
          }
        case OnboardingStepId.goal:
          await _repo.saveGoal(d);
        case OnboardingStepId.tastes:
          await _repo.saveTastes(d);
      }
      if (!_isLast) {
        _goTo(_index + 1);
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
    if (!_isLast) {
      _goTo(_index + 1);
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
    if (widget.screeningOnly) {
      widget.onFinished();
      return;
    }
    if (!widget.editing) await _repo.completeOnboarding();
    if (mounted) setState(() => _preparing = true);
  }

  void _back() {
    if (_index > 0) {
      _goTo(_index - 1);
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
      OnboardingStepId.people => PeopleStep(data: data, onChanged: changed),
      OnboardingStepId.budget => BudgetStep(data: data, onChanged: changed),
      OnboardingStepId.diet => DietStep(data: data, onChanged: changed),
      OnboardingStepId.allergies => AllergiesStep(data: data, onChanged: changed),
      OnboardingStepId.screening => ScreeningStep(data: data, onChanged: changed),
      OnboardingStepId.goal => GoalAndModifiersStep(data: data, onChanged: changed),
      OnboardingStepId.tastes => TastesStep(data: data, onChanged: changed),
    };
    // Alergias y cribado no se pueden saltar: hay que responder.
    final canSkip = _step != OnboardingStepId.allergies && _step != OnboardingStepId.screening;
    final footerNote = switch (_step) {
      OnboardingStepId.allergies || OnboardingStepId.screening => null,
      OnboardingStepId.tastes => data.tasteSummary,
      OnboardingStepId.goal when data.safetyMode == SafetyMode.general => null,
      _ => 'Podrás cambiarlo cuando quieras en Ajustes.',
    };
    final isFirst = _index == 0;

    return PopScope(
      canPop: isFirst && widget.editing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !isFirst) _goTo(_index - 1);
      },
      child: AppPage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StepHeader(
              step: _index + 1,
              total: _steps.length,
              onBack: !isFirst || widget.editing ? _back : null,
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
              label: !_isLast
                  ? 'Siguiente'
                  : widget.screeningOnly
                      ? 'Guardar'
                      : (widget.editing ? 'Guardar cambios' : 'Crear mi menú'),
              loading: _saving,
              onPressed: _canContinue ? _next : null,
            ),
          ],
        ),
      ),
    );
  }
}
