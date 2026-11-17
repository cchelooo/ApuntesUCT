import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/data/mock_auth_repository.dart' show authStateProvider;
import '../../data/dio_quality_moderation_repository.dart';
import '../../domain/models/pending_moderation_item.dart';
import '../../domain/repositories/quality_moderation_repository.dart';

/// Evalúa si el rol de sesión tiene permisos de moderación.
bool isModeratorRole(String? role) {
  if (role == null) return false;
  final normalized = role.trim().toUpperCase();
  return normalized == 'MODERATOR' || normalized == 'ADMIN';
}

/// Rol del usuario autenticado para habilitar el panel de moderación.
final moderationUserRoleProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).asData?.value?.role;
});

/// Indica si la sesión actual está autorizada para acceder a la cola privada.
final canAccessModerationProvider = Provider<bool>((ref) {
  return isModeratorRole(ref.watch(moderationUserRoleProvider));
});

/// Repositorio privado de Quality conectado al cliente del Gateway.
final qualityModerationRepositoryProvider =
    Provider<QualityModerationRepository>((ref) {
      return DioQualityModerationRepository(ref.watch(apiclientProvider));
    });

class ModerationQueueState {
  static const Object _undefined = Object();

  final List<PendingModerationItem> items;
  final bool isLoading;
  final bool isLoadingMore;
  final int currentPage;
  final int totalPages;
  final int total;
  final String? errorMessage;
  final Object? error;

  const ModerationQueueState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.currentPage = 1,
    this.totalPages = 1,
    this.total = 0,
    this.errorMessage,
    this.error,
  });

  bool get hasNextPage => currentPage < totalPages;

  ModerationQueueState copyWith({
    List<PendingModerationItem>? items,
    bool? isLoading,
    bool? isLoadingMore,
    int? currentPage,
    int? totalPages,
    int? total,
    Object? errorMessage = _undefined,
    Object? error = _undefined,
  }) {
    return ModerationQueueState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      total: total ?? this.total,
      errorMessage: errorMessage == _undefined
          ? this.errorMessage
          : errorMessage as String?,
      error: error == _undefined ? this.error : error,
    );
  }
}

class ModerationQueueNotifier extends Notifier<ModerationQueueState> {
  static const int _defaultPageSize = 10;
  bool _disposed = false;

  @override
  ModerationQueueState build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    Future.microtask(() => loadInitial());
    return const ModerationQueueState(isLoading: true);
  }

  Future<void> loadInitial({int pageSize = _defaultPageSize}) async {
    state = state.copyWith(
      isLoading: true,
      isLoadingMore: false,
      errorMessage: null,
      error: null,
    );

    try {
      final page = await ref
          .read(qualityModerationRepositoryProvider)
          .listPendingModeration(page: 1, pageSize: pageSize);
      if (_disposed) return;

      state = state.copyWith(
        items: page.items,
        isLoading: false,
        currentPage: page.page,
        totalPages: page.totalPages,
        total: page.total,
        errorMessage: null,
        error: null,
      );
    } catch (error) {
      if (_disposed) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: _resolveErrorMessage(error),
        error: error,
      );
    }
  }

  Future<void> refresh() => loadInitial();

  Future<void> loadNextPage({int pageSize = _defaultPageSize}) async {
    if (state.isLoading || state.isLoadingMore || !state.hasNextPage) return;

    state = state.copyWith(isLoadingMore: true);
    final nextPage = state.currentPage + 1;

    try {
      final page = await ref
          .read(qualityModerationRepositoryProvider)
          .listPendingModeration(page: nextPage, pageSize: pageSize);
      if (_disposed) return;

      state = state.copyWith(
        items: [...state.items, ...page.items],
        isLoadingMore: false,
        currentPage: page.page,
        totalPages: page.totalPages,
        total: page.total,
      );
    } catch (_) {
      if (_disposed) return;
      state = state.copyWith(isLoadingMore: false);
    }
  }

  String _resolveErrorMessage(Object error) {
    if (error is ApiException) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        return 'No tienes autorización para consultar la cola de moderación.';
      }
      return error.message;
    }
    return 'No se pudo cargar la cola de materiales pendientes.';
  }
}

final moderationQueueProvider =
    NotifierProvider.autoDispose<ModerationQueueNotifier, ModerationQueueState>(
      ModerationQueueNotifier.new,
    );
