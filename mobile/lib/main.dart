import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:apuntesuct_mobile/providers/auth_provider.dart';

void main() {
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ApuntesUCT',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuthenticated = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('ApuntesUCT - Riverpod Demo'),
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
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  ref.read(authProvider.notifier).toggle();
                },
                icon: Icon(isAuthenticated ? Icons.logout : Icons.login),
                label:
                    Text(isAuthenticated ? 'Cerrar sesión' : 'Iniciar sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
