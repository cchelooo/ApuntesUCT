import 'package:apuntesuct_mobile/features/materials/domain/models/material_status.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_summary.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/widgets/material_summary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Widget buildTestCard({
    required MaterialSummary material,
    Brightness brightness = Brightness.light,
    double surfaceWidth = 360,
    VoidCallback? onTap,
    GoRouter? router,
  }) {
    final cardWidget = MediaQuery(
      data: MediaQueryData(size: Size(surfaceWidth, 800)),
      child: MaterialSummaryCard(material: material, onTap: onTap),
    );

    if (router != null) {
      return MaterialApp.router(
        theme: ThemeData(useMaterial3: true, brightness: brightness),
        routerConfig: router,
      );
    }

    return MaterialApp(
      theme: ThemeData(useMaterial3: true, brightness: brightness),
      home: Scaffold(body: cardWidget),
    );
  }

  group('Issue #297: Conectar MaterialCard con detalle y estado real', () {
    testWidgets(
      'Criterio 1: Cada tarjeta muestra únicamente campos disponibles en el contrato',
      (WidgetTester tester) async {
        const material = MaterialSummary(
          id: 'mat-real-001',
          title: 'Guía de Cálculo Diferencial',
          description: 'Ejercicios resueltos de límites y derivadas.',
          subjectName: 'Cálculo I',
          careerName: 'Ingeniería Civil Informática',
          professor: 'Dr. Turing',
          materialType: 'guia',
          academicYear: 2026,
          authorName: 'Rossio Álvarez',
          rating: 4.8,
          downloadCount: 15,
        );

        await tester.pumpWidget(buildTestCard(material: material));
        await tester.pumpAndSettle();

        expect(find.text('Guía de Cálculo Diferencial'), findsOneWidget);
        expect(
          find.text('Ejercicios resueltos de límites y derivadas.'),
          findsOneWidget,
        );
        expect(
          find.text('Cálculo I • Ingeniería Civil Informática'),
          findsOneWidget,
        );
        expect(find.text('Prof. Dr. Turing'), findsOneWidget);
        expect(find.text('GUIA'), findsOneWidget);
        expect(find.text('2026'), findsOneWidget);
        expect(find.text('Rossio Álvarez'), findsOneWidget);
        expect(find.text('4.8'), findsOneWidget);
        expect(find.text('15'), findsOneWidget);
      },
    );

    testWidgets(
      'Criterio 2: El estado del material no induce a creer que PENDING_REVIEW está publicado',
      (WidgetTester tester) async {
        const pendingMaterial = MaterialSummary(
          id: 'mat-pending-01',
          title: 'Resumen en Revisión',
          status: 'PENDING_REVIEW',
        );

        await tester.pumpWidget(buildTestCard(material: pendingMaterial));
        await tester.pumpAndSettle();

        final badgeFinder = find.byKey(const Key('material_status_badge'));
        expect(badgeFinder, findsOneWidget);

        // Debe indicar textualmente EN REVISIÓN y nunca PUBLICADO ni APROBADO
        expect(
          find.text(MaterialStatus.pendingReview.label.toUpperCase()),
          findsOneWidget,
        );
        expect(
          find.text(MaterialStatus.published.label.toUpperCase()),
          findsNothing,
        );
        expect(
          find.text(MaterialStatus.approved.label.toUpperCase()),
          findsNothing,
        );

        // Ahora probamos con un material efectivamente publicado
        const publishedMaterial = MaterialSummary(
          id: 'mat-pub-01',
          title: 'Resumen Publicado',
          status: 'PUBLISHED',
        );

        await tester.pumpWidget(buildTestCard(material: publishedMaterial));
        await tester.pumpAndSettle();

        expect(
          find.text(MaterialStatus.published.label.toUpperCase()),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Criterio 3: La navegación utiliza el ID y soporta abrir la ruta directamente',
      (WidgetTester tester) async {
        String? pushedLocation;

        final router = GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => Scaffold(
                body: MaterialSummaryCard(
                  material: const MaterialSummary(
                    id: 'target-id-123',
                    title: 'Material de prueba',
                  ),
                ),
              ),
            ),
            GoRoute(
              path: '/materials/:id',
              builder: (context, state) {
                pushedLocation = state.uri.toString();
                return Scaffold(
                  body: Text('Detalle ID: ${state.pathParameters['id']}'),
                );
              },
            ),
          ],
        );

        await tester.pumpWidget(
          buildTestCard(
            material: const MaterialSummary(
              id: 'target-id-123',
              title: 'Material de prueba',
            ),
            router: router,
          ),
        );
        await tester.pumpAndSettle();

        // Pulsamos la tarjeta
        await tester.tap(find.byType(MaterialSummaryCard));
        await tester.pumpAndSettle();

        // Verifica que la navegación ocurrió con el ID exacto y abrió la ruta
        expect(pushedLocation, '/materials/target-id-123');
        expect(find.text('Detalle ID: target-id-123'), findsOneWidget);
      },
    );

    testWidgets(
      'Criterio 4: Las tarjetas mantienen legibilidad en tema claro/oscuro y pantallas estrechas',
      (WidgetTester tester) async {
        const testMaterial = MaterialSummary(
          id: 'narrow-01',
          title: 'Título sumamente extenso que podría causar overflow en pantallas pequeñas',
          description: 'Descripción también bastante extensa para verificar el manejo de líneas y ellipsis.',
          subjectName: 'Asignatura con Nombre Largo',
          careerName: 'Ingeniería Civil Informática',
          professor: 'Profesor de Apellido Compuesto',
          status: 'PENDING_REVIEW',
        );

        // 1. Pantalla estrecha (300px) en modo claro
        tester.view.physicalSize = const Size(300, 700);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          buildTestCard(
            material: testMaterial,
            surfaceWidth: 300,
            brightness: Brightness.light,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        // 2. Misma tarjeta en modo oscuro
        await tester.pumpWidget(
          buildTestCard(
            material: testMaterial,
            surfaceWidth: 300,
            brightness: Brightness.dark,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );
    testWidgets('Oculta asignatura y carrera cuando el servidor solo entrega IDs sin nombres', (tester) async {
      // Material simulado con nombres vacíos / sin datos del catálogo
      final materialSinNombres = MaterialSummary(
        id: 'mat_empty',
        title: 'Documento de prueba',
        subjectName: '',
        careerName: '',
        materialType: 'Guía',
        authorName: 'Ana Pérez',
        status: 'PUBLISHED',
        rating: 0.0,
        downloadCount: 0,
        // ... los demás campos requeridos por tu modelo con valores por defecto seguros
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MaterialSummaryCard(material: materialSinNombres),
          ),
        ),
      );

      // Verificamos que el título y autor estén presentes, pero NO aparezca el texto genérico o vacío en la zona de asignatura/carrera
      expect(find.text('Documento de prueba'), findsOneWidget);
      expect(find.text('General • UCT'), findsNothing);
    });
  });
}
