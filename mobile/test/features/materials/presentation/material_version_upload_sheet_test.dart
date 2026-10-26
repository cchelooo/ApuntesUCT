import 'dart:async';
import 'dart:typed_data';

import 'package:apuntesuct_mobile/core/errors/api_exception.dart';
import 'package:apuntesuct_mobile/core/widgets/app_primary_button.dart';
import 'package:apuntesuct_mobile/features/materials/data/dio_material_repository.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_detail.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_page.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_requests.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_version.dart';
import 'package:apuntesuct_mobile/features/materials/domain/repositories/material_repository.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/providers/material_version_upload_provider.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/validation/material_upload_validation.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/widgets/material_version_upload_sheet.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart' hide MaterialPage;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeVersionRepository implements MaterialRepository {
  var calls = 0;
  String? lastMaterialId;
  LocalMaterialFile? lastFile;
  CancelToken? lastCancelToken;
  Future<MaterialVersion> Function(String materialId, LocalMaterialFile file)?
  onCreate;

  @override
  Future<MaterialVersion> createVersion(
    String materialId,
    MaterialSource source, {
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) async {
    calls++;
    final file = source as LocalMaterialFile;
    lastMaterialId = materialId;
    lastFile = file;
    lastCancelToken = cancelToken;
    onSendProgress?.call(file.bytes.length ~/ 2, file.bytes.length);
    if (onCreate != null) return onCreate!(materialId, file);
    return MaterialVersion(
      id: 'ver-3',
      materialId: materialId,
      versionNumber: 3,
      originalFileName: file.fileName,
      mimeType: file.mimeType,
      fileSizeBytes: file.bytes.length,
      createdAt: DateTime.utc(2026, 10, 21),
    );
  }

  @override
  Future<MaterialDetail> getDetail(String materialId) =>
      throw UnimplementedError();

  @override
  Future<MaterialPage> list({int page = 1, int pageSize = 10}) =>
      throw UnimplementedError();

  @override
  Future<MaterialDetail> upload(UploadMaterialRequest request) =>
      throw UnimplementedError();

  @override
  Future<MaterialDownload> download(String materialId, {String? versionId}) =>
      throw UnimplementedError();
}

Future<void> _pumpSheet(
  WidgetTester tester,
  _FakeVersionRepository fake, {
  String materialId = 'mat-1',
  Future<MaterialPickedFile?> Function()? pickFile,
  int? currentVersionNumber = 2,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [dioMaterialRepositoryProvider.overrideWithValue(fake)],
      child: MaterialApp(
        home: Scaffold(
          body: MaterialVersionUploadSheet(
            materialId: materialId,
            currentVersionNumber: currentVersionNumber,
            pickFile:
                pickFile ??
                () async => MaterialPickedFile(
                  fileName: 'guia-v3.pdf',
                  sizeBytes: 3,
                  mimeType: 'application/pdf',
                  bytes: Uint8List.fromList(const [1, 2, 3]),
                ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('MaterialVersionUploadSheet widget (#292)', () {
    testWidgets('flujo completo: archivo, confirmación, éxito sin duplicar', (
      tester,
    ) async {
      final fake = _FakeVersionRepository()
        ..onCreate = (_, file) async {
          // Retrasa la respuesta para observar el estado de subida.
          await Future<void>.delayed(const Duration(milliseconds: 100));
          return MaterialVersion(
            id: 'ver-3',
            materialId: 'mat-1',
            versionNumber: 3,
            originalFileName: file.fileName,
            mimeType: file.mimeType,
            fileSizeBytes: file.bytes.length,
          );
        };
      await _pumpSheet(tester, fake);

      // Explica que la anterior no se elimina y la versión destino.
      expect(find.textContaining('no se elimina'), findsOneWidget);
      expect(find.textContaining('v3'), findsWidgets);

      await tester.tap(find.textContaining('Seleccionar archivo'));
      await tester.pumpAndSettle();
      expect(find.text('guia-v3.pdf'), findsOneWidget);

      // Confirmación explícita antes de enviar.
      final confirm = find.text('Confirmar subida de v3');
      expect(confirm, findsOneWidget);
      await tester.tap(confirm);
      await tester.pump();
      // Mientras sube: progreso visible y sin botón de envío (no duplica).
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Confirmar subida de v3'), findsNothing);
      await tester.pumpAndSettle();

      expect(fake.calls, 1);
      expect(fake.lastMaterialId, 'mat-1');
      expect(fake.lastFile?.fileName, 'guia-v3.pdf');
      expect(fake.lastFile?.bytes, [1, 2, 3]);
      expect(find.text('Versión v3 creada'), findsOneWidget);
      expect(find.textContaining('sigue en el historial'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('rechaza formato no permitido y bloquea confirmación', (
      tester,
    ) async {
      final fake = _FakeVersionRepository();
      await _pumpSheet(
        tester,
        fake,
        pickFile: () async => MaterialPickedFile(
          fileName: 'virus.exe',
          sizeBytes: 1024,
          mimeType: 'application/octet-stream',
        ),
      );

      await tester.tap(find.textContaining('Seleccionar archivo'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Formato no permitido'), findsOneWidget);
      expect(fake.calls, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('error 403 muestra mensaje y permite reintentar', (
      tester,
    ) async {
      final fake = _FakeVersionRepository()
        ..onCreate = (_, _) async => throw ApiException(
          message: 'Solo el autor del material puede subir una nueva versión.',
          statusCode: 403,
        );
      await _pumpSheet(tester, fake);

      await tester.tap(find.textContaining('Seleccionar archivo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar subida de v3'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Solo el autor'), findsOneWidget);
      expect(find.text('Versión v3 creada'), findsNothing);
      // El archivo se conserva para reintentar.
      expect(find.text('guia-v3.pdf'), findsOneWidget);

      fake.onCreate = null;
      await tester.tap(find.text('Confirmar subida de v3'));
      await tester.pumpAndSettle();

      expect(fake.calls, 2);
      expect(find.text('Versión v3 creada'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sin versiones previas propone v1', (tester) async {
      final fake = _FakeVersionRepository();
      await _pumpSheet(tester, fake, currentVersionNumber: null);

      expect(find.textContaining('v1'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reabrir no muestra la confirmación anterior sin subir', (
      tester,
    ) async {
      final fake = _FakeVersionRepository();
      final container = ProviderContainer(
        overrides: [dioMaterialRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      var openings = 0;
      Future<void> openSheet() async {
        // Key distinta por apertura: cerrar el modal hace dispose y
        // reabrir crea un State nuevo (igual que en producción).
        openings++;
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: MaterialVersionUploadSheet(
                  key: ValueKey('sheet-$openings'),
                  materialId: 'mat-1',
                  currentVersionNumber: 2,
                  pickFile: () async => MaterialPickedFile(
                    fileName: 'guia-v3.pdf',
                    sizeBytes: 3,
                    mimeType: 'application/pdf',
                    bytes: Uint8List.fromList(const [1, 2, 3]),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      // Sube la versión A.
      await openSheet();
      await tester.tap(find.textContaining('Seleccionar archivo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar subida de v3'));
      await tester.pumpAndSettle();
      expect(find.text('Versión v3 creada'), findsOneWidget);

      // Cierra (en producción: pop del modal) y reabre para la versión
      // B: re-montar equivale a cerrar+reabrir porque el provider del
      // contenedor compartido conserva el éxito de A.
      await openSheet();

      expect(find.text('Versión v3 creada'), findsNothing);
      expect(find.textContaining('Seleccionar archivo'), findsOneWidget);
      expect(fake.calls, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tras crear v3, subir otra propone v4', (tester) async {
      final fake = _FakeVersionRepository();
      await _pumpSheet(tester, fake);

      await tester.tap(find.textContaining('Seleccionar archivo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar subida de v3'));
      await tester.pumpAndSettle();
      expect(find.text('Versión v3 creada'), findsOneWidget);

      await tester.tap(find.text('Subir otra versión'));
      await tester.pumpAndSettle();

      // La propuesta avanza aunque el detalle aún no se haya refrescado.
      expect(find.text('Confirmar subida de v4'), findsOneWidget);

      await tester.tap(find.textContaining('Seleccionar archivo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar subida de v4'));
      await tester.pumpAndSettle();

      expect(fake.calls, 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('subida de A en curso bloquea la hoja de B hasta terminar', (
      tester,
    ) async {
      final gate = Completer<MaterialVersion>();
      final fake = _FakeVersionRepository()
        ..onCreate = (materialId, file) {
          if (materialId == 'mat-A') return gate.future;
          return Future.value(
            MaterialVersion(
              id: 'ver-6',
              materialId: materialId,
              versionNumber: 6,
            ),
          );
        };
      final container = ProviderContainer(
        overrides: [dioMaterialRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      // Empieza la subida de A sin UI (equivale a cerrar su hoja a mitad).
      final futureA = container
          .read(materialVersionUploadProvider('mat-A').notifier)
          .uploadVersion(
            'mat-A',
            LocalMaterialFile(
              fileName: 'a-v4.pdf',
              mimeType: 'application/pdf',
              bytes: const [1, 2, 3],
            ),
          );

      // Se abre la hoja de B mientras A sigue en vuelo.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: MaterialVersionUploadSheet(
                materialId: 'mat-B',
                currentVersionNumber: 5,
                pickFile: () async => MaterialPickedFile(
                  fileName: 'b-v6.pdf',
                  sizeBytes: 3,
                  mimeType: 'application/pdf',
                  bytes: Uint8List.fromList(const [1, 2, 3]),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // B está bloqueada: aviso + cancelación ajena, confirmación
      // deshabilitada (el botón existe pero sin onPressed), sin progreso
      // ni confirmación ajena.
      AppPrimaryButton confirmButton() => tester.widget<AppPrimaryButton>(
        find.widgetWithText(AppPrimaryButton, 'Confirmar subida de v6'),
      );
      expect(confirmButton().onPressed, isNull);
      expect(
        find.textContaining('subida en curso en otro material'),
        findsOneWidget,
      );
      expect(find.text('Cancelar subida en curso'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.textContaining('creada'), findsNothing);

      // Termina A: B se desbloquea y sigue intacta (no subió nada ahí).
      gate.complete(
        MaterialVersion(id: 'ver-4', materialId: 'mat-A', versionNumber: 4),
      );
      expect(await futureA, isTrue);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('subida en curso en otro material'),
        findsNothing,
      );
      expect(find.textContaining('creada'), findsNothing);
      // Al elegir archivo, la confirmación de B ya se habilita.
      await tester.tap(find.textContaining('Seleccionar archivo'));
      await tester.pumpAndSettle();
      expect(confirmButton().onPressed, isNotNull);
      expect(
        container.read(materialVersionUploadProvider('mat-A')).isSuccess,
        isTrue,
      );
      expect(
        container.read(materialVersionUploadProvider('mat-B')).isIdle,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('cancelar la subida en curso desde B desbloquea la hoja', (
      tester,
    ) async {
      final gate = Completer<MaterialVersion>();
      final fake = _FakeVersionRepository();
      fake.onCreate = (materialId, file) async {
        if (materialId != 'mat-A') {
          return MaterialVersion(
            id: 'ver-6',
            materialId: materialId,
            versionNumber: 6,
          );
        }
        final token = fake.lastCancelToken;
        if (token != null) {
          await Future.any([gate.future, token.whenCancel]);
          if (token.isCancelled) {
            throw DioException(
              requestOptions: RequestOptions(),
              type: DioExceptionType.cancel,
            );
          }
        } else {
          await gate.future;
        }
        return MaterialVersion(
          id: 'ver-4',
          materialId: materialId,
          versionNumber: 4,
        );
      };
      final container = ProviderContainer(
        overrides: [dioMaterialRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      final futureA = container
          .read(materialVersionUploadProvider('mat-A').notifier)
          .uploadVersion(
            'mat-A',
            LocalMaterialFile(
              fileName: 'a-v4.pdf',
              mimeType: 'application/pdf',
              bytes: const [1, 2, 3],
            ),
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: MaterialVersionUploadSheet(
                materialId: 'mat-B',
                currentVersionNumber: 5,
                pickFile: () async => MaterialPickedFile(
                  fileName: 'b-v6.pdf',
                  sizeBytes: 3,
                  mimeType: 'application/pdf',
                  bytes: Uint8List.fromList(const [1, 2, 3]),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Confirmar subida de v6'), findsOneWidget);
      await tester.tap(find.text('Cancelar subida en curso'));
      await tester.pumpAndSettle();

      // La cancelación libera el bloqueo y B queda habilitada.
      expect(await futureA, isFalse);
      expect(
        find.textContaining('subida en curso en otro material'),
        findsNothing,
      );
      await tester.tap(find.textContaining('Seleccionar archivo'));
      await tester.pumpAndSettle();
      final confirm = tester.widget<AppPrimaryButton>(
        find.widgetWithText(AppPrimaryButton, 'Confirmar subida de v6'),
      );
      expect(confirm.onPressed, isNotNull);
      expect(find.textContaining('creada'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
