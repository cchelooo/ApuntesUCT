import 'dart:async';

import 'package:apuntesuct_mobile/core/widgets/empty_state.dart';
import 'package:apuntesuct_mobile/core/widgets/error_state.dart';
import 'package:apuntesuct_mobile/core/widgets/loading_state.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_summary.dart';
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
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      ref.read(discoveryFilterProvider.notifier).setQuery(value.trim());
    });
  }

  void _openFiltersModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
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
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    label: const Text('Todas'),
                    onPressed: () {
                      ref.read(discoveryFilterProvider.notifier).clearSubject();
                      Navigator.pop(ctx);
                    },
                  ),
                  ActionChip(
                    label: const Text('Estructuras de Datos'),
                    onPressed: () {
                      ref
                          .read(discoveryFilterProvider.notifier)
                          .setSubject('Estructuras de Datos');
                      Navigator.pop(ctx);
                    },
                  ),
                  ActionChip(
                    label: const Text('Cálculo I'),
                    onPressed: () {
                      ref
                          .read(discoveryFilterProvider.notifier)
                          .setSubject('Cálculo I');
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final materialsAsync = ref.watch(paginatedMaterialsProvider);
    final filterState = ref.watch(discoveryFilterProvider);

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
                          onPressed: () {
                            setState(() => _searchController.clear());
                            ref
                                .read(discoveryFilterProvider.notifier)
                                .setQuery('');
                          },
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
          if (filterState.selectedSubject != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  avatar: const Icon(Icons.check, size: 16),
                  label: Text(filterState.selectedSubject!),
                  onDeleted: () {
                    ref.read(discoveryFilterProvider.notifier).clearSubject();
                  },
                ),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(paginatedMaterialsProvider);
                try {
                  await ref.read(paginatedMaterialsProvider.future);
                } catch (_) {}
              },
              child: materialsAsync.when(
                loading: () =>
                    const LoadingState(message: 'Buscando materiales...'),
                error: (error, _) => Center(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: ErrorState(
                      message: 'Error al cargar materiales disponibles.',
                      onRetry: () => ref.invalidate(paginatedMaterialsProvider),
                    ),
                  ),
                ),
                data: (List<MaterialSummary> materials) {
                  if (materials.isEmpty) {
                    return const Center(
                      child: SingleChildScrollView(
                        physics: AlwaysScrollableScrollPhysics(),
                        child: EmptyState(
                          title: 'No se encontraron materiales',
                          subtitle: 'Intenta modificando los términos de búsqueda o filtros.',
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: materials.length,
                    itemBuilder: (context, index) {
                      return MaterialSummaryCard(material: materials[index]);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
