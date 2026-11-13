import 'package:flutter/material.dart';

import '../safety/safety_widgets.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'auth_service.dart';

/// A3 · Aceptar términos y confirmar la mayoría de edad (tras entrar con Google, o usuarios
/// antiguos sin aceptación guardada). Hoja inferior sobre la bienvenida oscurecida.
/// "Cancelar" cierra la sesión.
class AcceptTermsScreen extends StatefulWidget {
  const AcceptTermsScreen({
    super.key,
    required this.firstName,
    required this.onAccepted,
    this.termsAlreadyAccepted = false,
  });

  final String? firstName;
  final VoidCallback onAccepted;

  /// true = solo falta la mayoría de edad (usuarios anteriores a la migración 0004).
  final bool termsAlreadyAccepted;

  @override
  State<AcceptTermsScreen> createState() => _AcceptTermsScreenState();
}

class _AcceptTermsScreenState extends State<AcceptTermsScreen> {
  // Sin casillas premarcadas: el RGPD exige una acción clara del usuario.
  bool _legal = false;
  bool _adult = false;
  bool _marketing = false;
  bool _loading = false;
  bool _triedWithoutLegal = false;
  String? _error;

  bool get _askTerms => !widget.termsAlreadyAccepted;

  Future<void> _accept() async {
    if ((_askTerms && !_legal) || !_adult) {
      setState(() => _triedWithoutLegal = true);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await const AuthService().acceptTerms(marketingOptIn: _marketing, includeTerms: _askTerms);
      widget.onAccepted();
    } catch (e) {
      if (mounted) setState(() => _error = friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// M1 y cierre de sesión.
  Future<void> _minor() async {
    await showMinorNotice(context);
    await const AuthService().signOut();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.firstName;
    return Scaffold(
      backgroundColor: AppColors.scrim,
      body: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Semantics(
            scopesRoute: true,
            namesRoute: true,
            label: 'Aceptar términos',
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(20, 12, 20, 28 + MediaQuery.paddingOf(context).bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    name == null || name.isEmpty ? '¡Ya casi está!' : '¡Ya casi está, $name!',
                    style: AppText.h1.copyWith(fontSize: 22, height: 28 / 22),
                  ),
                  const SizedBox(height: 8),
                  const Text('Solo falta un paso antes de preparar tus menús.', style: AppText.smallMuted),
                  const SizedBox(height: 20),
                  if (_askTerms) ...[
                    CheckRow(
                      value: _legal,
                      hasError: _triedWithoutLegal && !_legal,
                      onChanged: (v) => setState(() => _legal = v),
                      label: const LegalText(),
                    ),
                    if (_triedWithoutLegal && !_legal) ...[
                      const SizedBox(height: 8),
                      const ErrorLine('Para continuar, acepta los términos y la política de privacidad'),
                    ],
                    const SizedBox(height: 12),
                  ],
                  AdultConfirmation(
                    value: _adult,
                    showError: _triedWithoutLegal,
                    onChanged: (v) => setState(() => _adult = v),
                    onMinor: _loading ? () {} : _minor,
                  ),
                  if (_askTerms) ...[
                    const SizedBox(height: 4),
                    CheckRow(
                      value: _marketing,
                      onChanged: (v) => setState(() => _marketing = v),
                      label: const Text('Quiero recibir ideas y ofertas por email (opcional)'),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    ErrorLine(_error!),
                  ],
                  const SizedBox(height: 20),
                  AppButton(label: 'Aceptar y continuar', loading: _loading, onPressed: _accept),
                  const SizedBox(height: 4),
                  AppButton(
                    label: 'Cancelar',
                    style: AppButtonStyle.ghost,
                    onPressed: _loading ? null : () => const AuthService().signOut(),
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
