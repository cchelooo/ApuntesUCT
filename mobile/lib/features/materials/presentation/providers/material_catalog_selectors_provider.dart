import 'package:apuntesuct_mobile/features/materials/data/dio_catalog_selector_repository.dart';
import 'package:apuntesuct_mobile/models/career_model.dart';
import 'package:apuntesuct_mobile/models/professor_model.dart';
import 'package:apuntesuct_mobile/models/subject_model.dart';
import 'package:apuntesuct_mobile/models/university_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Selectores académicos del formulario de subida con UUID reales de
/// Catalog (#287). Sustituyen los `mockList()` (ids ficticios como
/// `subj-eda-uuid`) que el backend rechaza con 400.
///
/// Cada nivel depende del anterior; con padre nulo se resuelve `[]` sin
/// red para mantener los dropdowns deshabilitados. En tests se sustituyen
/// por `overrideWithValue` con fixtures de UUID válidos.
final uploadUniversitiesProvider =
    FutureProvider.autoDispose<List<UniversityModel>>((ref) {
      return ref.watch(catalogSelectorRepositoryProvider).listUniversities();
    });

final uploadCareersProvider =
    FutureProvider.autoDispose.family<List<CareerModel>, String?>(
      (ref, universityId) {
        if (universityId == null) return [];
        return ref
            .watch(catalogSelectorRepositoryProvider)
            .listCareers(universityId: universityId);
      },
    );

final uploadSubjectsProvider =
    FutureProvider.autoDispose.family<List<SubjectModel>, String?>(
      (ref, careerId) {
        if (careerId == null) return [];
        return ref
            .watch(catalogSelectorRepositoryProvider)
            .listSubjects(careerId: careerId);
      },
    );

final uploadProfessorsProvider =
    FutureProvider.autoDispose.family<List<ProfessorModel>, String?>(
      (ref, subjectId) {
        if (subjectId == null) return [];
        return ref
            .watch(catalogSelectorRepositoryProvider)
            .listProfessors(subjectId: subjectId);
      },
    );
