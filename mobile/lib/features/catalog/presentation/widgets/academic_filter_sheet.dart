import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:apuntesuct_mobile/core/theme/uct_palette.dart';
import 'package:apuntesuct_mobile/features/catalog/presentation/providers/academic_hierarchy_provider.dart';
import 'package:apuntesuct_mobile/models/university_model.dart';

/// Modal inferior interactivo para configurar y aplicar los 6 filtros oficiales del Catálogo:
/// 1. Universidad
/// 2. Carrera
/// 3. Asignatura
/// 4. Profesor
/// 5. Año
/// 6. Tipo
class AcademicFilterSheet extends ConsumerStatefulWidget {
  final VoidCallback? onApply;

  const AcademicFilterSheet({super.key, this.onApply});

  /// Muestra el modal de filtros configurado con diseño responsivo.
  static Future<void> show(BuildContext context, {VoidCallback? onApply}) {
    final colorScheme = Theme.of(context).colorScheme;

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => AcademicFilterSheet(onApply: onApply),
    );
  }

  @override
  ConsumerState<AcademicFilterSheet> createState() =>
      _AcademicFilterSheetState();
}

class _AcademicFilterSheetState extends ConsumerState<AcademicFilterSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(academicHierarchyProvider);
      if (state.universities.isEmpty && !state.isLoadingUniversities) {
        ref
            .read(academicHierarchyProvider.notifier)
            .setUniversities(UniversityModel.mockList());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hierarchyState = ref.watch(academicHierarchyProvider);
    final notifier = ref.read(academicHierarchyProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final colorFondoCampo = isDark
        ? UctPalette.superficieElevadaOscura
        : UctPalette.humo;
    final colorBordeCampo = isDark
        ? UctPalette.bordeOscuro
        : UctPalette.bordeClaro;
    final colorPrimario = isDark ? UctPalette.amarillo : UctPalette.azul;
    final colorTextoBotonPrimario = isDark ? UctPalette.navy : Colors.white;

    final activeFiltersCount = hierarchyState.activeFiltersCount;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 12,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra de arrastre superior
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark
                        ? UctPalette.bordeOscuro
                        : Colors.black.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Encabezado del modal
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? UctPalette.superficieElevadaOscura
                          : const Color(0xFFEAF3FA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.tune_rounded,
                      color: colorPrimario,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Filtros del Catálogo',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          activeFiltersCount > 0
                              ? '$activeFiltersCount filtro(s) activo(s)'
                              : '6 filtros en orden oficial',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: isDark
                                    ? UctPalette.textoSuaveOscuro
                                    : UctPalette.textoSuaveClaro,
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (hierarchyState.hasActiveFilters)
                    TextButton(
                      key: const Key('filter_reset_button'),
                      onPressed: () => notifier.resetSelection(),
                      child: Text(
                        'Limpiar',
                        style: TextStyle(
                          color: isDark
                              ? UctPalette.amarillo
                              : UctPalette.azulOscuro,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  IconButton(
                    key: const Key('filter_close_button'),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Banner orientativo de cascada
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1B232D)
                      : UctPalette.celesteClaro.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? UctPalette.bordeOscuro
                        : UctPalette.celesteTinte,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: isDark ? UctPalette.celeste : UctPalette.azul,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Selecciona en orden para habilitar los niveles siguientes en cascada.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? UctPalette.textoSuaveOscuro
                              : UctPalette.azulOscuro,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 1. Selector de Universidad
              _buildDropdownSection(
                context: context,
                label: '1. Universidad',
                icon: Icons.account_balance_outlined,
                isLoading: hierarchyState.isLoadingUniversities,
                dropdown: KeyedSubtree(
                  key: ValueKey('university_${hierarchyState.selectedUniversityId}'),
                  child: DropdownButtonFormField<String>(
                    key: const Key('filter_university_dropdown'),
                    initialValue: hierarchyState.selectedUniversityId,
                    isExpanded: true,
                    hint: const Text('Seleccionar universidad...'),
                    decoration: _inputDecoration(
                      colorFondoCampo,
                      colorBordeCampo,
                    ),
                    items: hierarchyState.universities
                        .map(
                          (u) => DropdownMenuItem(
                            value: u.id,
                            child: Text(u.name, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => notifier.selectUniversity(val),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 2. Selector de Carrera
              _buildDropdownSection(
                context: context,
                label: '2. Carrera',
                icon: Icons.school_outlined,
                isLoading: hierarchyState.isLoadingCareers,
                dropdown: KeyedSubtree(
                  key: ValueKey('career_${hierarchyState.selectedCareerId}'),
                  child: DropdownButtonFormField<String>(
                    key: const Key('filter_career_dropdown'),
                    initialValue: hierarchyState.selectedCareerId,
                    isExpanded: true,
                    hint: Text(
                      !hierarchyState.isUniversitySelected
                          ? 'Selecciona una universidad primero'
                          : 'Seleccionar carrera...',
                      style: TextStyle(
                        color: !hierarchyState.canSelectCareer
                            ? (isDark
                                  ? UctPalette.textoTenueOscuro
                                  : UctPalette.textoCampoClaro)
                            : null,
                      ),
                    ),
                    decoration: _inputDecoration(
                      colorFondoCampo,
                      colorBordeCampo,
                      enabled: hierarchyState.canSelectCareer,
                    ),
                    items: hierarchyState.canSelectCareer
                        ? hierarchyState.careers
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c.id,
                                  child: Text(c.name, overflow: TextOverflow.ellipsis),
                                ),
                              )
                              .toList()
                        : null,
                    onChanged: hierarchyState.canSelectCareer
                        ? (val) => notifier.selectCareer(val)
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 3. Selector de Asignatura
              _buildDropdownSection(
                context: context,
                label: '3. Asignatura',
                icon: Icons.menu_book_outlined,
                isLoading: hierarchyState.isLoadingSubjects,
                dropdown: KeyedSubtree(
                  key: ValueKey('subject_${hierarchyState.selectedSubjectId}'),
                  child: DropdownButtonFormField<String>(
                    key: const Key('filter_subject_dropdown'),
                    initialValue: hierarchyState.selectedSubjectId,
                    isExpanded: true,
                    hint: Text(
                      !hierarchyState.isCareerSelected
                          ? 'Selecciona una carrera primero'
                          : 'Seleccionar asignatura...',
                      style: TextStyle(
                        color: !hierarchyState.canSelectSubject
                            ? (isDark
                                  ? UctPalette.textoTenueOscuro
                                  : UctPalette.textoCampoClaro)
                            : null,
                      ),
                    ),
                    decoration: _inputDecoration(
                      colorFondoCampo,
                      colorBordeCampo,
                      enabled: hierarchyState.canSelectSubject,
                    ),
                    items: hierarchyState.canSelectSubject
                        ? hierarchyState.subjects
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s.id,
                                  child: Text(
                                    '${s.code} - ${s.name}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList()
                        : null,
                    onChanged: hierarchyState.canSelectSubject
                        ? (val) => notifier.selectSubject(val)
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 4. Selector de Profesor
              _buildDropdownSection(
                context: context,
                label: '4. Profesor / Docente',
                icon: Icons.person_outline,
                isLoading: hierarchyState.isLoadingProfessors,
                dropdown: KeyedSubtree(
                  key: ValueKey('professor_${hierarchyState.selectedProfessorId}'),
                  child: DropdownButtonFormField<String>(
                    key: const Key('filter_professor_dropdown'),
                    initialValue: hierarchyState.selectedProfessorId,
                    isExpanded: true,
                    hint: Text(
                      !hierarchyState.isSubjectSelected
                          ? 'Selecciona una asignatura primero'
                          : 'Seleccionar profesor (opcional)...',
                      style: TextStyle(
                        color: !hierarchyState.canSelectProfessor
                            ? (isDark
                                  ? UctPalette.textoTenueOscuro
                                  : UctPalette.textoCampoClaro)
                            : null,
                      ),
                    ),
                    decoration: _inputDecoration(
                      colorFondoCampo,
                      colorBordeCampo,
                      enabled: hierarchyState.canSelectProfessor,
                    ),
                    items: hierarchyState.canSelectProfessor
                        ? hierarchyState.professors
                              .map(
                                (p) => DropdownMenuItem(
                                  value: p.id,
                                  child: Text(
                                    p.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList()
                        : null,
                    onChanged: hierarchyState.canSelectProfessor
                        ? (val) => notifier.selectProfessor(val)
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 5. Selector de Año Académico
              _buildDropdownSection(
                context: context,
                label: '5. Año Académico',
                icon: Icons.calendar_today_outlined,
                dropdown: KeyedSubtree(
                  key: ValueKey('year_${hierarchyState.selectedYear}'),
                  child: DropdownButtonFormField<int>(
                    key: const Key('filter_year_dropdown'),
                    initialValue: hierarchyState.selectedYear,
                    isExpanded: true,
                    hint: const Text('Todos los años...'),
                    decoration: _inputDecoration(
                      colorFondoCampo,
                      colorBordeCampo,
                    ),
                    items: hierarchyState.availableYears
                        .map(
                          (y) => DropdownMenuItem(
                            value: y,
                            child: Text(y.toString()),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => notifier.selectYear(val),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 6. Selector de Tipo de Material
              _buildDropdownSection(
                context: context,
                label: '6. Tipo de Material',
                icon: Icons.category_outlined,
                dropdown: KeyedSubtree(
                  key: ValueKey('type_${hierarchyState.selectedType}'),
                  child: DropdownButtonFormField<String>(
                    key: const Key('filter_type_dropdown'),
                    initialValue: hierarchyState.selectedType,
                    isExpanded: true,
                    hint: const Text('Todos los tipos...'),
                    decoration: _inputDecoration(
                      colorFondoCampo,
                      colorBordeCampo,
                    ),
                    items: hierarchyState.availableTypes
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(t.toUpperCase()),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => notifier.selectType(val),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Botón de Aplicar Filtros
              ElevatedButton.icon(
                key: const Key('filter_apply_button'),
                icon: const Icon(Icons.check_rounded),
                label: Text(
                  activeFiltersCount > 0
                      ? 'Aplicar ($activeFiltersCount) filtros'
                      : 'Ver todos los materiales',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorPrimario,
                  foregroundColor: colorTextoBotonPrimario,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () {
                  widget.onApply?.call();
                  Navigator.of(context).pop();
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownSection({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Widget dropdown,
    bool isLoading = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            if (isLoading) ...[
              const SizedBox(width: 8),
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        dropdown,
      ],
    );
  }

  InputDecoration _inputDecoration(
    Color fondo,
    Color borde, {
    bool enabled = true,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: enabled ? fondo : fondo.withValues(alpha: 0.5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borde),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borde),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borde.withValues(alpha: 0.4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: UctPalette.azul, width: 1.5),
      ),
    );
  }
}
