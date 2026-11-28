import 'package:apuntesuct_mobile/core/errors/api_exception.dart';

import 'dart:convert';

import 'package:apuntesuct_mobile/core/network/api_client.dart';
import 'package:apuntesuct_mobile/core/session/auth_session.dart';
import 'package:apuntesuct_mobile/core/session/session_controller.dart';
import 'package:apuntesuct_mobile/core/session/session_storage.dart';
import 'package:apuntesuct_mobile/features/auth/data/dio_auth_repository.dart';
import 'package:apuntesuct_mobile/features/auth/data/mock_auth_repository.dart';
import 'package:apuntesuct_mobile/features/materials/data/dio_material_repository.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/academic_reference.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_requests.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/providers/material_upload_provider.dart';
import 'package:apuntesuct_mobile/main.dart' as app;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Opt-in: real Gateway, RSA Auth and native secure storage; no provider overrides.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment('RUN_NATIVE_SESSION_SMOKE');
  const materialId = String.fromEnvironment('EXPECTED_MATERIAL_ID');
  const universityId = String.fromEnvironment('EXPECTED_UNIVERSITY_ID');
  const careerId = String.fromEnvironment('EXPECTED_CAREER_ID');
  const subjectId = String.fromEnvironment('EXPECTED_SUBJECT_ID');

  testWidgets(
    'sesión real, subida, versionado, rechazo de autoría y restauración segura',
    (tester) async {
      expect(materialId, isNotEmpty);
      expect([universityId, careerId, subjectId], everyElement(isNotEmpty));
      var container = ProviderContainer();
      addTearDown(() => container.dispose());
      await container.read(sessionStorageProvider).delete();
      container
          .read(apiclientProvider)
          .dio
          .interceptors
          .add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                if (options.path == '/auth/login') {
                  expect(options.data['email'], 'qa278@alu.uct.cl');
                }
                handler.next(options);
              },
            ),
          );
      app.appRouter.go('/login');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const app.MyApp(),
        ),
      );
      await _wait(tester, () => !container.read(authStateProvider).isLoading);
      await tester.enterText(find.byType(TextFormField).first, 'qa278');
      await tester.enterText(find.byType(TextFormField).last, 'incorrecta');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.tap(find.text('Ingresar'));
      await _wait(tester, () => container.read(authStateProvider).hasError);
      expect(app.appRouter.state.uri.path, '/login');
      expect(container.read(sessionControllerProvider).current, isNull);

      await _wait(
        tester,
        () => tester
            .widget<TextFormField>(find.byType(TextFormField).last)
            .enabled,
      );
      tester
              .widget<TextFormField>(find.byType(TextFormField).last)
              .controller!
              .text =
          'ApuntesQA2026!';
      await tester.pump();
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).last)
            .controller
            ?.text,
        'ApuntesQA2026!',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ingresar'));
      await _wait(tester, () => !container.read(authStateProvider).isLoading);
      expect(
        container.read(authStateProvider).hasError,
        isFalse,
        reason: container.read(authStateProvider).error.toString(),
      );
      await _wait(tester, () => app.appRouter.state.uri.path == '/');
      expect(
        container.read(authStateProvider).asData?.value?.name,
        'Estudiante QA',
      );
      final session = container.read(sessionControllerProvider).current!;
      final stored = await container.read(sessionStorageProvider).read();
      expect(stored, contains(session.accessToken));
      expect(stored, isNot(contains('ApuntesQA2026!')));
      final file = LocalMaterialFile(
        fileName: 'session.pdf',
        mimeType: 'application/pdf',
        bytes: utf8.encode('%PDF-1.4\n% Session smoke\n%%EOF\n'),
      );
      final url = Uri.parse('https://example.org/material-qa');
      final upload = container.read(materialUploadProvider.notifier);
      for (final (type, source) in [
        ('DOCUMENT', file),
        ('LINK', ExternalMaterialLink(url)),
      ]) {
        expect(
          await upload.upload(
            UploadMaterialRequest(
              title: 'Material Mobile QA $type',
              year: 2026,
              type: type,
              university: AcademicReference(id: universityId),
              career: AcademicReference(id: careerId),
              subject: AcademicReference(id: subjectId),
              source: source,
            ),
          ),
          isTrue,
          reason: container.read(materialUploadProvider).errorMessage,
        );
        final created = container.read(materialUploadProvider).created!;
        expect(created.isSimulatedResponse, isFalse);
        expect(created.summary.status, 'PENDING_REVIEW');
        expect(created.summary.subject?.id, subjectId);
        expect(created.externalLink, type == 'LINK' ? url.toString() : isNull);
      }
      final version = await container
          .read(dioMaterialRepositoryProvider)
          .createVersion(materialId, file);
      expect(
        version.id,
        isNotEmpty,
      ); // Material verified the signature and author.

      final otherSession = SessionController(MemorySessionStorage());
      final otherClient = ApiClient(session: otherSession);
      addTearDown(() {
        otherClient.dio.close(force: true);
        otherSession.dispose();
      });
      final otherAuth = DioAuthRepository(otherClient);
      final otherEmail =
          'qa278.${DateTime.now().millisecondsSinceEpoch}@alu.uct.cl';
      await otherAuth.register(
        name: 'Estudiante QA alternativo',
        email: otherEmail,
        password: 'ApuntesQA2026!',
      );
      await otherAuth.login(email: otherEmail, password: 'ApuntesQA2026!');
      final current = otherSession.current;
      expect(current, isNotNull);
      expect(current!.user.id, isNot(session.user.id));
      await expectLater(
        DioMaterialRepository(otherClient).createVersion(materialId, file),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'HTTP', 403)),
      );
      expect(otherSession.current, same(current));

      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      container = ProviderContainer();
      app.appRouter.go('/profile');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const app.MyApp(),
        ),
      );
      await _wait(
        tester,
        () =>
            app.appRouter.state.uri.path == '/profile' &&
            find.text('Estudiante QA').evaluate().isNotEmpty,
      );
      expect(
        container.read(sessionControllerProvider).current?.accessToken,
        session.accessToken,
      );

      await container.read(authStateProvider.notifier).logout();
      await _wait(tester, () => app.appRouter.state.uri.path == '/login');
      expect(await container.read(sessionStorageProvider).read(), isNull);
      app.appRouter.go('/materials/upload');
      await tester.pumpAndSettle();
      expect(app.appRouter.state.uri.path, '/login');

      // Same legitimate claims, deliberately broken signature: only server rejects it.
      final saved = jsonDecode(stored!) as Map<String, dynamic>;
      final parts = (saved['accessToken'] as String).split('.');
      parts[2] = '${parts[2][0] == 'A' ? 'B' : 'A'}${parts[2].substring(1)}';
      saved['accessToken'] = parts.join('.');
      final controller = container.read(sessionControllerProvider);
      await controller.accept(
        AuthSession.fromLogin(saved, DateTime.now()),
        controller.beginLogin(),
      );
      await tester.pumpAndSettle();
      await expectLater(
        container
            .read(dioMaterialRepositoryProvider)
            .createVersion(materialId, file),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'HTTP', 401)),
      );
      await _wait(tester, () => app.appRouter.state.uri.path == '/login');
      expect(container.read(sessionControllerProvider).current, isNull);
      expect(await container.read(sessionStorageProvider).read(), isNull);
      expect(
        container.read(apiclientProvider).dio.options.headers.toString(),
        isNot(contains(session.accessToken)),
      );
    },
    skip: !enabled,
  );
}

Future<void> _wait(WidgetTester tester, bool Function() condition) async {
  for (var i = 0; i < 150; i++) {
    await tester.pump(const Duration(milliseconds: 200));
    if (condition()) {
      await tester.pumpAndSettle();
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  fail('No se completó el flujo nativo en el plazo esperado.');
}
