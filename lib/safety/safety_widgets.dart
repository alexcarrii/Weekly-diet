import 'package:flutter/material.dart';

import '../onboarding/onboarding_logic.dart';
import '../onboarding/onboarding_steps.dart' show StepTitle;
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'messages.dart';
import 'safety_logic.dart';

// ---------------------------------------------------------------------------
// O4c · Unas preguntas sobre tu salud (HU-3). No se puede saltar.
// ---------------------------------------------------------------------------
class ScreeningStep extends StatelessWidget {
  const ScreeningStep({super.key, required this.data, required this.onChanged});

  final OnboardingData data;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final askConsent = !data.hasScreeningConsentOnServer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const StepTitle(
          'Unas preguntas sobre tu salud',
          'Nos ayudan a saber si podemos adaptar los menús a tu objetivo o si es mejor proponerte menús '
              'generales. Tus respuestas no se guardan: solo el resultado, y solo con tu permiso.',
        ),
        const SizedBox(height: 20),
        for (final q in kScreeningQuestions) ...[
          _YesNoQuestion(
            text: q.text,
            value: data.screeningAnswers[q.id],
            onChanged: (v) {
              data.screeningAnswers[q.id] = v;
              onChanged();
            },
          ),
          const SizedBox(height: 16),
        ],
        if (askConsent) ...[
          const SizedBox(height: 4),
          _ScreeningConsentCard(data: data, onChanged: onChanged),
          if (!data.screeningConsent) ...[
            const SizedBox(height: 12),
            const InfoBox(text: SafetyMessages.noConsentGeneral),
          ],
        ] else
          const InfoBox(text: 'Ya nos diste tu permiso para usar datos de salud. Puedes retirarlo en Ajustes > Privacidad.'),
      ],
    );
  }
}

class _YesNoQuestion extends StatelessWidget {
  const _YesNoQuestion({required this.text, required this.value, required this.onChanged});

  final String text;
  final bool? value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: text,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExcludeSemantics(child: Text(text, style: AppText.body)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: PillChip(label: 'No', expand: true, selected: value == false, onTap: () => onChanged(false)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: PillChip(label: 'Sí', expand: true, selected: value == true, onTap: () => onChanged(true)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ScreeningConsentCard extends StatelessWidget {
  const _ScreeningConsentCard({required this.data, required this.onChanged});

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
          // ⚖️ Texto pendiente de revisión por el asesor RGPD.
          const Text(
            'El resultado de estas preguntas es un dato de salud. Con tu permiso guardamos solo si podemos '
            'adaptar los menús a tu objetivo o si te proponemos menús generales, nunca tus respuestas. '
            'No lo compartimos con nadie y puedes retirar el permiso cuando quieras en Ajustes > Privacidad.',
            style: AppText.small,
          ),
          const SizedBox(height: 8),
          CheckRow(
            value: data.screeningConsent,
            onChanged: (v) {
              data.screeningConsent = v;
              onChanged();
            },
            label: const Text(
              'Doy mi consentimiento para que guardéis y uséis mis alergias y el resultado de estas '
              'preguntas para adaptar mis menús.',
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Avisos (HU-4)
// ---------------------------------------------------------------------------

/// Aviso de derivación M2–M5 tras el cribado. Único botón: «Entendido, continuar».
Future<void> showReferralMessage(BuildContext context, ReferralMessage message) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: AppColors.scrim,
    builder: (context) => PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.favorite_border, size: 32, color: AppColors.primary),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(SafetyMessages.forReferral(message), style: AppText.body),
                ),
              ),
              const SizedBox(height: 20),
              AppButton(label: 'Entendido, continuar', onPressed: () => Navigator.pop(context)),
            ],
          ),
        ),
      ),
    ),
  );
}

/// M1 · Aviso para menores de 18. Único botón: «Entendido».
Future<void> showMinorNotice(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: AppColors.scrim,
    builder: (context) => PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: AppColors.surface,
        content: const Text(SafetyMessages.m1Minor, style: AppText.body),
        actions: [
          SizedBox(
            width: double.infinity,
            child: AppButton(label: 'Entendido', onPressed: () => Navigator.pop(context)),
          ),
        ],
      ),
    ),
  );
}

/// Casilla «Tengo 18 años o más» + enlace «Soy menor de 18» (A2 y A3).
class AdultConfirmation extends StatelessWidget {
  const AdultConfirmation({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onMinor,
    this.showError = false,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback onMinor;
  final bool showError;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CheckRow(
          value: value,
          hasError: showError && !value,
          onChanged: onChanged,
          label: const Text('Tengo 18 años o más'),
        ),
        if (showError && !value) ...[
          const SizedBox(height: 8),
          const ErrorLine('Para usar la app tienes que tener 18 años o más'),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: LinkButton(label: 'Soy menor de 18', fontSize: 14, onPressed: onMinor),
        ),
      ],
    );
  }
}

/// Tarjeta fija del Inicio en modo general.
class GeneralModeCard extends StatelessWidget {
  const GeneralModeCard({super.key});

  @override
  Widget build(BuildContext context) => const InfoBox(text: SafetyMessages.generalModeBanner, warning: true);
}
