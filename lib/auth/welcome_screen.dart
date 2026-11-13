import 'package:flutter/material.dart';

import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'auth_service.dart';
import 'sign_in_screen.dart';
import 'sign_up_screen.dart';

/// A1 · Bienvenida
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _googleLoading = false;

  Future<void> _google() async {
    setState(() => _googleLoading = true);
    try {
      await const AuthService().signInWithGoogle();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyAuthError(e))));
      }
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 36),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(child: WelcomeIllustration()),
                      SizedBox(height: 28),
                      Text('Tu menú de la semana y tu lista de la compra, listos en un minuto', style: AppText.hero),
                      SizedBox(height: 12),
                      Text(
                        'Come mejor, gasta menos y aprovecha lo que ya tienes en la nevera.',
                        style: AppText.bodyMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'Continuar con Google',
            style: AppButtonStyle.google,
            leading: const GoogleMarkPlaceholder(),
            loading: _googleLoading,
            onPressed: _google,
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Crear cuenta con email',
            style: AppButtonStyle.outline,
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignUpScreen())),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('¿Ya tienes cuenta?', style: AppText.bodyMuted),
              LinkButton(
                label: 'Inicia sesión',
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignInScreen())),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Ilustración del diseñador: plato con verduras junto a una lista de la compra.
class WelcomeIllustration extends StatelessWidget {
  const WelcomeIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Ilustración: plato con verduras junto a una lista de la compra',
      child: const SizedBox(width: 300, height: 220, child: CustomPaint(painter: _WelcomePainter())),
    );
  }
}

class _WelcomePainter extends CustomPainter {
  const _WelcomePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 300;
    canvas.scale(s, s);
    final white = Paint()..color = AppColors.surface;
    final border = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final line = Paint()..color = AppColors.border;
    final green = Paint()..color = AppColors.primary;

    // Lista de la compra
    final card = RRect.fromRectAndRadius(const Rect.fromLTWH(150, 30, 120, 160), const Radius.circular(16));
    canvas.drawRRect(card, white);
    canvas.drawRRect(card, border);
    const rows = [(54.0, 58.0, true), (88.0, 46.0, true), (122.0, 52.0, false), (156.0, 38.0, false)];
    for (final (y, w, done) in rows) {
      final box = RRect.fromRectAndRadius(Rect.fromLTWH(168, y, 18, 18), const Radius.circular(5));
      if (done) {
        canvas.drawRRect(box, green);
        final tick = Path()
          ..moveTo(172, y + 9)
          ..lineTo(175.5, y + 12.5)
          ..lineTo(181.5, y + 5.5);
        canvas.drawPath(
          tick,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      } else {
        canvas.drawRRect(
          box,
          Paint()
            ..color = AppColors.borderStrong
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(194, y + 4, w, 9), const Radius.circular(4.5)), line);
    }

    // Plato
    const center = Offset(110, 122);
    canvas.drawCircle(center, 84, white);
    canvas.drawCircle(center, 84, border);
    canvas.drawCircle(center, 60, Paint()..color = AppColors.primaryLight);
    canvas.drawCircle(const Offset(88, 108), 20, green);
    canvas.drawCircle(const Offset(128, 100), 15, Paint()..color = const Color(0xFFC2410C));
    canvas.drawCircle(const Offset(122, 142), 22, Paint()..color = const Color(0xFFE8B04B));
    final stem = Path()
      ..moveTo(84, 150)
      ..cubicTo(92, 140, 102, 138, 112, 142);
    canvas.drawPath(
      stem,
      Paint()
        ..color = AppColors.primaryDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
