import 'package:apuntesuct_mobile/features/auth/data/mock_auth_repository.dart';
import 'package:apuntesuct_mobile/features/materials/data/material_file_handler.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_requests.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_version.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/providers/material_download_provider.dart';
import 'package:apuntesuct_mobile/features/quality/domain/models/moderation_material_detail.dart';
import 'package:apuntesuct_mobile/features/quality/domain/models/pending_moderation_item.dart';
import 'package:apuntesuct_mobile/features/quality/domain/repositories/quality_moderation_repository.dart';
import 'package:apuntesuct_mobile/features/quality/presentation/providers/moderation_queue_provider.dart';
import 'package:apuntesuct_mobile/features/quality/presentation/providers/moderation_review_provider.dart';
import 'package:apuntesuct_mobile/features/quality/presentation/screens/moderation_queue_screen.dart';
import 'package:apuntesuct_mobile/features/quality/presentation/screens/moderation_review_route.dart';
import 'package:apuntesuct_mobile/features/quality/presentation/screens/moderation_review_screen.dart';
import 'package:apuntesuct_mobile/main.dart';
import 'package:apuntesuct_mobile/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeQualityModerationRepository implements QualityModerationRepository {
  int queueCalls = 0;
  int detailCalls = 0;
  int downloadCalls = 0;

  Future<PendingModerationPage> Function(int page, int pageSize)?
  onListPendingModeration;
  Future<ModerationMaterialDetail> Function(String materialId)?
  onGetPendingMaterialDetail;
  Future<MaterialDownload> Function(String materialId, {String? versionId})?
  onDownloadPendingMaterial;

  @override
  Future<PendingModerationPage> listPendingModeration({
    int page = 1,
    int pageSize = 10,
  }) async {
    queueCalls++;
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

  @override
  Future<ModerationMaterialDetail> getPendingMaterialDetail(
    String materialId,
  ) async {
    detailCalls++;
    if (onGetPendingMaterialDetail != null) {
      return onGetPendingMaterialDetail!(materialId);
    }
    return ModerationMaterialDetail(
      materialId: materialId,
      title: 'Material $materialId',
      status: 'PENDING_REVIEW',
    );
  }

  @override
  Future<MaterialDownload> downloadPendingMaterial(
    String materialId, {
    String? versionId,
  }) async {
    downloadCalls++;
    if (onDownloadPendingMaterial != null) {
      return onDownloadPendingMaterial!(materialId, versionId: versionId);
    }
    return MaterialDownload(
      bytes: [10, 20, 30],
      fileName: 'pendiente.pdf',
      mimeType: 'application/pdf',
    );
  }
}

class _FakeMaterialFileHandler implements MaterialFileHandler {
  String? lastSavedFileName;
  String? lastOpenedPath;
  String? lastOpenedMime;

  @override
  Future<String> save(MaterialDownload download) async {
    lastSavedFileName = download.fileName;
    return '/tmp/cache/${download.fileName}';
  }

  @override
  Future<void> open(String path, String mimeType) async {
    lastOpenedPath = path;
    lastOpenedMime = mimeType;
  }
}

class _FakeAuthStateNotifier extends AuthStateNotifier {
  _FakeAuthStateNotifier(this._user);

  final UserModel? _user;

  @override
  Future<UserModel?> build() async => _user;
}

void main() {
  group(
    'Moderación: cola (#409) y revisión de detalle (#410) con GoRouter',
    () {
      testWidgets(
        'usuario STUDENT no entra a /moderation ni a /moderation/materials/:id sin llamadas HTTP',
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
          expect(find.text('Acceso restringido'), findsOneWidget);
          expect(repo.queueCalls, 0);

          appRouter.go('/moderation/materials/mat-901');
          await tester.pumpAndSettle();
          expect(find.text('Acceso restringido'), findsOneWidget);
          expect(repo.detailCalls, 0);
        },
      );

      testWidgets(
        'recorrido MODERATOR: /moderation -> /moderation/materials/:id -> descarga y apertura nativa -> regreso',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(390, 844);
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
            appRouter.go('/login');
          });

          final fileHandler = _FakeMaterialFileHandler();
          final repo = _FakeQualityModerationRepository()
            ..onListPendingModeration = (page, pageSize) async {
              return PendingModerationPage(
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
            }
            ..onGetPendingMaterialDetail = (materialId) async =>
                ModerationMaterialDetail(
                  reviewId: 'rev-55',
                  materialId: materialId,
                  title: 'Guía Redes de Computadores',
                  description: 'Material pendiente con modelo OSI',
                  authorName: 'Rossio',
                  subjectName: 'Redes',
                  careerName: 'Ingeniería Civil Informática',
                  materialType: 'DOCUMENT',
                  academicYear: 2026,
                  status: 'PENDING_REVIEW',
                  fileSizeBytes: 4096,
                  mimeType: 'application/pdf',
                  currentVersionId: 'ver-1',
                  versions: const [
                    MaterialVersion(
                      id: 'ver-1',
                      materialId: 'mat-901',
                      versionNumber: 1,
                      originalFileName: 'guia_redes.pdf',
                      mimeType: 'application/pdf',
                      fileSizeBytes: 4096,
                    ),
                  ],
                );

          appRouter.go('/moderation');

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                qualityModerationRepositoryProvider.overrideWithValue(repo),
                materialFileHandlerProvider.overrideWithValue(fileHandler),
                authStateProvider.overrideWith(
                  () =>
                      _FakeAuthStateNotifier(UserModel.mock(role: 'MODERATOR')),
                ),
              ],
              child: const MyApp(),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(ModerationQueueScreen), findsOneWidget);
          await tester.tap(find.text('Guía Redes de Computadores'));
          await tester.pumpAndSettle();

          expect(appRouter.state.uri.path, '/moderation/materials/mat-901');
          expect(find.byType(ModerationReviewRoute), findsOneWidget);
          expect(find.byType(ModerationReviewScreen), findsOneWidget);
          expect(
            find.byKey(const Key('moderation_review_material_id_mat-901')),
            findsOneWidget,
          );
          expect(
            find.text('Material pendiente con modelo OSI'),
            findsOneWidget,
          );
          expect(find.text('Subir nueva versión'), findsNothing);

          await tester.tap(
            find.byKey(const Key('moderation_download_file_button')),
          );
          await tester.pumpAndSettle();

          expect(repo.downloadCalls, 1);
          expect(fileHandler.lastSavedFileName, 'pendiente.pdf');

          final openBtn = find.byKey(const Key('moderation_open_file_button'));
          expect(openBtn, findsOneWidget);
          await tester.tap(openBtn);
          await tester.pumpAndSettle();

          expect(fileHandler.lastOpenedPath, '/tmp/cache/pendiente.pdf');
          expect(fileHandler.lastOpenedMime, 'application/pdf');

          await tester.pump(const Duration(seconds: 5));
          await tester.pumpAndSettle();

          await tester.scrollUntilVisible(
            find.byKey(const Key('moderation_review_back_button')),
            200,
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
        'material tipo LINK: valida URL segura, permite abrir enlace y bloquea esquemas inseguros',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(390, 844);
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
            appRouter.go('/login');
          });

          Uri? openedUri;
          var unsafe = false;

          final repo = _FakeQualityModerationRepository()
            ..onGetPendingMaterialDetail = (materialId) async =>
                ModerationMaterialDetail(
                  materialId: materialId,
                  title: 'Repositorio de Grafos',
                  materialType: 'LINK',
                  status: 'PENDING_REVIEW',
                  externalLink: unsafe
                      ? 'javascript:alert(1)'
                      : 'https://github.com/uct/grafos',
                );

          appRouter.go('/moderation/materials/mat-link-1');

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                qualityModerationRepositoryProvider.overrideWithValue(repo),
                moderationExternalLinkOpenerProvider.overrideWithValue((
                  uri,
                ) async {
                  openedUri = uri;
                }),
                authStateProvider.overrideWith(
                  () => _FakeAuthStateNotifier(UserModel.mock(role: 'ADMIN')),
                ),
              ],
              child: const MyApp(),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.byKey(const Key('moderation_external_link_url')),
            findsOneWidget,
          );
          await tester.tap(
            find.byKey(const Key('moderation_open_link_button')),
          );
          await tester.pumpAndSettle();
          expect(openedUri.toString(), 'https://github.com/uct/grafos');

          unsafe = true;
          appRouter.go('/moderation/materials/mat-link-2');
          await tester.pumpAndSettle();

          expect(
            find.byKey(const Key('moderation_unsafe_link_warning')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('moderation_open_link_button')),
            findsNothing,
          );
        },
      );

      testWidgets(
        'maneja material no encontrado (404) en /moderation/materials/:id',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(390, 844);
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
            appRouter.go('/login');
          });

          final repo = _FakeQualityModerationRepository()
            ..onGetPendingMaterialDetail = (materialId) async {
              throw ModerationMaterialNotFoundException(materialId);
            };

          appRouter.go('/moderation/materials/mat-missing');

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                qualityModerationRepositoryProvider.overrideWithValue(repo),
                authStateProvider.overrideWith(
                  () =>
                      _FakeAuthStateNotifier(UserModel.mock(role: 'MODERATOR')),
                ),
              ],
              child: const MyApp(),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.text('Material no disponible para revisión'),
            findsOneWidget,
          );
        },
      );
    },
  );
}
