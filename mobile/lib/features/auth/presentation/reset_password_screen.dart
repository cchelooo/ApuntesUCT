import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/error_messages.dart';
import '../../../core/validation/validators.dart';
import '../../../core/widgets/widgets.dart';
import '../data/mock_auth_repository.dart'
    show authRepositoryProvider, authStateProvider;

/// Pantalla para restablecer la contraseña con token temporal (`POST /auth/reset-password`).
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({this.initialToken, super.key});

  /// Token opcional recibido por parámetro de ruta o deep link.
  final String? initialToken;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _tokenController;
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tokenController = TextEditingController(
      text: widget.initialToken?.trim() ?? '',
    );
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isLoading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final normalizedToken = Validators.extractRecoveryToken(
        _tokenController.text,
      );
      final message = await ref
          .read(authRepositoryProvider)
          .resetPassword(
            token: normalizedToken,
            password: _passwordController.text,
          );
      if (!mounted) return;
      ref.read(authStateProvider.notifier).clearError();
      final messenger = ScaffoldMessenger.maybeOf(context);
      context.go('/login');
      messenger?.showSnackBar(
        SnackBar(
          content: Text('$message Inicia sesión con tu nueva contraseña.'),
        ),
      );
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

  void _requestNewCode() {
    context.go(
      Uri(
        path: '/forgot-password',
        queryParameters: const {
          'notice':
              'Solicita un nuevo código temporal para restablecer tu contraseña.',
        },
      ).toString(),
    );
  }

  void _goToLogin() {
    ref.read(authStateProvider.notifier).clearError();
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    final colorEnlace = esOscuro ? colorScheme.secondary : colorScheme.primary;
    final esAlturaCorta = MediaQuery.sizeOf(context).height < 700;
    final esAlturaMuyCorta = MediaQuery.sizeOf(context).height < 600;
    final separacionCampo = esAlturaMuyCorta
        ? 0.0
        : (esAlturaCorta ? 4.0 : 10.0);

    return AuthScaffold(
      actions: const [ThemeToggleButton()],
      title: 'Nueva contraseña',
      isRegistration: true,
      subtitle:
          'Ingresa el código de 64 caracteres (o enlace recibido) y define tu '
          'nueva contraseña institucional.',
      bottomAction: AppPrimaryButton(
        label: 'Actualizar contraseña',
        isLoading: _isLoading,
        compact: esAlturaCorta,
        onPressed: _submit,
      ),
      footer: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('¿Código vencido o no lo tienes?'),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.only(left: 5),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: colorEnlace,
            ),
            onPressed: _isLoading ? null : _requestNewCode,
            child: Text(
              'Solicitar nuevo código',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
                decorationColor: colorEnlace,
                decorationThickness: 2,
              ),
            ),
          ),
          const SizedBox(width: 8),
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
        FormErrorBanner(message: _errorMessage),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _isLoading ? null : _requestNewCode,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Solicitar un nuevo código de recuperación'),
              ),
            ),
          ),
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  controller: _tokenController,
                  label: 'Código o enlace de recuperación',
                  hint: 'Código hexadecimal de 64 caracteres',
                  compact: true,
                  enabled: !_isLoading,
                  keyboardType: TextInputType.text,
                  textCapitalization: TextCapitalization.none,
                  validator: Validators.recoveryToken,
                ),
                SizedBox(height: separacionCampo),
                AppPasswordField(
                  controller: _passwordController,
                  label: 'Nueva contraseña',
                  hint: 'Mínimo ${Validators.minPasswordLength} caracteres',
                  enabled: !_isLoading,
                  compact: true,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: Validators.newPassword,
                ),
                SizedBox(height: separacionCampo),
                AppPasswordField(
                  controller: _confirmationController,
                  label: 'Repetir contraseña',
                  enabled: !_isLoading,
                  compact: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: (value) => Validators.passwordConfirmation(
                    value,
                    _passwordController.text,
                  ),
                  onFieldSubmitted: (_) => _isLoading ? null : _submit(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
