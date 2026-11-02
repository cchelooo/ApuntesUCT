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

  void _onClearAll() {
    _debounceTimer?.cancel();
    _searchController.clear();
    setState(() {});
    ref.read(academicHierarchyProvider.notifier).resetSelection();
    ref.read(discoveryMaterialsProvider.notifier).clearFilters();
  }

  void _openFiltersModal(BuildContext context) {
    AcademicFilterSheet.show(
      context,
      onApply: () {
        final hierarchy = ref.read(academicHierarchyProvider);
        final selectedSubject = hierarchy.selectedSubject;
        final notifier = ref.read(discoveryMaterialsProvider.notifier);
        notifier.setSubject(selectedSubject?.name);
        notifier.setYear(hierarchy.selectedYear);
        notifier.setType(hierarchy.selectedType);
      },
    );
  }

  Widget _buildActiveFilterChips(DiscoveryMaterialsState state) {
    if (!state.hasHierarchyFilters) return const SizedBox.shrink();

    final notifier = ref.read(discoveryMaterialsProvider.notifier);
    final academicNotifier = ref.read(academicHierarchyProvider.notifier);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          if (state.selectedSubject != null) ...[
            Chip(
              avatar: const Icon(Icons.menu_book_outlined, size: 16),
              label: Text(state.selectedSubject!),
              onDeleted: () {
                notifier.setSubjectHierarchy(null);
                academicNotifier.selectSubject(null);
              },
            ),
            const SizedBox(width: 8),
          ],
          if (state.selectedYear != null) ...[
            Chip(
              key: const Key('chip_active_year'),
              avatar: const Icon(Icons.calendar_today, size: 16),
              label: Text('Año: ${state.selectedYear}'),
              onDeleted: () => notifier.clearYear(),
            ),
            const SizedBox(width: 8),
          ],
          if (state.selectedType != null) ...[
            Chip(
              key: const Key('chip_active_type'),
              avatar: const Icon(Icons.category, size: 16),
              label: Text('Tipo: ${state.selectedType}'),
              onDeleted: () => notifier.clearType(),
            ),
            const SizedBox(width: 8),
          ],
          ActionChip(
            key: const Key('chip_clear_all_filters'),
            avatar: const Icon(Icons.close, size: 16),
            label: const Text('Limpiar todo'),
            onPressed: _onClearAll,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(discoveryMaterialsProvider);
    final hasHierarchyFilters = ref.watch(hasAcademicHierarchyFiltersProvider);

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
                      if (_searchController.text.isNotEmpty || state.hasHierarchyFilters)
                        IconButton(
                          key: const Key('clear_search_button'),
                          icon: const Icon(Icons.clear),
                          onPressed: _onClearAll,
                        ),
                    ],
                    onChanged: _onSearchChanged,
                  ),
                ),
                const SizedBox(width: 8),
                Badge(
                  isLabelVisible: hasHierarchyFilters || state.hasHierarchyFilters,
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
          _buildActiveFilterChips(state),
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

  Widget _buildBody(DiscoveryMaterialsState state) {
    if (state.isLoading) {
      return const LoadingState(message: 'Buscando materiales...');
    }

    // Criterio 3: Falla en pull-to-refresh o carga inicial expone ErrorState sin crash
    if (state.errorMessage != null) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ErrorState(
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
      final subjectText = state.selectedSubject != null
          ? ' en "${state.selectedSubject}"'
          : '';
      final yearText = state.selectedYear != null
          ? ' año ${state.selectedYear}'
          : '';
      final typeText = state.selectedType != null
          ? ' tipo ${state.selectedType}'
          : '';

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
                      ? 'No encontramos materiales$queryText$subjectText$yearText$typeText.'
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
