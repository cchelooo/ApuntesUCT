import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:apuntesuct_mobile/core/config/app_config.dart';
import 'package:apuntesuct_mobile/core/theme/app_theme.dart';
import 'package:apuntesuct_mobile/features/auth/data/auth_providers.dart';
import 'package:apuntesuct_mobile/features/auth/data/mock_auth_repository.dart'
    show authStateProvider;
import 'package:apuntesuct_mobile/features/auth/presentation/login_screen.dart';
import 'package:apuntesuct_mobile/features/auth/presentation/register_screen.dart';
import 'package:apuntesuct_mobile/providers/theme_mode_provider.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      name: 'register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/profile',
      name: 'profile',
      builder: (context, state) => const PendingScreen(title: 'Perfil'),
    ),
    GoRoute(
      path: '/catalog',
      name: 'catalog',
      builder: (context, state) => const PendingScreen(title: 'Catálogo'),
    ),
    GoRoute(
      path: '/search',
      name: 'search',
      builder: (context, state) => const PendingScreen(title: 'Búsqueda'),
    ),
    GoRoute(
      path: '/library',
      name: 'library',
      builder: (context, state) => const PendingScreen(title: 'Biblioteca'),
    ),
  ],
);

void main() {
  final overrides = [if (AppConfig.useRemoteApi) useRemoteAuthOverride];

  runApp(ProviderScope(overrides: overrides, child: const MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'ApuntesUCT',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.claro,
      darkTheme: AppTheme.oscuro,
      themeMode: ref.watch(themeModeProvider),
      routerConfig: appRouter,
    );
  }
}

class PendingScreen extends StatelessWidget {
  const PendingScreen({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text('$title pendiente')),
    );
  }
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final isAuthenticated = authState.hasValue && authState.value != null;
    final user = authState.value;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('ApuntesUCT'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Estado de autenticación:',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Chip(
                avatar: Icon(
                  isAuthenticated ? Icons.check_circle : Icons.cancel,
                  color: isAuthenticated ? Colors.green : Colors.red,
                ),
                label: Text(
                  isAuthenticated ? 'Autenticado' : 'No autenticado',
                  style: TextStyle(
                    color: isAuthenticated
                        ? Colors.green.shade900
                        : Colors.red.shade900,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor: isAuthenticated
                    ? Colors.green.shade50
                    : Colors.red.shade50,
              ),
              if (isAuthenticated && user != null) ...[
                const SizedBox(height: 12),
                Text(
                  '${user.name}\n${user.email}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  if (isAuthenticated) {
                    ref.read(authStateProvider.notifier).logout();
                  } else {
                    context.go('/login');
                  }
                },
                icon: Icon(isAuthenticated ? Icons.logout : Icons.login),
                label: Text(
                  isAuthenticated ? 'Cerrar sesión' : 'Iniciar sesión',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
