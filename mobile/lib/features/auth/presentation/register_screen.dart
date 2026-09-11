import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/error_messages.dart';
import '../../../core/validation/validators.dart';
import '../../../core/widgets/widgets.dart';
import '../../../models/user_model.dart';
import '../../../core/errors/api_exception.dart';
import '../data/mock_auth_repository.dart' show authStateProvider;

/// Pantalla de registro institucional.
///
/// Comparte estructura, widgets y validaciones con `LoginScreen`; sólo cambian
/// los campos y la regla de correo, que aquí exige dominio institucional
/// (RF-01).
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  /// Valida el formulario y dispara el registro.
  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();

    // El campo guarda sólo el nombre de usuario; el dominio lo agrega la app.
    await ref
        .read(authStateProvider.notifier)
        .register(
          _nameController.text.trim(),
          Validators.composeInstitutionalEmail(_emailController.text),
          _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    final esAlturaCorta = MediaQuery.sizeOf(context).height < 700;
    final esAlturaMuyCorta = MediaQuery.sizeOf(context).height < 600;
    final separacionCampo = esAlturaMuyCorta
        ? 0.0
        : (esAlturaCorta ? 4.0 : 10.0);

    ref.listen<AsyncValue<UserModel?>>(authStateProvider, (previous, next) {
      if (next.isLoading || next.asData?.value != null) return;

      final error = next.error;
      if (error == null) return;

      // Registro exitoso sin sesión iniciada: volvemos a Login con el mensaje.
      if (error is RequiresVerificationException) {
        context.go('/login');
      }
    });

    final isLoading = authState.isLoading;

    return AuthScaffold(
      actions: const [ThemeToggleButton()],
      title: 'Crear cuenta',
      isRegistration: true,
      subtitle:
          'Regístrate con tu cuenta institucional para guardar y '
          'compartir apuntes.',
      bottomAction: AppPrimaryButton(
        label: 'Crear cuenta',
        isLoading: isLoading,
        compact: esAlturaCorta,
        onPressed: _submit,
      ),
      // Wrap y no Row: con tipografía grande o pantallas angostas el texto
      // más el enlace no caben en una línea, y un Row desbordaría.
      footer: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('¿Ya tienes cuenta?'),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.only(left: 5),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: esOscuro
                  ? colorScheme.secondary
                  : colorScheme.primary,
            ),
            onPressed: isLoading ? null : () => context.go('/login'),
            child: Text(
              'Inicia sesión',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                decoration: esOscuro
                    ? TextDecoration.none
                    : TextDecoration.underline,
                decorationColor: colorScheme.secondary,
                decorationThickness: 2,
              ),
            ),
          ),
        ],
      ),
      children: [
        FormErrorBanner(
          message: authState.hasError && !isRegistrationSuccess(authState.error!)
              ? errorMessage(authState.error!)
              : null,
        ),
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  controller: _nameController,
                  label: 'Nombre completo',
                  hint: 'Camila Soto',
                  compact: true,
                  enabled: !isLoading,
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  validator: Validators.name,
                ),
                SizedBox(height: separacionCampo),
                InstitutionalEmailField(
                  controller: _emailController,
                  enabled: !isLoading,
                  compact: true,
                ),
                SizedBox(height: separacionCampo),
                AppPasswordField(
                  controller: _passwordController,
                  label: 'Contraseña',
                  hint: 'Mínimo ${Validators.minPasswordLength} caracteres',
                  enabled: !isLoading,
                  compact: true,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: Validators.newPassword,
                ),
                SizedBox(height: separacionCampo),
                AppPasswordField(
                  controller: _confirmationController,
                  label: 'Repetir contraseña',
                  enabled: !isLoading,
                  compact: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: (value) => Validators.passwordConfirmation(
                    value,
                    _passwordController.text,
                  ),
                  onFieldSubmitted: (_) => isLoading ? null : _submit(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
