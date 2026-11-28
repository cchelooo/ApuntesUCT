import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:apuntesuct_mobile/core/theme/app_theme.dart';
import 'package:apuntesuct_mobile/features/auth/presentation/forgot_password_screen.dart';
import 'package:apuntesuct_mobile/features/auth/presentation/login_screen.dart';
import 'package:apuntesuct_mobile/features/auth/presentation/register_screen.dart';
import 'package:apuntesuct_mobile/features/auth/presentation/reset_password_screen.dart';
import 'package:apuntesuct_mobile/features/catalog/presentation/screens/catalog_screen.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/screens/material_detail_route.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/screens/material_discovery_screen.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/screens/material_upload_screen.dart';
import 'package:apuntesuct_mobile/features/profile/presentation/profile_screen.dart';
import 'package:apuntesuct_mobile/providers/theme_mode_provider.dart';
import 'package:apuntesuct_mobile/features/home/presentation/home_screen.dart';
import 'package:apuntesuct_mobile/features/quality/quality.dart';
import 'package:apuntesuct_mobile/features/auth/data/mock_auth_repository.dart'
    show authStateProvider;

final GoRouter appRouter = GoRouter(
  initialLocation: const String.fromEnvironment(
    'INITIAL_ROUTE',
    defaultValue: '/login',
  ),
  redirect: (context, state) {
    final path = state.uri.path;
    final auth = ProviderScope.containerOf(context).read(authStateProvider);
    if (path == '/session') {
      if (auth.isLoading) return null;
      final requested = state.uri.queryParameters['next'];
      final target =
          const {
            '/',
            '/profile',
            '/favorites',
            '/library',
            '/materials/upload',
          }.contains(requested)
          ? requested!
          : '/';
      return auth.asData?.value == null ? '/login' : target;
    }
    final private =
        path == '/' ||
        path == '/profile' ||
        path == '/favorites' ||
        path == '/library' ||
        path == '/materials/upload' ||
        path.startsWith('/moderation');
    if (!private) return null;
    if (auth.isLoading) {
      return Uri(path: '/session', queryParameters: {'next': path}).toString();
    }
    return auth.asData?.value == null ? '/login' : null;
  },
  routes: [
    GoRoute(
      path: '/session',
      builder: (context, state) =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
    ),
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
      path: '/forgot-password',
      name: 'forgot-password',
      builder: (context, state) => ForgotPasswordScreen(
        initialNotice: state.uri.queryParameters['notice'],
      ),
    ),
    GoRoute(
      path: '/reset-password',
      name: 'reset-password',
      builder: (context, state) => ResetPasswordScreen(
        initialToken: state.uri.queryParameters['token'],
      ),
    ),
    GoRoute(
      path: '/profile',
      name: 'profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/catalog',
      name: 'catalog',
      builder: (context, state) => const CatalogScreen(),
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
    GoRoute(
      path: '/favorites',
      name: 'favorites',
      builder: (context, state) => const FavoritesScreen(),
    ),
    // Módulo Materiales (issue #279). Convive con /catalog sin reemplazarlo.
    GoRoute(
      path: '/materials',
      name: 'materials',
      builder: (context, state) => const MaterialDiscoveryScreen(),
      routes: [
        GoRoute(
          path: 'upload',
          name: 'material-upload',
          builder: (context, state) => const MaterialUploadScreen(),
        ),
        GoRoute(
          // Declarada después de 'upload' para que /materials/upload no
          // sea capturado como :id.
          path: ':id',
          name: 'material-detail',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return MaterialDetailRoute(materialId: id);
          },
        ),
      ],
    ),
  ],
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(authStateProvider, (_, next) {
      WidgetsBinding.instance.addPostFrameCallback((_) => appRouter.refresh());
    });
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
