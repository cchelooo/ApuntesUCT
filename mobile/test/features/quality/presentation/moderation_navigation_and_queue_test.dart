import 'package:apuntesuct_mobile/core/errors/api_exception.dart';
import 'package:apuntesuct_mobile/features/auth/data/mock_auth_repository.dart';
import 'package:apuntesuct_mobile/features/quality/domain/models/pending_moderation_item.dart';
import 'package:apuntesuct_mobile/features/quality/domain/repositories/quality_moderation_repository.dart';
import 'package:apuntesuct_mobile/features/quality/presentation/providers/moderation_queue_provider.dart';
import 'package:apuntesuct_mobile/features/quality/presentation/screens/moderation_queue_screen.dart';
import 'package:apuntesuct_mobile/features/quality/presentation/screens/moderation_review_route.dart';
import 'package:apuntesuct_mobile/main.dart';
import 'package:apuntesuct_mobile/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeQualityModerationRepository implements QualityModerationRepository {
  int calls = 0;
  Future<PendingModerationPage> Function(int page, int pageSize)?
  onListPendingModeration;

  @override
  Future<PendingModerationPage> listPendingModeration({
    int page = 1,
    int pageSize = 10,
  }) async {
    calls++;
    if (onListPendingModeration != null) {
      return onListPendingModeration!(page, pageSize);
    }
    return PendingModerationPage(
      items: const [],
      page: 1,
      pageSize: 10,
      total: 0,
    );
  }
}

class _FakeAuthStateNotifier extends AuthStateNotifier {
  _FakeAuthStateNotifier(this._user);

  final UserModel? _user;

  @override
  Future<UserModel?> build() async => _user;
}

void main() {
  group('Cola de moderación y navegación real con GoRouter (#409)', () {
    testWidgets(
      'usuario STUDENT no ve acceso en Home ni entra a /moderation ni /moderation/materials/:id',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          appRouter.go('/login');
        });

        final repo = _FakeQualityModerationRepository();
        appRouter.go('/');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              qualityModerationRepositoryProvider.overrideWithValue(repo),
              authStateProvider.overrideWith(
                () => _FakeAuthStateNotifier(UserModel.mock(role: 'STUDENT')),
              ),
            ],
            child: const MyApp(),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('home_moderation_queue_button')),
          findsNothing,
        );

        appRouter.go('/moderation');
        await tester.pumpAndSettle();
        expect(appRouter.state.uri.path, '/moderation');
        expect(find.text('Acceso restringido'), findsOneWidget);
        expect(repo.calls, 0);

        appRouter.go('/moderation/materials/mat-901');
        await tester.pumpAndSettle();
        expect(appRouter.state.uri.path, '/moderation/materials/mat-901');
        expect(find.text('Acceso restringido'), findsOneWidget);
        expect(repo.calls, 0);
      },
    );

    testWidgets(
      'recorrido completo MODERATOR: Home -> /moderation -> /moderation/materials/:id conservando ID y regreso',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          appRouter.go('/login');
        });

        final repo = _FakeQualityModerationRepository()
          ..onListPendingModeration = (page, pageSize) async =>
              PendingModerationPage(
                items: const [
                  PendingModerationItem(
                    reviewId: 'rev-55',
                    materialId: 'mat-901',
                    materialVersionId: 'ver-1',
                    title: 'Guía Redes de Computadores',
                    status: 'PENDING_REVIEW',
                    subjectName: 'Redes',
                  ),
                ],
                page: 1,
                pageSize: 10,
                total: 1,
              );

        appRouter.go('/');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              qualityModerationRepositoryProvider.overrideWithValue(repo),
              authStateProvider.overrideWith(
                () => _FakeAuthStateNotifier(UserModel.mock(role: 'MODERATOR')),
              ),
            ],
            child: const MyApp(),
          ),
        );
        await tester.pumpAndSettle();

        final moderationBtn = find.byKey(
          const Key('home_moderation_queue_button'),
        );
        expect(moderationBtn, findsOneWidget);

        await tester.tap(moderationBtn);
        await tester.pumpAndSettle();

        expect(appRouter.state.uri.path, '/moderation');
        expect(find.byType(ModerationQueueScreen), findsOneWidget);
        expect(find.text('Pendientes por revisar: 1'), findsOneWidget);
        expect(find.text('ID: mat-901'), findsOneWidget);
        expect(find.text('Guía Redes de Computadores'), findsOneWidget);

        await tester.tap(find.text('Guía Redes de Computadores'));
        await tester.pumpAndSettle();

        expect(appRouter.state.uri.path, '/moderation/materials/mat-901');
        expect(find.byType(ModerationReviewRoute), findsOneWidget);
        expect(
          find.byKey(const Key('moderation_review_material_id_mat-901')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const Key('moderation_review_back_button')),
        );
        await tester.pumpAndSettle();

        expect(appRouter.state.uri.path, '/moderation');
        expect(find.byType(ModerationQueueScreen), findsOneWidget);
      },
    );

    testWidgets(
      'muestra estado vacío y recuperación tras error en /moderation',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          appRouter.go('/login');
        });

        var mode = 'error';
        final repo = _FakeQualityModerationRepository()
          ..onListPendingModeration = (page, pageSize) async {
            if (mode == 'error') {
              throw ApiException(
                statusCode: 500,
                message: 'Error interno al consultar Quality',
              );
            }
            return PendingModerationPage(
              items: const [],
              page: 1,
              pageSize: 10,
              total: 0,
            );
          };

        appRouter.go('/moderation');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              qualityModerationRepositoryProvider.overrideWithValue(repo),
              authStateProvider.overrideWith(
                () => _FakeAuthStateNotifier(UserModel.mock(role: 'ADMIN')),
              ),
            ],
            child: const MyApp(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Error interno al consultar Quality'), findsOneWidget);

        mode = 'empty';
        await tester.tap(find.byKey(const Key('moderation_refresh_button')));
        await tester.pumpAndSettle();

        expect(find.text('Sin materiales pendientes'), findsOneWidget);
      },
    );
  });
}
