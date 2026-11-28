import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/error_messages.dart';
import '../../../core/validation/validators.dart';
import '../../../core/widgets/widgets.dart';
import '../data/mock_auth_repository.dart'
    show authRepositoryProvider, authStateProvider;

/// Pantalla para solicitar la recuperación de contraseña (`POST /auth/forgot-password`).
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({this.initialNotice, super.key});

  /// Mensaje contextual opcional (por ejemplo, cuando el usuario vuelve desde
  /// restablecimiento tras detectar un código vencido).
  final String? initialNotice;

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _confirmationMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isLoading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _confirmationMessage = null;
    });

    try {
      final email = Validators.composeInstitutionalEmail(_emailController.text);
      final message = await ref
          .read(authRepositoryProvider)
          .requestPasswordRecovery(email: email);
      if (!mounted) return;
      setState(() {
        _confirmationMessage = message;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = errorMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _goToLogin() {
    ref.read(authStateProvider.notifier).clearError();
    context.go('/login');
  }

  void _goToResetPassword() {
    context.go('/reset-password');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    final colorEnlace = esOscuro ? colorScheme.secondary : colorScheme.primary;
    final esAlturaCorta = MediaQuery.sizeOf(context).height < 700;

    return AuthScaffold(
      actions: const [ThemeToggleButton()],
      title: 'Recuperar contraseña',
      subtitle:
          'Ingresa tu usuario institucional para solicitar un código o enlace '
          'temporal de recuperación (válido por 15 minutos).',
      bottomAction: AppPrimaryButton(
        label: _confirmationMessage == null
            ? 'Enviar instrucciones'
            : 'Reenviar instrucciones',
        isLoading: _isLoading,
        compact: esAlturaCorta,
        onPressed: _submit,
      ),
      footer: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('¿Recordaste tu contraseña?'),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.only(left: 5),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: colorEnlace,
            ),
            onPressed: _isLoading ? null : _goToLogin,
            child: Text(
              'Volver al inicio de sesión',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
                decorationColor: colorEnlace,
                decorationThickness: 2,
              ),
            ),
          ),
        ],
      ),
      children: [
        if (widget.initialNotice != null &&
            widget.initialNotice!.trim().isNotEmpty &&
            _errorMessage == null &&
            _confirmationMessage == null)
          _InfoBanner(message: widget.initialNotice!),
        FormErrorBanner(message: _errorMessage),
        if (_confirmationMessage != null)
          _ConfirmationBanner(
            message: _confirmationMessage!,
            onContinueToReset: _isLoading ? null : _goToResetPassword,
          ),
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InstitutionalEmailField(
                  controller: _emailController,
                  enabled: !_isLoading,
                  compact: esAlturaCorta,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _isLoading ? null : _submit(),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: colorEnlace,
                    ),
                    onPressed: _isLoading ? null : _goToResetPassword,
                    child: Text(
                      'Ya tengo un código de recuperación',
                      style: TextStyle(
                        fontSize: esAlturaCorta ? 12.5 : 13.5,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                        decorationColor: colorEnlace,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ConfirmationBanner extends StatelessWidget {
  const _ConfirmationBanner({
    required this.message,
    required this.onContinueToReset,
  });

  final String message;
  final VoidCallback? onContinueToReset;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.mark_email_read_outlined,
                size: 20,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Nota: la recepción del mensaje depende de que el canal de entrega '
            'de correo de Auth esté activo en el entorno.',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 12,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onContinueToReset,
              child: const Text('Ingresar código y nueva contraseña'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.secondary.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 20,
            color: colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: colorScheme.onSecondaryContainer,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
