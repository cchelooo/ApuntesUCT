import 'package:apuntesuct_mobile/core/errors/api_exception.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_page.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_summary.dart';
import 'package:apuntesuct_mobile/features/materials/domain/repositories/moderation_repository.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/providers/moderation_queue_provider.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/screens/moderation_queue_screen.dart';
import 'package:apuntesuct_mobile/features/auth/data/mock_auth_repository.dart';
import 'package:apuntesuct_mobile/features/home/presentation/home_screen.dart';
import 'package:apuntesuct_mobile/models/user_model.dart';
import 'package:flutter/material.dart' hide MaterialPage;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeModerationRepository implements ModerationRepository {
  int calls = 0;
  Future<MaterialPage> Function(int page, int pageSize)? onListPending;

  @override
  Future<MaterialPage> listPending({int page = 1, int pageSize = 10}) async {
    calls++;
    if (onListPending != null) {
      return onListPending!(page, pageSize);
    }
    return MaterialPage(items: const [], page: 1, pageSize: 10, total: 0);
  }
}

class _FakeAuthStateNotifier extends AuthStateNotifier {
  _FakeAuthStateNotifier(this._user);

  final UserModel? _user;

  @override
  Future<UserModel?> build() async => _user;
}

void main() {
  group('ModerationQueueScreen (#409)', () {
    testWidgets('oculta el panel y no consulta la cola si no es moderador', (
      tester,
    ) async {
      final repo = _FakeModerationRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            moderationRepositoryProvider.overrideWithValue(repo),
            moderationUserRoleProvider.overrideWithValue('STUDENT'),
          ],
          child: const MaterialApp(home: ModerationQueueScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Acceso restringido'), findsOneWidget);
      expect(repo.calls, 0);
    });

    testWidgets(
      'muestra materiales pendientes con IDs y conserva ID al navegar',
      (tester) async {
        final repo = _FakeModerationRepository()
          ..onListPending = (page, pageSize) async => MaterialPage(
            items: const [
              MaterialSummary(
                id: 'mat-901',
                title: 'Guía Redes de Computadores',
                status: 'PENDING_REVIEW',
                subjectName: 'Redes',
              ),
            ],
            page: 1,
            pageSize: 10,
            total: 1,
          );

        MaterialSummary? selected;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              moderationRepositoryProvider.overrideWithValue(repo),
              moderationUserRoleProvider.overrideWithValue('MODERATOR'),
            ],
            child: MaterialApp(
              home: ModerationQueueScreen(
                onSelectMaterial: (material) => selected = material,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Pendientes por revisar: 1'), findsOneWidget);
        expect(find.text('ID: mat-901'), findsOneWidget);
        expect(find.text('Guía Redes de Computadores'), findsOneWidget);
        expect(find.text('EN REVISIÓN'), findsOneWidget);

        await tester.tap(find.text('Guía Redes de Computadores'));
        await tester.pumpAndSettle();

        expect(selected?.id, 'mat-901');
      },
    );

    testWidgets('muestra estado vacío cuando no hay pendientes', (
      tester,
    ) async {
      final repo = _FakeModerationRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            moderationRepositoryProvider.overrideWithValue(repo),
            moderationUserRoleProvider.overrideWithValue('MODERATOR'),
          ],
          child: const MaterialApp(home: ModerationQueueScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sin materiales pendientes'), findsOneWidget);
    });

    testWidgets('muestra estado de error y permite reintentar', (tester) async {
      var shouldFail = true;
      final repo = _FakeModerationRepository()
        ..onListPending = (page, pageSize) async {
          if (shouldFail) {
            throw ApiException(
              statusCode: 500,
              message: 'Error interno al consultar cola',
            );
          }
          return MaterialPage(
            items: const [
              MaterialSummary(
                id: 'mat-902',
                title: 'Resumen Recuperado',
                status: 'PENDING_REVIEW',
              ),
            ],
            page: 1,
            pageSize: 10,
            total: 1,
          );
        };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            moderationRepositoryProvider.overrideWithValue(repo),
            moderationUserRoleProvider.overrideWithValue('MODERATOR'),
          ],
          child: const MaterialApp(home: ModerationQueueScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Error interno al consultar cola'), findsOneWidget);

      shouldFail = false;
      await tester.tap(find.byKey(const Key('moderation_refresh_button')));
      await tester.pumpAndSettle();

      expect(find.text('Resumen Recuperado'), findsOneWidget);
    });
    testWidgets('HomeScreen oculta acceso a moderación para rol STUDENT', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith(
              () => _FakeAuthStateNotifier(UserModel.mock(role: 'STUDENT')),
            ),
          ],
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('home_moderation_queue_button')),
        findsNothing,
      );
    });

    testWidgets('HomeScreen muestra acceso a moderación para rol MODERATOR', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith(
              () => _FakeAuthStateNotifier(UserModel.mock(role: 'MODERATOR')),
            ),
          ],
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('home_moderation_queue_button')),
        findsOneWidget,
      );
    });
  });
}
