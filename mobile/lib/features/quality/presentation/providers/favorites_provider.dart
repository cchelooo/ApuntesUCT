import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/session/session_controller.dart';
import '../../../../core/session/session_revision.dart';
import '../../../auth/data/mock_auth_repository.dart' show authStateProvider;
import '../../../materials/domain/models/material_summary.dart';
import '../../domain/models/favorite_item.dart';
import '../../domain/models/favorite_model.dart';

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

  bool containsMaterial(String materialId) =>
      items.any((item) => item.materialId == materialId);

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

/// Resuelve el identificador del usuario autenticado activo desde `SessionController` o `authStateProvider`.
String? resolveActiveQualityUserId(Ref ref) {
  ref.watch(sessionRevisionProvider);
  final sessionUser = ref.watch(sessionControllerProvider).current?.user;
  if (sessionUser != null && sessionUser.active) {
    return sessionUser.id;
  }
  final authState = ref.watch(authStateProvider);
  final currentUser = authState.value;
  if (currentUser != null && currentUser.active) {
    return currentUser.id.isNotEmpty ? currentUser.id : currentUser.email;
  }
  return null;
}

/// Notifier responsable de gestionar los estados del listado de favoritos (#396, #418).
///
/// - Aísla la sesión por usuario activo y limpia la lista al cerrar o cambiar sesión.
/// - Sincroniza adiciones y eliminaciones confirmadas con tarjeta y detalle.
class FavoritesNotifier extends Notifier<FavoritesState> {
  @override
  FavoritesState build() {
    final authState = ref.watch(authStateProvider);
    final currentUserId = resolveActiveQualityUserId(ref);

    if (authState.isLoading && currentUserId == null) {
      return const FavoritesState(
        status: FavoritesStatus.loading,
        items: [],
        activeUserId: null,
      );
    }

    if (currentUserId == null) {
      return const FavoritesState(
        status: FavoritesStatus.empty,
        items: [],
        activeUserId: null,
      );
    }

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

  /// Sincroniza un favorito confirmado por el servidor en el listado activo (#418).
  void syncFavoriteAdded(Favorite favorite, {MaterialSummary? summary}) {
    if (state.activeUserId == null) return;
    final existingIndex = state.items.indexWhere(
      (item) => item.materialId == favorite.materialId,
    );
    final previous = existingIndex >= 0 ? state.items[existingIndex] : null;
    final newItem = FavoriteItem(
      id: favorite.id,
      materialId: favorite.materialId,
      title: summary?.title.isNotEmpty == true
          ? summary!.title
          : (previous?.title ?? 'Material guardado'),
      subjectName: summary?.subjectName ?? previous?.subjectName ?? 'General',
      careerName: summary?.careerName ?? previous?.careerName ?? 'UCT',
      authorName: summary?.authorName ?? previous?.authorName ?? 'Anónimo',
      academicYear: summary?.academicYear ?? previous?.academicYear,
      fileType: summary?.fileType.isNotEmpty == true
          ? summary!.fileType
          : (previous?.fileType ?? 'PDF'),
      rating: summary?.rating ?? previous?.rating ?? 0.0,
      downloadCount: summary?.downloadCount ?? previous?.downloadCount ?? 0,
      createdAt: favorite.createdAt,
      available: favorite.available,
    );

    final updated = List<FavoriteItem>.from(state.items);
    if (existingIndex >= 0) {
      updated[existingIndex] = newItem;
    } else {
      updated.insert(0, newItem);
    }

    state = state.copyWith(
      items: List<FavoriteItem>.unmodifiable(updated),
      status: FavoritesStatus.data,
      errorMessage: null,
    );
  }

  /// Sincroniza la eliminación confirmada de un favorito (#418).
  void syncFavoriteRemoved(String materialId) {
    removeLocalFavorite(materialId);
  }

  /// Elimina un favorito localmente.
  void removeLocalFavorite(String materialId) {
    final updated =
        state.items.where((item) => item.materialId != materialId).toList();
    state = state.copyWith(
      items: List<FavoriteItem>.unmodifiable(updated),
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
