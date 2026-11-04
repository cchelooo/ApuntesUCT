import 'dart:async';

import 'package:apuntesuct_mobile/core/widgets/empty_state.dart';
import 'package:apuntesuct_mobile/core/widgets/error_state.dart';
import 'package:apuntesuct_mobile/core/widgets/loading_state.dart';
import 'package:apuntesuct_mobile/features/catalog/presentation/providers/academic_hierarchy_provider.dart';
import 'package:apuntesuct_mobile/features/catalog/presentation/widgets/academic_filter_sheet.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/providers/materials_discovery_provider.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/widgets/material_summary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MaterialDiscoveryScreen extends ConsumerStatefulWidget {
  const MaterialDiscoveryScreen({super.key});

  @override
  ConsumerState<MaterialDiscoveryScreen> createState() =>
      _MaterialDiscoveryScreenState();
}

class _MaterialDiscoveryScreenState
    extends ConsumerState<MaterialDiscoveryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 150) {
      ref.read(discoveryMaterialsProvider.notifier).loadNextPage();
    }
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      ref.read(discoveryMaterialsProvider.notifier).setQuery(value.trim());
    });
  }

  void _onClearSearch() {
    _debounceTimer?.cancel();
    _searchController.clear();
    setState(() {});
    ref.read(discoveryMaterialsProvider.notifier).setQuery('');
  }

  void _onClearAll() {
    _debounceTimer?.cancel();
    _searchController.clear();
    setState(() {});
    ref.read(discoveryMaterialsProvider.notifier).clearFilters();
    ref.read(academicHierarchyProvider.notifier).clearFilters();
  }

  void _openFiltersModal(BuildContext context) {
    AcademicFilterSheet.show(
      context,
      onApply: () {
        final hierarchy = ref.read(academicHierarchyProvider);
        ref.read(discoveryMaterialsProvider.notifier).applyHierarchyFilters(
          universityId: hierarchy.selectedUniversityId,
          careerId: hierarchy.selectedCareerId,
          subjectId: hierarchy.selectedSubjectId,
          professorId: hierarchy.selectedProfessorId,
          year: hierarchy.selectedYear,
          type: hierarchy.selectedType,
          universityName: hierarchy.selectedUniversity?.name,
          careerName: hierarchy.selectedCareer?.name,
          subjectName: hierarchy.selectedSubject?.name,
          professorName: hierarchy.selectedProfessor?.name,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(discoveryMaterialsProvider);
    final hierarchyState = ref.watch(academicHierarchyProvider);
    final hasHierarchyFilters =
        hierarchyState.hasActiveFilters || state.hasHierarchyFilters;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Descubrir Materiales'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: SearchBar(
                    controller: _searchController,
                    hintText: 'Buscar apuntes, ramos, docentes...',
                    leading: const Icon(Icons.search),
                    trailing: [
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: _onClearSearch,
                        ),
                    ],
                    onChanged: _onSearchChanged,
                  ),
                ),
                const SizedBox(width: 8),
                Badge(
                  isLabelVisible: hasHierarchyFilters,
                  smallSize: 8,
                  child: IconButton.filledTonal(
                    icon: const Icon(Icons.tune_rounded),
                    tooltip: 'Filtros Académicos',
                    onPressed: () => _openFiltersModal(context),
                  ),
                ),
              ],
            ),
          ),
          if (state.hasHierarchyFilters) _buildActiveFilterChips(state),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await ref.read(discoveryMaterialsProvider.notifier).refresh();
              },
              child: _buildBody(state),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilterChips(DiscoveryMaterialsState state) {
    final chips = <Widget>[];

    if (state.selectedUniversityId != null &&
        state.selectedUniversityId!.isNotEmpty) {
      chips.add(
        Chip(
          key: const Key('active_chip_university'),
          avatar: const Icon(Icons.account_balance_outlined, size: 16),
          label: Text(
            state.selectedUniversityName ?? state.selectedUniversityId!,
          ),
          onDeleted: () {
            ref.read(discoveryMaterialsProvider.notifier).setUniversity(null);
            ref
                .read(academicHierarchyProvider.notifier)
                .selectUniversity(null);
          },
        ),
      );
    }

    if (state.selectedCareerId != null &&
        state.selectedCareerId!.isNotEmpty) {
      chips.add(
        Chip(
          key: const Key('active_chip_career'),
          avatar: const Icon(Icons.school_outlined, size: 16),
          label: Text(state.selectedCareerName ?? state.selectedCareerId!),
          onDeleted: () {
            ref.read(discoveryMaterialsProvider.notifier).setCareer(null);
            ref.read(academicHierarchyProvider.notifier).selectCareer(null);
          },
        ),
      );
    }

    final effectiveSubject = state.selectedSubjectName ??
        state.selectedSubject ??
        state.selectedSubjectId;
    if (effectiveSubject != null && effectiveSubject.isNotEmpty) {
      chips.add(
        Chip(
          key: const Key('active_chip_subject'),
          avatar: const Icon(Icons.menu_book_outlined, size: 16),
          label: Text(effectiveSubject),
          onDeleted: () {
            ref
                .read(discoveryMaterialsProvider.notifier)
                .setSubjectHierarchy(null);
            ref.read(academicHierarchyProvider.notifier).selectSubject(null);
          },
        ),
      );
    }

    if (state.selectedProfessorId != null &&
        state.selectedProfessorId!.isNotEmpty) {
      chips.add(
        Chip(
          key: const Key('active_chip_professor'),
          avatar: const Icon(Icons.person_outline, size: 16),
          label: Text(
            state.selectedProfessorName ?? state.selectedProfessorId!,
          ),
          onDeleted: () {
            ref.read(discoveryMaterialsProvider.notifier).setProfessor(null);
            ref.read(academicHierarchyProvider.notifier).selectProfessor(null);
          },
        ),
      );
    }

    if (state.selectedYear != null) {
      chips.add(
        Chip(
          key: const Key('active_chip_year'),
          avatar: const Icon(Icons.calendar_today_outlined, size: 16),
          label: Text('Año: ${state.selectedYear}'),
          onDeleted: () {
            ref.read(discoveryMaterialsProvider.notifier).setYear(null);
            ref.read(academicHierarchyProvider.notifier).selectYear(null);
          },
        ),
      );
    }

    if (state.selectedType != null && state.selectedType!.isNotEmpty) {
      chips.add(
        Chip(
          key: const Key('active_chip_type'),
          avatar: const Icon(Icons.category_outlined, size: 16),
          label: Text('Tipo: ${state.selectedType!.toUpperCase()}'),
          onDeleted: () {
            ref.read(discoveryMaterialsProvider.notifier).setType(null);
            ref.read(academicHierarchyProvider.notifier).selectType(null);
          },
        ),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            ...chips.expand((c) => [c, const SizedBox(width: 8)]),
            ActionChip(
              key: const Key('clear_all_filters_button'),
              avatar: const Icon(Icons.close_rounded, size: 16),
              label: const Text('Limpiar todo'),
              onPressed: _onClearAll,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(DiscoveryMaterialsState state) {
    if (state.isLoading) {
      return const LoadingState(message: 'Buscando materiales...');
    }

    // Criterio 3: Falla en pull-to-refresh o carga inicial expone ErrorState sin crash
    if (state.errorMessage != null) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ErrorState.fromMessage(
            error: state.error,
            message: state.errorMessage!,
            onRetry: () =>
                ref.read(discoveryMaterialsProvider.notifier).refresh(),
          ),
        ),
      );
    }

    if (state.items.isEmpty) {
      final isFiltered = state.isSearchActive;
      final queryText = state.query.isNotEmpty ? ' para "${state.query}"' : '';
      final subjectLabel = state.selectedSubjectName ?? state.selectedSubject;
      final subjectText = subjectLabel != null ? ' en "$subjectLabel"' : '';

      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                EmptyState(
                  title: isFiltered
                      ? 'Sin coincidencias'
                      : 'Catálogo de materiales vacío',
                  subtitle: isFiltered
                      ? 'No encontramos materiales$queryText$subjectText.'
                      : 'Aún no se han registrado materiales académicos.',
                ),
                // Criterio 4: Opción visible para limpiar filtros y búsqueda
                if (isFiltered) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    key: const Key('empty_state_clear_button'),
                    onPressed: _onClearAll,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Limpiar filtros y búsqueda'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: state.items.length + (state.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == state.items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          );
        }
        final item = state.items[index];
        return MaterialSummaryCard(
          material: item,
          onTap: () => context.push('/materials/${item.id}'),
        );
      },
    );
  }
}
