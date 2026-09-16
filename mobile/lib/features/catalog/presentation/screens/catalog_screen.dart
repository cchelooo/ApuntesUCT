import 'package:flutter/material.dart';

import '../widgets/material_card.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final TextEditingController _searchController = TextEditingController();

  // Lista mock de materiales para la maqueta inicial
  final List<Map<String, String>> _allMaterials = [
    {
      'title': 'Cálculo Diferencial e Integral',
      'author': 'James Stewart',
      'subject': 'Matemáticas',
    },
    {
      'title': 'Álgebra Lineal y sus Aplicaciones',
      'author': 'David C. Lay',
      'subject': 'Álgebra',
    },
    {
      'title': 'Estructuras de Datos y Algoritmos',
      'author': 'Mark Allen Weiss',
      'subject': 'Informática',
    },
    {
      'title': 'Física Universitaria Vol. 1',
      'author': 'Sears y Zemansky',
      'subject': 'Física',
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.toLowerCase();
    final filteredMaterials = _allMaterials.where((item) {
      final title = item['title']!.toLowerCase();
      final author = item['author']!.toLowerCase();
      final subject = item['subject']!.toLowerCase();
      return title.contains(query) ||
          author.contains(query) ||
          subject.contains(query);
    }).toList();

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
                    onPressed: () {
                      setState(() {
                        _searchController.clear();
                      });
                    },
                  ),
              ],
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredMaterials.length,
              itemBuilder: (context, index) {
                final item = filteredMaterials[index];
                return MaterialCard(
                  title: item['title']!,
                  author: item['author']!,
                  subject: item['subject']!,
                  onTap: null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
