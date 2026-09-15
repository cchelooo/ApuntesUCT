import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/material_card_data.dart';
import '../models/subject_model.dart';

/// Par de [SubjectModel] con el conteo de apuntes disponibles, solo para UI.
class CourseEntry {
  final SubjectModel subject;
  final int materialCount;

  const CourseEntry({required this.subject, required this.materialCount});
}

// ---------------------------------------------------------------------------
// Estado
// ---------------------------------------------------------------------------

/// Estado inmutable que expone la Home al widget layer.
class HomeState {
  final List<CourseEntry> courses;
  final List<MaterialCardData> recommended;
  final List<MaterialCardData> topRated;

  const HomeState({
    required this.courses,
    required this.recommended,
    required this.topRated,
  });

  HomeState copyWith({
    List<CourseEntry>? courses,
    List<MaterialCardData>? recommended,
    List<MaterialCardData>? topRated,
  }) {
    return HomeState(
      courses: courses ?? this.courses,
      recommended: recommended ?? this.recommended,
      topRated: topRated ?? this.topRated,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

/// Controla los datos de la pantalla Home.
///
/// Por ahora retorna datos MOCK — en la tarea #68 se reemplazarán las
/// listas estáticas por llamadas reales al API Gateway.
class HomeNotifier extends Notifier<HomeState> {
  @override
  HomeState build() {
    return HomeState(
      courses: _mockCourses(),
      recommended: MaterialCardData.mockRecomendado(),
      topRated: MaterialCardData.mockMejoresCalificados(),
    );
  }

  static List<CourseEntry> _mockCourses() {
    return [
      CourseEntry(
        subject: SubjectModel.mock(
          id: 'subj-calc-uuid',
          code: 'MAT-2101',
          name: 'Cálculo Intermedio',
          description: 'Integrales, series y ecuaciones diferenciales.',
        ),
        materialCount: 38,
      ),
      CourseEntry(
        subject: SubjectModel.mock(
          id: 'subj-grafos-uuid',
          code: 'INF-3201',
          name: 'Teoría de Grafos',
          description: 'Grafos, árboles y algoritmos de recorrido.',
        ),
        materialCount: 21,
      ),
      CourseEntry(
        subject: SubjectModel.mock(
          id: 'subj-bd-uuid',
          code: 'INF-2202',
          name: 'Bases de Datos',
          description: 'Modelo relacional, SQL, normalización.',
        ),
        materialCount: 16,
      ),
    ];
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// Provider global de la Home. Expone [HomeState] listo para pintar.
final homeProvider = NotifierProvider<HomeNotifier, HomeState>(
  HomeNotifier.new,
);

// ---------------------------------------------------------------------------
// Provider del tab activo del bottom navigation bar
// ---------------------------------------------------------------------------

/// Mantiene el índice del tab activo (0-3).
/// Gestionado con Riverpod — los widgets no usan setState para este estado.
class NavTabNotifier extends Notifier<int> {
  @override
  int build() => 0; // Inicio es la tab 0

  void selectTab(int index) => state = index;
}

/// Provider global del índice del tab activo en el bottom navigation bar.
final navTabProvider = NotifierProvider<NavTabNotifier, int>(
  NavTabNotifier.new,
);
