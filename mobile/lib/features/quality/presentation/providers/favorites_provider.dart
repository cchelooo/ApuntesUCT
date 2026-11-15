import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/data/mock_auth_repository.dart' show authStateProvider;
import '../../domain/models/favorite_item.dart';

/// Estados posibles de la pantalla de favoritos (Criterio 1: carga, datos, vacío, error).
enum FavoritesStatus {
  initial,
  loading,
  data,
  empty,
  error,
}

/// Escenarios de prueba explícitos para verificación visual en fase de preparación (S3-M09).
enum FavoritesDemoScenario {
  withData,
  empty,
  error,
  loading,
}

/// Estado inmutable de la pantalla de favoritos.
class FavoritesState {
  final FavoritesStatus status;
  final List<FavoriteItem> items;
  final String? errorMessage;
  final String? activeUserId;
  final bool isPreparationMode;
  final FavoritesDemoScenario currentScenario;

  const FavoritesState({
    this.status = FavoritesStatus.initial,
    this.items = const [],
    this.errorMessage,
    this.activeUserId,
    this.isPreparationMode = true,
    this.currentScenario = FavoritesDemoScenario.withData,
  });

  bool get isLoading => status == FavoritesStatus.loading;
  bool get hasData => status == FavoritesStatus.data && items.isNotEmpty;
  bool get isEmpty =>
      status == FavoritesStatus.empty ||
      (status == FavoritesStatus.data && items.isEmpty);
  bool get hasError => status == FavoritesStatus.error;

  FavoritesState copyWith({
    FavoritesStatus? status,
    List<FavoriteItem>? items,
    String? errorMessage,
    String? activeUserId,
    bool? isPreparationMode,
    FavoritesDemoScenario? currentScenario,
  }) {
    return FavoritesState(
      status: status ?? this.status,
      items: items ?? this.items,
      errorMessage: errorMessage,
      activeUserId: activeUserId ?? this.activeUserId,
      isPreparationMode: isPreparationMode ?? this.isPreparationMode,
      currentScenario: currentScenario ?? this.currentScenario,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FavoritesState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          items.length == other.items.length &&
          errorMessage == other.errorMessage &&
          activeUserId == other.activeUserId &&
          isPreparationMode == other.isPreparationMode &&
          currentScenario == other.currentScenario;

  @override
  int get hashCode => Object.hash(
        status,
        items.length,
        errorMessage,
        activeUserId,
        isPreparationMode,
        currentScenario,
      );
}

/// Notifier responsable de gestionar los estados del listado de favoritos.
///
/// Implementa los requerimientos de la Issue #396 (S3-M09):
/// - Aísla la sesión por usuario activo y limpia la lista al cerrar o cambiar sesión.
/// - Administra estados de carga, datos, vacío y error con reintento.
/// - Utiliza datos explícitos de preparación identificados adecuadamente.
class FavoritesNotifier extends Notifier<FavoritesState> {
  @override
  FavoritesState build() {
    // Escucha activamente el estado del usuario autenticado (Criterio 3)
    final authState = ref.watch(authStateProvider);
    final currentUser = authState.value;
    final currentUserId = currentUser?.id ?? currentUser?.email;

    // Si la sesión aún se está resolviendo, reflejar estado de carga
    if (authState.isLoading) {
      return const FavoritesState(
        status: FavoritesStatus.loading,
        items: [],
        activeUserId: null,
      );
    }

    // Si no hay usuario activo, limpiar inmediatamente favoritos anteriores
    if (currentUserId == null) {
      return const FavoritesState(
        status: FavoritesStatus.empty,
        items: [],
        activeUserId: null,
      );
    }

    // Inicializar estado aislado para el usuario activo con datos de preparación
    return FavoritesState(
      status: FavoritesStatus.data,
      items: List<FavoriteItem>.unmodifiable(FavoritesFixtures.defaultFavorites),
      activeUserId: currentUserId,
      currentScenario: FavoritesDemoScenario.withData,
    );
  }

  /// Carga los favoritos según el escenario activo o datos del usuario.
  Future<void> loadFavorites() async {
    final userId = state.activeUserId;
    if (userId == null) {
      state = state.copyWith(
        status: FavoritesStatus.empty,
        items: const [],
      );
      return;
    }
    await _applyScenario(state.currentScenario, userId: userId);
  }

  /// Reintenta la carga ante un error previo (Criterio 1).
  Future<void> retry() async {
    if (state.currentScenario == FavoritesDemoScenario.error) {
      await setScenario(FavoritesDemoScenario.withData);
    } else {
      await loadFavorites();
    }
  }

  /// Recarga los datos mediante pull-to-refresh.
  Future<void> refresh() async {
    await loadFavorites();
  }

  /// Cambia explícitamente el escenario visual para propósitos de prueba / QA.
  Future<void> setScenario(FavoritesDemoScenario scenario) async {
    await _applyScenario(scenario, userId: state.activeUserId);
  }

  /// Elimina un favorito localmente (preparación para la interacción en semana 3).
  void removeLocalFavorite(String materialId) {
    final updated =
        state.items.where((item) => item.materialId != materialId).toList();
    state = state.copyWith(
      items: updated,
      status: updated.isEmpty ? FavoritesStatus.empty : FavoritesStatus.data,
    );
  }

  /// Limpia los favoritos cuando se cierra sesión explícitamente (Criterio 3).
  void clearForLogout() {
    state = const FavoritesState(
      status: FavoritesStatus.empty,
      items: [],
      activeUserId: null,
    );
  }

  Future<void> _applyScenario(
    FavoritesDemoScenario scenario, {
    required String? userId,
  }) async {
    state = state.copyWith(
      status: FavoritesStatus.loading,
      currentScenario: scenario,
      errorMessage: null,
    );

    await Future<void>.microtask(() {});
    if (!ref.mounted || state.activeUserId != userId) {
      return;
    }

    switch (scenario) {
      case FavoritesDemoScenario.loading:
        state = state.copyWith(
          status: FavoritesStatus.loading,
        );
        break;
      case FavoritesDemoScenario.withData:
        state = state.copyWith(
          status: FavoritesStatus.data,
          items: List<FavoriteItem>.unmodifiable(
            FavoritesFixtures.defaultFavorites,
          ),
          errorMessage: null,
        );
        break;
      case FavoritesDemoScenario.empty:
        state = state.copyWith(
          status: FavoritesStatus.empty,
          items: const [],
          errorMessage: null,
        );
        break;
      case FavoritesDemoScenario.error:
        state = state.copyWith(
          status: FavoritesStatus.error,
          items: const [],
          errorMessage:
              'No fue posible conectar con el servicio de favoritos. Verifica tu conexión e intenta nuevamente.',
        );
        break;
    }
  }
}

/// Provider global de estado para la pantalla de favoritos.
final favoritesProvider = NotifierProvider<FavoritesNotifier, FavoritesState>(
  FavoritesNotifier.new,
);
