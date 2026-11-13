import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../onboarding/onboarding_flow.dart';
import '../onboarding/onboarding_logic.dart';
import '../onboarding/onboarding_repository.dart';
import '../safety/messages.dart';
import '../safety/safety_logic.dart';
import '../safety/safety_widgets.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// Inicio provisional (Sprint 1): resumen de las preferencias guardadas.
/// La pantalla del menú semanal sustituirá a esta cuando llegue la generación con IA.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.firstName});

  final String? firstName;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  OnboardingData? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await const OnboardingRepository().load();
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyAuthError(e));
    }
  }

  Future<void> _edit() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (routeContext) => OnboardingFlow(editing: true, onFinished: () => Navigator.of(routeContext).pop()),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.firstName;
    final d = _data;
    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TopBar(
            trailing: IconButton(
              tooltip: 'Cerrar sesión',
              icon: const Icon(Icons.logout, color: AppColors.textMuted),
              onPressed: () => const AuthService().signOut(),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 8),
              children: [
                Text(name == null || name.isEmpty ? '¡Todo listo!' : '¡Todo listo, $name!', style: AppText.h1),
                const SizedBox(height: 12),
                const Text(
                  'Tus preferencias están guardadas. Tu primer menú semanal llegará en la próxima versión de la app.',
                  style: AppText.bodyMuted,
                ),
                const SizedBox(height: 24),
                if (_error != null) ErrorLine(_error!),
                if (d == null && _error == null) const Center(child: CircularProgressIndicator()),
                if (d != null && d.safetyMode == SafetyMode.general) ...[
                  const GeneralModeCard(),
                  const SizedBox(height: 16),
                ],
                if (d != null && d.diet == 'vegan') ...[
                  const InfoBox(text: SafetyMessages.veganB12),
                  const SizedBox(height: 16),
                ],
                if (d != null) _Summary(data: d),
              ],
            ),
          ),
          AppButton(label: 'Editar mis preferencias', style: AppButtonStyle.outline, onPressed: _edit),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.data});

  final OnboardingData data;

  @override
  Widget build(BuildContext context) {
    final diet = kDiets.where((x) => x.code == data.diet).map((x) => x.title).firstOrNull;
    final goal = kGoals.where((x) => x.code == data.goal).map((x) => x.title).firstOrNull;
    final modifiers = [for (final m in kGoalModifiers) if (data.goalModifiers.contains(m.code)) m.title];
    final rows = <(String, String)>[
      ('Personas', peopleLabel(data.householdSize)),
      ('Presupuesto', data.budget == null ? 'Sin límite fijo' : '${data.budget} € / semana'),
      ('Dieta', diet ?? 'Sin indicar'),
      ('Alergias', data.allergens.isEmpty ? 'Ninguna guardada' : allergySentence(data.allergens)),
      ('Objetivo', goal ?? 'Sin indicar'),
      ('Además', modifiers.isEmpty ? 'Nada más' : modifiers.join(' · ')),
      ('Gustos', data.tasteSummary),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Column(
        children: [
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 110, child: Text(label, style: AppText.label.copyWith(color: AppColors.textMuted))),
                  Expanded(child: Text(value, style: AppText.small)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
