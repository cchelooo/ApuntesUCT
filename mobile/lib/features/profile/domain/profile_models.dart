import 'package:flutter/material.dart';

/// Modelo de curso inscrito que se muestra en la sección horizontal del perfil.
class ProfileCourseItem {
  final String id;
  final String title;
  final String subtitle;
  final Color backgroundColor;
  final Color textColor;

  const ProfileCourseItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.backgroundColor,
    required this.textColor,
  });
}

/// Modelo de material subido por el estudiante mostrado en la cuadrícula.
class ProfileMaterialItem {
  final String id;
  final String title;
  final String category;

  const ProfileMaterialItem({
    required this.id,
    required this.title,
    required this.category,
  });
}

/// Modelo de insignia o logro obtenido por el usuario en ApuntesUCT.
class ProfileBadge {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final bool isUnlocked;
  final int currentProgress;
  final int maxProgress;
  final String category;
  final String? unlockedDate;

  const ProfileBadge({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.isUnlocked,
    required this.currentProgress,
    required this.maxProgress,
    required this.category,
    this.unlockedDate,
  });
}

/// Modelo integral que representa los datos de visualización del perfil.
class UserProfileData {
  final String id;
  final String name;
  final String career;
  final String bio;
  final int uploadedCount;
  final int savedCount;
  final double reputation;
  final List<ProfileCourseItem> courses;
  final List<ProfileMaterialItem> uploadedMaterials;
  final List<ProfileBadge> badges;

  const UserProfileData({
    required this.id,
    required this.name,
    required this.career,
    required this.bio,
    required this.uploadedCount,
    required this.savedCount,
    required this.reputation,
    required this.courses,
    required this.uploadedMaterials,
    this.badges = const [],
  });

  /// Factory con los datos de ejemplo fieles a la maqueta de referencia.
  factory UserProfileData.mock({String? customName}) {
    return UserProfileData(
      id: 'usr-marcelo-santana',
      name: customName ?? 'Marcelo Santana',
      career: 'Ingeniería Civil Informática',
      bio:
          'Estudiante de Ingeniería Civil Informática. Comparte guías, apuntes y resúmenes verificados por ramo.',
      uploadedCount: 8,
      savedCount: 42,
      reputation: 4.8,
      courses: const [
        ProfileCourseItem(
          id: 'c-1',
          title: 'Arquitectura\nde Software',
          subtitle: 'INT4',
          backgroundColor: Color(0xFF006699),
          textColor: Colors.white,
        ),
        ProfileCourseItem(
          id: 'c-2',
          title: 'Ingeniería de\nSoftware',
          subtitle: 'Proyecto',
          backgroundColor: Color(0xFFEDB002),
          textColor: Color(0xFF1B2A3D),
        ),
        ProfileCourseItem(
          id: 'c-3',
          title: 'Bases de\nDatos',
          subtitle: 'Avanzadas',
          backgroundColor: Color(0xFF1E8278),
          textColor: Colors.white,
        ),
      ],
      uploadedMaterials: const [
        ProfileMaterialItem(
          id: 'm-1',
          title: 'Guía API REST',
          category: 'Arquitectura',
        ),
        ProfileMaterialItem(
          id: 'm-2',
          title: 'Resumen\nmicroservicios',
          category: 'Software',
        ),
        ProfileMaterialItem(
          id: 'm-3',
          title: 'Checklist\nSwagger',
          category: 'Integración',
        ),
        ProfileMaterialItem(
          id: 'm-4',
          title: 'Apunte Prisma\nORM',
          category: 'Backend',
        ),
        ProfileMaterialItem(
          id: 'm-5',
          title: 'Ejercicios SQL',
          category: 'Bases de Datos',
        ),
        ProfileMaterialItem(
          id: 'm-6',
          title: 'Control resuelto',
          category: 'Evaluación',
        ),
      ],
      badges: const [
        ProfileBadge(
          id: 'b-1',
          title: 'Colaborador Destacado',
          description: 'Has subido 8 apuntes a la comunidad estudiantil.',
          icon: Icons.military_tech_rounded,
          isUnlocked: true,
          currentProgress: 8,
          maxProgress: 8,
          category: 'Aportes',
          unlockedDate: 'Agosto 2026',
        ),
        ProfileBadge(
          id: 'b-2',
          title: 'Top Calificado',
          description: 'Mantienes una calificación superior a 4.5 estrellas.',
          icon: Icons.star_rounded,
          isUnlocked: true,
          currentProgress: 5,
          maxProgress: 5,
          category: 'Calidad',
          unlockedDate: 'Septiembre 2026',
        ),
        ProfileBadge(
          id: 'b-3',
          title: 'Coleccionista',
          description: 'Has guardado más de 40 recursos útiles en tu biblioteca.',
          icon: Icons.bookmark_added_rounded,
          isUnlocked: true,
          currentProgress: 42,
          maxProgress: 40,
          category: 'Biblioteca',
          unlockedDate: 'Septiembre 2026',
        ),
        ProfileBadge(
          id: 'b-4',
          title: 'Pionero UCT',
          description: 'Miembro activo y verificado de la carrera en UCT.',
          icon: Icons.school_rounded,
          isUnlocked: true,
          currentProgress: 3,
          maxProgress: 3,
          category: 'Comunidad',
          unlockedDate: 'Julio 2026',
        ),
        ProfileBadge(
          id: 'b-5',
          title: 'Maestro de Apuntes',
          description: 'Sube 15 materiales de estudio verificados por ramo.',
          icon: Icons.workspace_premium_rounded,
          isUnlocked: false,
          currentProgress: 8,
          maxProgress: 15,
          category: 'Metas',
        ),
        ProfileBadge(
          id: 'b-6',
          title: 'Tutor Guía',
          description: 'Ayuda a responder y clarificar dudas de compañeros.',
          icon: Icons.forum_rounded,
          isUnlocked: false,
          currentProgress: 3,
          maxProgress: 10,
          category: 'Mentoría',
        ),
      ],
    );
  }

  UserProfileData copyWith({
    String? id,
    String? name,
    String? career,
    String? bio,
    int? uploadedCount,
    int? savedCount,
    double? reputation,
    List<ProfileCourseItem>? courses,
    List<ProfileMaterialItem>? uploadedMaterials,
    List<ProfileBadge>? badges,
  }) {
    return UserProfileData(
      id: id ?? this.id,
      name: name ?? this.name,
      career: career ?? this.career,
      bio: bio ?? this.bio,
      uploadedCount: uploadedCount ?? this.uploadedCount,
      savedCount: savedCount ?? this.savedCount,
      reputation: reputation ?? this.reputation,
      courses: courses ?? this.courses,
      uploadedMaterials: uploadedMaterials ?? this.uploadedMaterials,
      badges: badges ?? this.badges,
    );
  }
}
