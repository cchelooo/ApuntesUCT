import 'package:flutter/material.dart';

import '../../../../core/theme/uct_palette.dart';
import '../../domain/profile_models.dart';

/// Sección horizontal de cursos inscritos en el perfil del estudiante.
class ProfileCoursesSection extends StatelessWidget {
  const ProfileCoursesSection({super.key, required this.courses});

  final List<ProfileCourseItem> courses;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    final colorSemestre = esOscuro ? UctPalette.celeste : UctPalette.azul;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Encabezado: "Cursos" + "Semestre 2"
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Cursos',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Filtrado por Semestre 2'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                child: Text(
                  'Semestre 2',
                  style: TextStyle(
                    color: colorSemestre,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Lista horizontal de tarjetas de cursos
        SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: courses.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final course = courses[index];
              return _CourseCard(item: course, esOscuro: esOscuro);
            },
          ),
        ),
      ],
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.item, required this.esOscuro});

  final ProfileCourseItem item;
  final bool esOscuro;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 145,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: item.backgroundColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: esOscuro
            ? null
            : [
                BoxShadow(
                  color: item.backgroundColor.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            item.title,
            style: TextStyle(
              color: item.textColor,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            item.subtitle,
            style: TextStyle(
              color: item.textColor.withValues(alpha: 0.9),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
