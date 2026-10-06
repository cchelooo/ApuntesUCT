import 'dart:async';

import 'package:apuntesuct_mobile/core/widgets/empty_state.dart';
import 'package:apuntesuct_mobile/core/widgets/error_state.dart';
import 'package:apuntesuct_mobile/core/widgets/loading_state.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/providers/materials_discovery_provider.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/widgets/material_summary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    // Cancelar debounce inmediatamente para evitar que aplique búsquedas previas
    _debounceTimer?.cancel();
    _searchController.clear();
    setState(() {});
    ref.read(discoveryMaterialsProvider.notifier).setQuery('');
  }

  void _openFiltersModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final subjectsAsync = ref.watch(availableSubjectsProvider);

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filtrar por Asignatura',
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  subjectsAsync.when(
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (_, _) =>
                        const Text('No fue posible obtener las asignaturas.'),
                    data: (subjects) {
                      if (subjects.isEmpty) {
                        return const Text(
                          'No hay asignaturas disponibles en el catálogo.',
                          style: TextStyle(color: Colors.grey),
                        );
                      }
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ActionChip(
                            label: const Text('Todas'),
                            onPressed: () {
                              ref
                                  .read(discoveryMaterialsProvider.notifier)
                                  .setSubject(null);
                              Navigator.pop(ctx);
                            },
                          ),
                          ...subjects.map(
                            (s) => ActionChip(
                              label: Text(s),
                              onPressed: () {
                                ref
                                    .read(discoveryMaterialsProvider.notifier)
                                    .setSubject(s);
                                Navigator.pop(ctx);
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(discoveryMaterialsProvider);

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
                IconButton.filledTonal(
                  icon: const Icon(Icons.tune_rounded),
                  tooltip: 'Filtros',
                  onPressed: () => _openFiltersModal(context),
                ),
              ],
            ),
          ),
          if (state.selectedSubject != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  avatar: const Icon(Icons.check, size: 16),
                  label: Text(state.selectedSubject!),
                  onDeleted: () {
                    ref
                        .read(discoveryMaterialsProvider.notifier)
                        .setSubject(null);
                  },
                ),
              ),
            ),
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
      // Distinción entre catálogo sin datos vs búsqueda sin coincidencias
      final isFiltered = state.isSearchActive;
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: EmptyState(
            title: isFiltered
                ? 'Sin coincidencias'
                : 'Catálogo de materiales vacío',
            subtitle: isFiltered
                ? 'No encontramos materiales con esos términos o filtros.'
                : 'Aún no se han registrado materiales académicos.',
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
        return MaterialSummaryCard(material: state.items[index]);
      },
    );
  }
}
