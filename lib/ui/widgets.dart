import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'theme.dart';

/// Contenedor de pantalla del diseño: fondo crema, márgenes 20 px y ancho máximo
/// (en la versión web de escritorio no se estira a toda la pantalla).
class AppPage extends StatelessWidget {
  const AppPage({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: padding ?? const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Fila superior con flecha de volver (área táctil 44 px).
class TopBar extends StatelessWidget {
  const TopBar({super.key, this.onBack, this.center, this.trailing});

  final VoidCallback? onBack;
  final Widget? center;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: onBack == null
                ? null
                : IconButton(
                    onPressed: onBack,
                    tooltip: 'Volver',
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                    icon: const Icon(Icons.chevron_left, size: 28, color: AppColors.text),
                  ),
          ),
          Expanded(child: Center(child: center)),
          SizedBox(width: 64, child: Align(alignment: Alignment.centerRight, child: trailing)),
        ],
      ),
    );
  }
}

enum AppButtonStyle { primary, outline, google, ghost }

/// Botón de 52 px de alto y radio 12 del diseño.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = AppButtonStyle.primary,
    this.loading = false,
    this.leading,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonStyle style;
  final bool loading;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final (Color bg, Color fg, BorderSide side) = switch (style) {
      AppButtonStyle.primary => (
          enabled ? AppColors.primary : AppColors.border,
          enabled ? Colors.white : AppColors.textMuted,
          BorderSide.none,
        ),
      AppButtonStyle.outline => (
          AppColors.surface,
          enabled ? AppColors.primary : AppColors.textMuted,
          BorderSide(color: enabled ? AppColors.primary : AppColors.border, width: 1.5),
        ),
      AppButtonStyle.google => (
          AppColors.surface,
          AppColors.text,
          const BorderSide(color: AppColors.googleBorder, width: 1.5),
        ),
      AppButtonStyle.ghost => (Colors.transparent, AppColors.textMuted, BorderSide.none),
    };
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: TextButton(
        onPressed: enabled ? onPressed : null,
        style: TextButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: bg,
          disabledForegroundColor: fg,
          side: side,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontFamily: AppFonts.body, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        child: loading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: fg),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: 10)],
                  Flexible(child: Text(label, textAlign: TextAlign.center)),
                ],
              ),
      ),
    );
  }
}

/// Marca provisional del logotipo de Google (círculo discontinuo del diseño).
/// Antes de publicar se sustituye por el logotipo oficial del kit de marca de Google.
class GoogleMarkPlaceholder extends StatelessWidget {
  const GoogleMarkPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.borderStrong, width: 1.5),
      ),
    );
  }
}

/// Enlace de texto verde con área táctil de 44 px.
class LinkButton extends StatelessWidget {
  const LinkButton({super.key, required this.label, required this.onPressed, this.fontSize = 16});

  final String label;
  final VoidCallback? onPressed;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        textStyle: TextStyle(fontFamily: AppFonts.body, fontSize: fontSize, fontWeight: FontWeight.w600),
      ),
      child: Text(label),
    );
  }
}

/// Campo con etiqueta encima, botón "Mostrar" para contraseñas y error debajo.
class LabeledField extends StatefulWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.controller,
    this.isPassword = false,
    this.keyboardType,
    this.helper,
    this.error,
    this.autofillHints,
    this.textInputAction,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final bool isPassword;
  final TextInputType? keyboardType;
  final String? helper;
  final String? error;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  State<LabeledField> createState() => _LabeledFieldState();
}

class _LabeledFieldState extends State<LabeledField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.label, style: AppText.label),
        const SizedBox(height: 6),
        TextField(
          controller: widget.controller,
          obscureText: widget.isPassword && _obscure,
          keyboardType: widget.keyboardType,
          autocorrect: !widget.isPassword && widget.keyboardType != TextInputType.emailAddress,
          enableSuggestions: !widget.isPassword,
          autofillHints: widget.autofillHints,
          textInputAction: widget.textInputAction,
          onSubmitted: widget.onSubmitted,
          style: AppText.body,
          decoration: InputDecoration(
            hintText: null,
            errorText: widget.error == null ? null : '',
            errorStyle: const TextStyle(height: 0, fontSize: 0),
            suffixIcon: widget.isPassword
                ? TextButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      minimumSize: const Size(44, 44),
                      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    child: Text(_obscure ? 'Mostrar' : 'Ocultar'),
                  )
                : null,
          ),
        ),
        if (widget.error != null) ...[
          const SizedBox(height: 6),
          ErrorLine(widget.error!),
        ] else if (widget.helper != null) ...[
          const SizedBox(height: 6),
          Text(widget.helper!, style: AppText.smallMuted),
        ],
      ],
    );
  }
}

/// Mensaje de error rojo con icono (no solo color, por accesibilidad).
class ErrorLine extends StatelessWidget {
  const ErrorLine(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.error_outline, size: 18, color: AppColors.error),
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(message, style: AppText.small.copyWith(color: AppColors.error))),
        ],
      ),
    );
  }
}

/// Casilla con texto a la derecha; toda la fila es pulsable (mín. 44 px).
class CheckRow extends StatelessWidget {
  const CheckRow({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.hasError = false,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget label;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: hasError
                    ? BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.error, width: 2),
                      )
                    : null,
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: Checkbox(
                    value: value,
                    onChanged: (v) => onChanged(v ?? false),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: DefaultTextStyle.merge(style: const TextStyle(fontSize: 14, height: 1.5), child: label),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Texto "He leído y acepto los Términos de uso y la Política de privacidad"
/// con los dos enlaces pulsables.
class LegalText extends StatefulWidget {
  const LegalText({super.key});

  @override
  State<LegalText> createState() => _LegalTextState();
}

class _LegalTextState extends State<LegalText> {
  late final TapGestureRecognizer _terms = TapGestureRecognizer()
    ..onTap = () => showLegalPending(context, 'Términos de uso');
  late final TapGestureRecognizer _privacy = TapGestureRecognizer()
    ..onTap = () => showLegalPending(context, 'Política de privacidad');

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const link = TextStyle(
      color: AppColors.primary,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.primary,
    );
    return Text.rich(
      TextSpan(
        style: AppText.small.copyWith(height: 1.5),
        children: [
          const TextSpan(text: 'He leído y acepto los '),
          TextSpan(text: 'Términos de uso', style: link, recognizer: _terms),
          const TextSpan(text: ' y la '),
          TextSpan(text: 'Política de privacidad', style: link, recognizer: _privacy),
        ],
      ),
    );
  }
}

/// Mientras no existan los textos legales definitivos, se muestra este aviso.
Future<void> showLegalPending(BuildContext context, String title) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: const Text('El texto definitivo se publicará antes del lanzamiento.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido'))],
    ),
  );
}

/// Cabecera de los pasos del onboarding: volver, "Paso n de 6", Saltar y barra de progreso.
class StepHeader extends StatelessWidget {
  const StepHeader({super.key, required this.step, required this.total, this.onBack, this.onSkip});

  final int step;
  final int total;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TopBar(
          onBack: onBack,
          center: Text('Paso $step de $total', style: AppText.label.copyWith(color: AppColors.textMuted)),
          trailing: onSkip == null ? null : LinkButton(label: 'Saltar', onPressed: onSkip),
        ),
        const SizedBox(height: 10),
        Semantics(
          label: 'Paso $step de $total',
          child: ExcludeSemantics(
            child: Row(
              children: [
                for (var i = 1; i <= total; i++) ...[
                  if (i > 1) const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: i <= step ? AppColors.primary : AppColors.border,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Tarjeta de opción única (Dieta, Objetivo).
class ChoiceCard extends StatelessWidget {
  const ChoiceCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
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
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1.5,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.background : AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: AppText.body.copyWith(fontWeight: FontWeight.w600, height: 22 / 16)),
                        const SizedBox(height: 2),
                        Text(subtitle, style: AppText.smallMuted),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _RadioDot(selected: selected),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.primary : null,
        border: selected ? null : Border.all(color: AppColors.borderStrong, width: 1.5),
      ),
      child: selected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
    );
  }
}

/// Píldora seleccionable (alérgenos, platos, ingredientes).
/// [avoid] usa el estilo gris con icono de prohibido de "Prefiero evitar".
class PillChip extends StatelessWidget {
  const PillChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.avoid = false,
    this.expand = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool avoid;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final selColor = avoid ? AppColors.text : AppColors.primary;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? (avoid ? AppColors.avoidBg : AppColors.primaryLight) : AppColors.surface,
        shape: StadiumBorder(
          side: BorderSide(color: selected ? selColor : AppColors.borderStrong, width: selected ? 2 : 1.5),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  if (selected) ...[
                    Icon(avoid ? Icons.block : Icons.check, size: 16, color: selColor),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      style: AppText.small.copyWith(
                        height: 18 / 14,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Píldora discontinua "+ Añadir otro".
class AddPill extends StatelessWidget {
  const AddPill({super.key, required this.onTap, required this.semanticLabel});

  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: CustomPaint(
          painter: _DashedStadiumPainter(),
          child: const ConstrainedBox(
            constraints: BoxConstraints(minHeight: 44),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 16, color: AppColors.primary),
                  SizedBox(width: 6),
                  Text('Añadir otro',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedStadiumPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.height / 2),
    ).deflate(0.75);
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 5), paint);
        distance += 9;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Caja informativa (gris) o de aviso (ámbar).
class InfoBox extends StatelessWidget {
  const InfoBox({super.key, required this.text, this.warning = false});

  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: warning ? AppColors.warningBg : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: warning ? null : Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            warning ? Icons.warning_amber_rounded : Icons.info_outline,
            size: 20,
            color: warning ? AppColors.warningText : AppColors.textMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppText.small.copyWith(color: warning ? AppColors.warningText : AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}
