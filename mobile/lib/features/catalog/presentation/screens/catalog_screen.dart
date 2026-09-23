import 'dart:async';

import 'package:apuntesuct_mobile/core/widgets/widgets.dart';
import 'package:apuntesuct_mobile/features/catalog/domain/catalog_item.dart';
import 'package:apuntesuct_mobile/features/catalog/presentation/providers/catalog_provider.dart';
import 'package:apuntesuct_mobile/features/catalog/presentation/widgets/material_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
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
      ref.read(catalogSearchQueryProvider.notifier).setQuery(value.trim());
    });
  }

  void _clearSearch() {
    _debounceTimer?.cancel();
    setState(() {
      _searchController.clear();
    });
    ref.read(catalogSearchQueryProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(catalogListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo de Materiales'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Buscar apuntes, libros, ramos...',
              leading: const Icon(Icons.search),
              trailing: [
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: _clearSearch,
                  ),
              ],
              onChanged: _onSearchChanged,
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(catalogListProvider);
                await ref.read(catalogListProvider.future);
              },
              child: catalogAsync.when(
                loading: () =>
                    const LoadingState(message: 'Cargando catálogo...'),
                error: (error, _) => Center(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: ErrorState(
                      message: 'Error al cargar el catálogo. Por favor intenta nuevamente.',
                      onRetry: () => ref.invalidate(catalogListProvider),
                    ),
                  ),
                ),
                data: (List<CatalogItem> materials) {
                  if (materials.isEmpty) {
                    return Center(
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: EmptyState(
                          title: 'No se encontraron materiales',
                          subtitle: 'Prueba buscando con otro término o revisa la ortografía.',
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: materials.length,
                    itemBuilder: (context, index) {
                      final item = materials[index];
                      return MaterialCard(
                        title: item.title,
                        author: item.author,
                        subject: item.subject,
                        onTap: null,
                      );
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
