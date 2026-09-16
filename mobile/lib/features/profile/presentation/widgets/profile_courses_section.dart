import 'package:flutter/material.dart';

import '../../../../core/widgets/app_horizontal_list.dart';
import '../../../../core/widgets/app_section_header.dart';
import '../../domain/profile_models.dart';

/// Sección horizontal de cursos inscritos en el perfil del estudiante.
class ProfileCoursesSection extends StatelessWidget {
  const ProfileCoursesSection({super.key, required this.courses});

  final List<ProfileCourseItem> courses;

  @override
  Widget build(BuildContext context) {
    final esOscuro = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: 'Cursos',
          actionLabel: 'Semestre 2',
          onAction: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Filtrado por Semestre 2'),
                duration: Duration(seconds: 1),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        AppHorizontalList(
          height: 104,
          itemCount: courses.length,
          itemBuilder: (context, index) {
            final course = courses[index];
            return _CourseCard(item: course, esOscuro: esOscuro);
          },
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
