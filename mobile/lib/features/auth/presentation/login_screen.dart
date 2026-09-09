import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/error_messages.dart';
import '../../../core/validation/validators.dart';
import '../../../core/widgets/widgets.dart';
import '../../../models/user_model.dart';
import '../data/mock_auth_repository.dart' show authStateProvider;

/// Pantalla de inicio de sesión.
///
/// Consume `authStateProvider`, que expone un `AsyncValue<UserModel?>`: de ahí
/// salen los tres estados de la pantalla sin necesidad de un flag local de
/// carga ni de un `setState` por cada transición.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Valida el formulario y dispara el login.
  ///
  /// El resultado no se lee aquí: lo publica `authStateProvider` y lo recogen
  /// el `ref.listen` (navegación) y el `ref.watch` (error y carga).
  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Baja el teclado antes de la petición para que el banner de error quede
    // visible cuando la respuesta llegue.
    FocusScope.of(context).unfocus();

    // El campo guarda sólo el nombre de usuario; el dominio lo agrega la app.
    await ref
        .read(authStateProvider.notifier)
        .login(
          Validators.composeInstitutionalEmail(_emailController.text),
          _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final esOscuro = Theme.of(context).brightness == Brightness.dark;

    // La navegación va en listen y no en build: build puede ejecutarse muchas
    // veces por la misma sesión y terminaría empujando rutas repetidas.
    ref.listen<AsyncValue<UserModel?>>(authStateProvider, (previous, next) {
      if (!next.isLoading && next.value != null) {
        context.go('/');
      }
    });

    final isLoading = authState.isLoading;

    return AuthScaffold(
      actions: const [ThemeToggleButton()],
      title: 'Iniciar sesión',
      subtitle:
          'Ingresa con tu cuenta institucional para acceder al material '
          'de tu carrera.',
      bottomAction: AppPrimaryButton(
        label: 'Ingresar',
        isLoading: isLoading,
        onPressed: _submit,
      ),
      // Wrap y no Row: con tipografía grande o pantallas angostas el texto
      // más el enlace no caben en una línea, y un Row desbordaría.
      footer: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('¿No tienes cuenta?'),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.only(left: 5),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: esOscuro
                  ? colorScheme.secondary
                  : colorScheme.primary,
            ),
            onPressed: isLoading ? null : () => context.go('/register'),
            child: Text(
              'Regístrate',
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
          message: authState.hasError ? errorMessage(authState.error!) : null,
        ),
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InstitutionalEmailField(
                  controller: _emailController,
                  enabled: !isLoading,
                ),
                const SizedBox(height: 16),
                AppPasswordField(
                  controller: _passwordController,
                  label: 'Contraseña',
                  enabled: !isLoading,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  validator: Validators.loginPassword,
                  // Enter en el teclado envía el formulario, igual que el botón.
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
