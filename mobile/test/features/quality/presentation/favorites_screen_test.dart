import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:apuntesuct_mobile/core/theme/app_theme.dart';
import 'package:apuntesuct_mobile/core/widgets/empty_state.dart';
import 'package:apuntesuct_mobile/core/widgets/error_state.dart';
import 'package:apuntesuct_mobile/core/widgets/loading_state.dart';
import 'package:apuntesuct_mobile/features/auth/data/mock_auth_repository.dart'
    show authStateProvider, AuthStateNotifier;
import 'package:apuntesuct_mobile/features/quality/domain/models/favorite_item.dart';
import 'package:apuntesuct_mobile/features/quality/presentation/providers/favorites_provider.dart';
import 'package:apuntesuct_mobile/features/quality/presentation/screens/favorites_screen.dart';
import 'package:apuntesuct_mobile/features/quality/presentation/widgets/favorite_card.dart';
import 'package:apuntesuct_mobile/models/user_model.dart';

void main() {
  const userA = UserModel(
    id: 'usr-autor-a',
    email: 'usuario.a@uct.cl',
    name: 'Usuario A',
    role: 'STUDENT',
    active: true,
  );
  const userB = UserModel(
    id: 'usr-autor-b',
    email: 'usuario.b@uct.cl',
    name: 'Usuario B',
    role: 'STUDENT',
    active: true,
  );

  group('Issue #396: FavoritesNotifier - Gestión de Estados y Sesión (S3-M09)', () {
    test('Criterio 1: Notifier contempla carga, datos, lista vacía y error con reintento', () async {
      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith(() => _PresetAuthNotifier(userA)),
        ],
      );
      addTearDown(container.dispose);

      // Mantener suscripción activa al provider durante el test
      final subscription = container.listen(favoritesProvider, (_, _) {});
      addTearDown(subscription.close);

      // Mientras authStateProvider resuelve su Future inicial, está en loading
      expect(container.read(favoritesProvider).isLoading, isTrue);

      // Esperar resolución de autenticación
      await container.read(authStateProvider.future);

      final loaded = container.read(favoritesProvider);
      expect(loaded.hasData, isTrue);
      expect(loaded.activeUserId, equals('usr-autor-a'));
      expect(
        loaded.items.length,
        equals(FavoritesFixtures.defaultFavorites.length),
      );
      expect(loaded.isPreparationMode, isTrue);

      // Transición a estado de carga explícito
      final notifier = container.read(favoritesProvider.notifier);
      await notifier.setScenario(FavoritesDemoScenario.loading);
      expect(container.read(favoritesProvider).isLoading, isTrue);

      // Transición a lista vacía
      await notifier.setScenario(FavoritesDemoScenario.empty);
      final emptyState = container.read(favoritesProvider);
      expect(emptyState.isEmpty, isTrue);
      expect(emptyState.items, isEmpty);

      // Transición a error
      await notifier.setScenario(FavoritesDemoScenario.error);
      final errorState = container.read(favoritesProvider);
      expect(errorState.hasError, isTrue);
      expect(errorState.errorMessage, contains('servicio de favoritos'));

      // Reintento funcional recupera datos
      await notifier.retry();
      final recoveredState = container.read(favoritesProvider);
      expect(recoveredState.hasData, isTrue);
      expect(recoveredState.items.isNotEmpty, isTrue);
    });

    test('Criterio 3: Respeta el usuario activo y evita conservar favoritos de otra sesión', () async {
      final authNotifier = _MutableAuthNotifier(userA);

      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith(() => authNotifier),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(favoritesProvider, (_, _) {});
      addTearDown(subscription.close);

      await container.read(authStateProvider.future);

      expect(
        container.read(favoritesProvider).activeUserId,
        equals('usr-autor-a'),
      );
      expect(container.read(favoritesProvider).hasData, isTrue);

      // Usuario A remueve un favorito localmente en su sesión
      final firstMaterialId =
          container.read(favoritesProvider).items.first.materialId;
      container
          .read(favoritesProvider.notifier)
          .removeLocalFavorite(firstMaterialId);
      expect(
        container.read(favoritesProvider).items.length,
        equals(FavoritesFixtures.defaultFavorites.length - 1),
      );

      // Usuario A cierra sesión: no deben conservarse favoritos de la sesión anterior
      authNotifier.setUser(null);

      final loggedOutState = container.read(favoritesProvider);
      expect(loggedOutState.activeUserId, isNull);
      expect(loggedOutState.items, isEmpty);
      expect(loggedOutState.isEmpty, isTrue);

      // Usuario B inicia sesión: recibe estado limpio propio, sin arrastrar mutaciones de Usuario A
      authNotifier.setUser(userB);

      final userBState = container.read(favoritesProvider);
      expect(userBState.activeUserId, equals('usr-autor-b'));
      expect(userBState.activeUserId, isNot(equals('usr-autor-a')));
      expect(
        userBState.items.length,
        equals(FavoritesFixtures.defaultFavorites.length),
      );
    });

    test('Criterio 4: Identificación explícita de preparación visual (S3-M09)', () {
      const state = FavoritesState();
      expect(state.isPreparationMode, isTrue);
      expect(FavoritesFixtures.preparationNotice, contains('S3-M09'));
      expect(FavoritesFixtures.preparationNotice, contains('Semana 3'));
    });

    test('FavoriteItem.toMaterialSummary() mapea disponibilidad correctamente', () {
      final available = FavoriteItem(
        id: 'f0000001-0000-4000-8000-000000000001',
        materialId: 'a0000001-0000-4000-8000-000000000001',
        title: 'Material A',
        subjectName: 'Química',
        careerName: 'Ingeniería',
        authorName: 'Autor',
        createdAt: DateTime.utc(2026, 11, 1),
        available: true,
      );

      final unavailable = available.copyWith(available: false);

      expect(available.toMaterialSummary().status, equals('APPROVED'));
      expect(unavailable.toMaterialSummary().status, equals('WITHDRAWN'));
    });
  });

  group('Issue #396: FavoritesScreen - Pruebas de Interfaz Visual (S3-M09)', () {
    testWidgets('Criterio 1: Renderiza estado de carga (LoadingState)', (tester) async {
      const loadingState = FavoritesState(
        status: FavoritesStatus.loading,
        activeUserId: 'usr-test',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith(() => _PresetAuthNotifier(null)),
            favoritesProvider.overrideWith(
              () => _PresetFavoritesNotifier(loadingState),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.claro,
            home: const FavoritesScreen(),
          ),
        ),
      );

      expect(find.byType(LoadingState), findsOneWidget);
      expect(find.text('Cargando favoritos guardados...'), findsOneWidget);
    });

    testWidgets('Criterio 1 y 4: Renderiza lista de favoritos y aviso de preparación', (tester) async {
      final dataState = FavoritesState(
        status: FavoritesStatus.data,
        items: FavoritesFixtures.defaultFavorites,
        activeUserId: 'usr-test',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith(() => _PresetAuthNotifier(null)),
            favoritesProvider.overrideWith(
              () => _PresetFavoritesNotifier(dataState),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.claro,
            home: const FavoritesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Aviso explícito de preparación (Criterio 4)
      expect(find.textContaining('Sprint 3 / S3-M09'), findsOneWidget);

      // Tarjetas de favoritos con sus datos
      expect(
        find.byType(FavoriteCard),
        findsNWidgets(FavoritesFixtures.defaultFavorites.length),
      );
      expect(
        find.text('Guía Completa de Cálculo I - Derivadas e Integrales'),
        findsOneWidget,
      );
      expect(
        find.text('Resumen Estructuras de Datos y Algoritmos en Dart'),
        findsOneWidget,
      );
    });

    testWidgets('Criterio 1: Renderiza estado vacío (EmptyState) con botón de exploración', (tester) async {
      const emptyState = FavoritesState(
        status: FavoritesStatus.empty,
        items: [],
        activeUserId: 'usr-test',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith(() => _PresetAuthNotifier(null)),
            favoritesProvider.overrideWith(
              () => _PresetFavoritesNotifier(emptyState),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.claro,
            home: const FavoritesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('Sin favoritos guardados'), findsOneWidget);
      expect(find.text('Explorar materiales'), findsOneWidget);
    });

    testWidgets('Criterio 1: Renderiza ErrorState y permite reintentar', (tester) async {
      bool retried = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith(() => _PresetAuthNotifier(null)),
            favoritesProvider.overrideWith(
              () => _MockRetryNotifier(
                const FavoritesState(
                  status: FavoritesStatus.error,
                  errorMessage: 'Error de conexión simulado.',
                  activeUserId: 'usr-test',
                ),
                onRetryCalled: () => retried = true,
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.claro,
            home: const FavoritesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.text('No pudimos cargar tus favoritos'), findsOneWidget);
      expect(find.text('Error de conexión simulado.'), findsOneWidget);

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(retried, isTrue);
    });

    testWidgets('Criterio 2: Las tarjetas navegan al detalle mediante el ID del material', (tester) async {
      String? navigatedMaterialId;

      final testItem = FavoriteItem(
        id: 'f0aa0001-0000-4000-8000-000000000001',
        materialId: 'a1bb0001-0000-4000-8000-000000000001',
        title: 'Material de Prueba para Navegación',
        subjectName: 'Química',
        careerName: 'Ingeniería',
        authorName: 'Docente X',
        createdAt: DateTime.utc(2026, 11, 1),
        available: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.claro,
          home: Scaffold(
            body: FavoriteCard(
              item: testItem,
              onTap: () => navigatedMaterialId = testItem.materialId,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Material de Prueba para Navegación'), findsOneWidget);

      await tester.tap(find.byType(FavoriteCard));
      await tester.pumpAndSettle();

      expect(
        navigatedMaterialId,
        equals('a1bb0001-0000-4000-8000-000000000001'),
      );
    });

    testWidgets('Criterio 2: Muestra badge de advertencia cuando el material no está disponible', (tester) async {
      final unavailableItem = FavoriteItem(
        id: 'f0aa0002-0000-4000-8000-000000000002',
        materialId: 'a1bb0002-0000-4000-8000-000000000002',
        title: 'Material Retirado del Catálogo',
        subjectName: 'Física',
        careerName: 'Ingeniería',
        authorName: 'Docente Y',
        createdAt: DateTime.utc(2026, 11, 1),
        available: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.claro,
          home: Scaffold(
            body: FavoriteCard(item: unavailableItem),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No disponible'), findsOneWidget);
    });
  });
}

class _PresetAuthNotifier extends AuthStateNotifier {
  final UserModel? _user;

  _PresetAuthNotifier(this._user);

  @override
  Future<UserModel?> build() async => _user;
}

class _MutableAuthNotifier extends AuthStateNotifier {
  UserModel? _current;

  _MutableAuthNotifier(this._current);

  @override
  Future<UserModel?> build() async => _current;

  void setUser(UserModel? user) {
    _current = user;
    state = AsyncValue.data(user);
  }
}

class _PresetFavoritesNotifier extends FavoritesNotifier {
  final FavoritesState _presetState;

  _PresetFavoritesNotifier(this._presetState);

  @override
  FavoritesState build() => _presetState;
}

class _MockRetryNotifier extends FavoritesNotifier {
  final FavoritesState _initial;
  final VoidCallback onRetryCalled;

  _MockRetryNotifier(this._initial, {required this.onRetryCalled});

  @override
  FavoritesState build() => _initial;

  @override
  Future<void> retry() async => onRetryCalled();
}

extension on FavoriteItem {
  FavoriteItem copyWith({bool? available}) {
    return FavoriteItem(
      id: id,
      materialId: materialId,
      title: title,
      subjectName: subjectName,
      careerName: careerName,
      authorName: authorName,
      academicYear: academicYear,
      fileType: fileType,
      rating: rating,
      downloadCount: downloadCount,
      createdAt: createdAt,
      available: available ?? this.available,
    );
  }
}
