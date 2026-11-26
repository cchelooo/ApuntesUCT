import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/session/session_revision.dart';
import '../../../../models/user_model.dart';
import '../../../auth/data/mock_auth_repository.dart' show authStateProvider;
import '../../../materials/domain/models/material_summary.dart';
import '../../domain/models/favorite_model.dart';
import '../../domain/models/quality_error.dart';
import 'favorites_provider.dart';
import 'quality_repository_provider.dart';

/// Estado de la acción de agregar o quitar un material de favoritos (Issue #418 - S3-M31).
///
/// - [isFavorite] refleja únicamente el último estado confirmado para el usuario activo.
/// - Ante un error, [isFavorite] conserva su valor confirmado previo y expone
///   [errorMessage] y [canRetry] para repetir la operación fallida.
class FavoriteActionState {
  final bool isFavorite;
  final bool isPending;
  final Favorite? favorite;
  final String? errorMessage;
  final int? statusCode;
  final String? errorCode;
  final bool? lastFailedTargetState;
  final MaterialSummary? lastSummary;
  final String? activeUserId;

  const FavoriteActionState({
    required this.isFavorite,
    this.isPending = false,
    this.favorite,
    this.errorMessage,
    this.statusCode,
    this.errorCode,
    this.lastFailedTargetState,
    this.lastSummary,
    this.activeUserId,
  });

  bool get hasError => errorMessage != null && !isPending;
  bool get canRetry => hasError && lastFailedTargetState != null;

  FavoriteActionState copyWith({
    bool? isFavorite,
    bool? isPending,
    Favorite? favorite,
    bool clearFavorite = false,
    String? errorMessage,
    bool clearError = false,
    int? statusCode,
    String? errorCode,
    bool? lastFailedTargetState,
    bool clearFailedTarget = false,
    MaterialSummary? lastSummary,
    String? activeUserId,
  }) {
    return FavoriteActionState(
      isFavorite: isFavorite ?? this.isFavorite,
      isPending: isPending ?? this.isPending,
      favorite: clearFavorite ? null : (favorite ?? this.favorite),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      statusCode: clearError ? null : (statusCode ?? this.statusCode),
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      lastFailedTargetState: clearFailedTarget
          ? null
          : (lastFailedTargetState ?? this.lastFailedTargetState),
      lastSummary: lastSummary ?? this.lastSummary,
      activeUserId: activeUserId ?? this.activeUserId,
    );
  }
}

/// Traduce errores de API/red en operaciones de favoritos a mensajes comprensibles en español.
String favoriteActionErrorMessage(Object error, {required bool adding}) {
  if (error is DioException && error.type == DioExceptionType.cancel) {
    return 'Operación de favoritos cancelada.';
  }

  QualityApiException? qualityError;
  ApiException? apiError;
  if (error is QualityApiException) {
    qualityError = error;
    apiError = error;
  } else if (error is DioException && error.error is QualityApiException) {
    qualityError = error.error as QualityApiException;
    apiError = qualityError;
  } else if (error is DioException && error.error is ApiException) {
    apiError = error.error as ApiException;
  } else if (error is ApiException) {
    apiError = error;
  }

  final actionText = adding
      ? 'guardar en favoritos'
      : 'quitar de favoritos';

  if (apiError == null) {
    return 'No fue posible $actionText. Verifica tu conexión e intenta nuevamente.';
  }

  final serverMessage = apiError.message.trim();
  switch (apiError.statusCode) {
    case 401:
      return 'Inicia sesión con una cuenta activa para gestionar tus favoritos.';
    case 403:
      return serverMessage.isNotEmpty
          ? serverMessage
          : 'Tu cuenta no tiene permisos para modificar favoritos.';
    case 404:
      return 'El material no está disponible para guardarse en favoritos.';
    case 502:
    case 503:
      return 'El servicio de favoritos no está disponible ahora. Intenta nuevamente.';
    default:
      return serverMessage.isNotEmpty
          ? serverMessage
          : 'No fue posible $actionText. Intenta nuevamente.';
  }
}

/// Notifier que coordina las acciones de agregar y quitar favoritos para un [materialId] (#418).
///
/// - Utiliza `qualityRepositoryProvider` (`PUT / DELETE /quality/materials/{id}/favorite`) mediante Gateway.
/// - Sincroniza el estado confirmado entre tarjeta, detalle y listado (`favoritesProvider`)
///   mediante `ref.listen` sin cancelar ni reconstruir peticiones pendientes de otros materiales.
/// - Conserva el estado confirmado previo si la petición falla y habilita `retry()`.
/// - Aísla los favoritos por sesión activa, evitando mostrar favoritos de una sesión en otra.
class FavoriteActionNotifier extends Notifier<FavoriteActionState> {
  FavoriteActionNotifier(this.materialId);

  final String materialId;
  CancelToken? _cancelToken;

  @override
  FavoriteActionState build() {
    ref.onDispose(() => _cancelToken?.cancel());

    // Escuchar cambios en el listado general sin reconstruir ni cancelar peticiones en vuelo de este material
    ref.listen<FavoritesState>(favoritesProvider, (previous, next) {
      if (state.isPending) {
        // Si la sesión se cerró por completo mientras había una operación en vuelo
        // de otro origen, se resolverá al terminar o cambiar de usuario; no cancelar
        // cuando solo se confirmó otro material A mientras B sigue en vuelo.
        return;
      }

      if (next.activeUserId == null) {
        state = const FavoriteActionState(
          isFavorite: false,
          activeUserId: null,
        );
        return;
      }

      // Si el listado está cargando (p. ej. durante refresh()), conservar la marca confirmada actual
      if (next.isLoading) {
        return;
      }

      if (next.status == FavoritesStatus.data ||
          next.status == FavoritesStatus.empty) {
        final confirmedInList = next.containsMaterial(materialId);
        if (state.isFavorite != confirmedInList ||
            state.activeUserId != next.activeUserId) {
          state = state.copyWith(
            isFavorite: confirmedInList,
            activeUserId: next.activeUserId,
            clearFavorite: !confirmedInList,
          );
        }
      }
    });

    // Escuchar cambios de sesión para aislar cuentas sin interrumpir otros materiales
    ref.listen<int>(sessionRevisionProvider, (previous, next) {
      _handleSessionChange();
    });
    ref.listen<AsyncValue<UserModel?>>(authStateProvider, (previous, next) {
      _handleSessionChange();
    });

    final activeUserId = readActiveQualityUserId(ref);
    final favoritesListState = ref.read(favoritesProvider);

    if (activeUserId == null) {
      return const FavoriteActionState(
        isFavorite: false,
        activeUserId: null,
      );
    }

    final isConfirmedInList =
        favoritesListState.activeUserId == activeUserId &&
        favoritesListState.containsMaterial(materialId);

    return FavoriteActionState(
      isFavorite: isConfirmedInList,
      activeUserId: activeUserId,
    );
  }

  void _handleSessionChange() {
    final currentUserId = readActiveQualityUserId(ref);
    if (currentUserId == state.activeUserId) return;

    if (state.isPending) {
      // Si cambió a otro usuario distinto mientras estaba en vuelo, cancelar y limpiar
      if (currentUserId != null && currentUserId != state.activeUserId) {
        _cancelToken?.cancel();
        _cancelToken = null;
        final listState = ref.read(favoritesProvider);
        state = FavoriteActionState(
          isFavorite:
              listState.activeUserId == currentUserId &&
              listState.containsMaterial(materialId),
          activeUserId: currentUserId,
        );
      }
      return;
    }

    _cancelToken?.cancel();
    _cancelToken = null;
    if (currentUserId == null) {
      state = const FavoriteActionState(
        isFavorite: false,
        activeUserId: null,
      );
      return;
    }

    final listState = ref.read(favoritesProvider);
    state = FavoriteActionState(
      isFavorite:
          listState.activeUserId == currentUserId &&
          listState.containsMaterial(materialId),
      activeUserId: currentUserId,
    );
  }

  /// Guarda el material en los favoritos del usuario autenticado activo (`PUT /quality/materials/:id/favorite`).
  Future<bool> addFavorite({MaterialSummary? summary}) async {
    if (state.isPending) return false;

    final userId = readActiveQualityUserId(ref);
    if (userId == null) {
      state = state.copyWith(
        isFavorite: false,
        isPending: false,
        errorMessage:
            'Inicia sesión con una cuenta activa para gestionar tus favoritos.',
        statusCode: 401,
        errorCode: 'UNAUTHENTICATED',
        lastFailedTargetState: true,
        lastSummary: summary,
      );
      return false;
    }

    final revision = ref.read(sessionRevisionProvider);
    final previousConfirmed = state.isFavorite;
    final previousFavorite = state.favorite;
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;

    state = state.copyWith(
      isPending: true,
      clearError: true,
      clearFailedTarget: true,
      lastSummary: summary,
      activeUserId: userId,
    );

    try {
      final repository = ref.read(qualityRepositoryProvider);
      final confirmed = await repository.addFavorite(
        materialId,
        cancelToken: cancelToken,
      );

      if (!ref.mounted) return false;
      final currentUserId = readActiveQualityUserId(ref);
      if (ref.read(sessionRevisionProvider) != revision ||
          currentUserId != userId) {
        state = FavoriteActionState(
          isFavorite: false,
          activeUserId: currentUserId,
        );
        return false;
      }

      state = FavoriteActionState(
        isFavorite: true,
        isPending: false,
        favorite: confirmed,
        lastSummary: summary ?? state.lastSummary,
        activeUserId: userId,
      );

      // Sincroniza el listado personal para mantener coherencia con tarjeta y detalle
      ref
          .read(favoritesProvider.notifier)
          .syncFavoriteAdded(confirmed, summary: summary ?? state.lastSummary);

      return true;
    } catch (error) {
      if (!ref.mounted) return false;

      QualityApiException? qualityErr;
      ApiException? apiErr;
      if (error is QualityApiException) {
        qualityErr = error;
        apiErr = error;
      } else if (error is DioException && error.error is QualityApiException) {
        qualityErr = error.error as QualityApiException;
        apiErr = qualityErr;
      } else if (error is DioException && error.error is ApiException) {
        apiErr = error.error as ApiException;
      } else if (error is ApiException) {
        apiErr = error;
      }

      final currentUserId = readActiveQualityUserId(ref);
      final isUnauthorized = apiErr?.statusCode == 401;
      if (!isUnauthorized &&
          (ref.read(sessionRevisionProvider) != revision ||
              currentUserId != userId)) {
        state = FavoriteActionState(
          isFavorite: false,
          activeUserId: currentUserId,
        );
        return false;
      }

      // Conserva el estado confirmado previo sin simular que se agregó
      state = FavoriteActionState(
        isFavorite: isUnauthorized ? false : previousConfirmed,
        isPending: false,
        favorite: isUnauthorized ? null : previousFavorite,
        errorMessage: favoriteActionErrorMessage(error, adding: true),
        statusCode: apiErr?.statusCode,
        errorCode:
            qualityErr?.errorCode ?? (isUnauthorized ? 'UNAUTHENTICATED' : null),
        lastFailedTargetState: true,
        lastSummary: summary ?? state.lastSummary,
        activeUserId: currentUserId,
      );
      return false;
    } finally {
      if (identical(_cancelToken, cancelToken)) {
        _cancelToken = null;
      }
    }
  }

  /// Quita el material de los favoritos del usuario autenticado activo (`DELETE /quality/materials/:id/favorite`).
  Future<bool> removeFavorite() async {
    if (state.isPending) return false;

    final userId = readActiveQualityUserId(ref);
    if (userId == null) {
      state = state.copyWith(
        isFavorite: false,
        isPending: false,
        errorMessage:
            'Inicia sesión con una cuenta activa para gestionar tus favoritos.',
        statusCode: 401,
        errorCode: 'UNAUTHENTICATED',
        lastFailedTargetState: false,
      );
      return false;
    }

    final revision = ref.read(sessionRevisionProvider);
    final previousConfirmed = state.isFavorite;
    final previousFavorite = state.favorite;
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;

    state = state.copyWith(
      isPending: true,
      clearError: true,
      clearFailedTarget: true,
      activeUserId: userId,
    );

    try {
      final repository = ref.read(qualityRepositoryProvider);
      await repository.removeFavorite(
        materialId,
        cancelToken: cancelToken,
      );

      if (!ref.mounted) return false;
      final currentUserId = readActiveQualityUserId(ref);
      if (ref.read(sessionRevisionProvider) != revision ||
          currentUserId != userId) {
        state = FavoriteActionState(
          isFavorite: false,
          activeUserId: currentUserId,
        );
        return false;
      }

      state = FavoriteActionState(
        isFavorite: false,
        isPending: false,
        favorite: null,
        lastSummary: state.lastSummary,
        activeUserId: userId,
      );

      // Sincroniza el listado personal para mantener coherencia con tarjeta y detalle
      ref.read(favoritesProvider.notifier).syncFavoriteRemoved(materialId);

      return true;
    } catch (error) {
      if (!ref.mounted) return false;

      QualityApiException? qualityErr;
      ApiException? apiErr;
      if (error is QualityApiException) {
        qualityErr = error;
        apiErr = error;
      } else if (error is DioException && error.error is QualityApiException) {
        qualityErr = error.error as QualityApiException;
        apiErr = qualityErr;
      } else if (error is DioException && error.error is ApiException) {
        apiErr = error.error as ApiException;
      } else if (error is ApiException) {
        apiErr = error;
      }

      final currentUserId = readActiveQualityUserId(ref);
      final isUnauthorized = apiErr?.statusCode == 401;
      if (!isUnauthorized &&
          (ref.read(sessionRevisionProvider) != revision ||
              currentUserId != userId)) {
        state = FavoriteActionState(
          isFavorite: false,
          activeUserId: currentUserId,
        );
        return false;
      }

      // Conserva el estado confirmado previo sin simular que se eliminó
      state = FavoriteActionState(
        isFavorite: isUnauthorized ? false : previousConfirmed,
        isPending: false,
        favorite: isUnauthorized ? null : previousFavorite,
        errorMessage: favoriteActionErrorMessage(error, adding: false),
        statusCode: apiErr?.statusCode,
        errorCode:
            qualityErr?.errorCode ?? (isUnauthorized ? 'UNAUTHENTICATED' : null),
        lastFailedTargetState: false,
        lastSummary: state.lastSummary,
        activeUserId: currentUserId,
      );
      return false;
    } finally {
      if (identical(_cancelToken, cancelToken)) {
        _cancelToken = null;
      }
    }
  }

  /// Alterna entre agregar y quitar según el último estado confirmado.
  Future<bool> toggleFavorite({MaterialSummary? summary}) {
    if (state.isFavorite) {
      return removeFavorite();
    }
    return addFavorite(summary: summary);
  }

  /// Reintenta la última operación fallida (agregar o quitar).
  Future<bool> retry() {
    final target = state.lastFailedTargetState;
    if (target == true) {
      return addFavorite(summary: state.lastSummary);
    }
    if (target == false) {
      return removeFavorite();
    }
    return toggleFavorite(summary: state.lastSummary);
  }

  void clearError() {
    state = state.copyWith(clearError: true, clearFailedTarget: true);
  }
}

/// Provider familiar por `materialId` que coordina el estado y acciones de favorito entre tarjeta, detalle y listado.
final favoriteActionProvider =
    NotifierProvider.family<
      FavoriteActionNotifier,
      FavoriteActionState,
      String
    >(FavoriteActionNotifier.new);
