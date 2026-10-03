import 'package:apuntesuct_mobile/features/materials/data/mock_materials_repository.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_summary.dart';
import 'package:apuntesuct_mobile/features/materials/domain/repositories/materials_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final materialsRepositoryProvider = Provider<MaterialsRepository>((ref) {
  return MockMaterialsRepository();
});

class DiscoveryFilterState {
  final String query;
  final String? selectedSubject;

  const DiscoveryFilterState({this.query = '', this.selectedSubject});

  DiscoveryFilterState copyWith({
    String? query,
    String? selectedSubject,
    bool clearSubject = false,
  }) {
    return DiscoveryFilterState(
      query: query ?? this.query,
      selectedSubject: clearSubject
          ? null
          : (selectedSubject ?? this.selectedSubject),
    );
  }
}

class DiscoveryFilterNotifier extends Notifier<DiscoveryFilterState> {
  @override
  DiscoveryFilterState build() {
    return const DiscoveryFilterState();
  }

  void setQuery(String query) {
    state = state.copyWith(query: query);
  }

  void setSubject(String? subject) {
    state = DiscoveryFilterState(query: state.query, selectedSubject: subject);
  }

  void clearSubject() {
    state = DiscoveryFilterState(query: state.query, selectedSubject: null);
  }

  void reset() {
    state = const DiscoveryFilterState();
  }
}

final discoveryFilterProvider =
    NotifierProvider<DiscoveryFilterNotifier, DiscoveryFilterState>(() {
      return DiscoveryFilterNotifier();
    });

final paginatedMaterialsProvider =
    FutureProvider.autoDispose<List<MaterialSummary>>((ref) async {
      final repository = ref.watch(materialsRepositoryProvider);
      final filters = ref.watch(discoveryFilterProvider);

      return repository.getMaterials(
        query: filters.query,
        subject: filters.selectedSubject,
      );
    });
