import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/uct_palette.dart';
import '../../domain/profile_models.dart';
import '../providers/profile_provider.dart';

/// Sección de pestañas ("Material subido" / "Cursos") y cuadrícula de 3 columnas de materiales.
class ProfileMaterialsGrid extends ConsumerWidget {
  const ProfileMaterialsGrid({
    super.key,
    required this.materials,
    required this.courses,
  });

  final List<ProfileMaterialItem> materials;
  final List<ProfileCourseItem> courses;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    final selectedTab = ref.watch(profileTabProvider);

    final colorIndicador = esOscuro ? UctPalette.celeste : UctPalette.azul;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fila de Tabs con línea divisoria
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: colorScheme.outlineVariant, width: 1),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _TabItem(
                  label: 'Material subido',
                  isSelected: selectedTab == ProfileSectionTab.materialSubido,
                  indicatorColor: colorIndicador,
                  onTap: () => ref
                      .read(profileTabProvider.notifier)
                      .selectTab(ProfileSectionTab.materialSubido),
                ),
              ),
              Expanded(
                child: _TabItem(
                  label: 'Cursos',
                  isSelected: selectedTab == ProfileSectionTab.cursos,
                  indicatorColor: colorIndicador,
                  onTap: () => ref
                      .read(profileTabProvider.notifier)
                      .selectTab(ProfileSectionTab.cursos),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Contenido según la pestaña activa
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: selectedTab == ProfileSectionTab.materialSubido
              ? _MaterialGridView(materials: materials, esOscuro: esOscuro)
              : _CoursesDetailedListView(courses: courses, esOscuro: esOscuro),
        ),
      ],
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.label,
    required this.isSelected,
    required this.indicatorColor,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final Color indicatorColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              label,
              style: TextStyle(
                color:
                    isSelected ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          // Línea indicadora inferior azul
          Container(
            height: 3,
            width: isSelected ? 120 : 0,
            decoration: BoxDecoration(
              color: isSelected ? indicatorColor : Colors.transparent,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
            ),
          ),
        ],
      ),
    );
  }
}

class _MaterialGridView extends StatelessWidget {
  const _MaterialGridView({required this.materials, required this.esOscuro});

  final List<ProfileMaterialItem> materials;
  final bool esOscuro;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.82,
      ),
      itemCount: materials.length,
      itemBuilder: (context, index) {
        final item = materials[index];
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: esOscuro
                ? UctPalette.superficieOscura
                : colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: esOscuro
                  ? UctPalette.bordeOscuro
                  : colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item.title,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                item.category,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CoursesDetailedListView extends StatelessWidget {
  const _CoursesDetailedListView({required this.courses, required this.esOscuro});

  final List<ProfileCourseItem> courses;
  final bool esOscuro;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: courses.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final course = courses[index];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: esOscuro
                ? UctPalette.superficieOscura
                : colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: esOscuro
                  ? UctPalette.bordeOscuro
                  : colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: course.backgroundColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  course.title.replaceAll('\n', ' '),
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                course.subtitle,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
