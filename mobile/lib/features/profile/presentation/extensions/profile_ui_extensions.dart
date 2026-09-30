import 'package:flutter/material.dart';

import '../../domain/profile_models.dart';

/// Extensiones de presentación para mapear propiedades de dominio a componentes visuales de Flutter.
extension ProfileCourseItemUI on ProfileCourseItem {
  Color get backgroundColor => Color(colorValue);
  Color get textColor => Color(textColorValue);
}

extension ProfileBadgeUI on ProfileBadge {
  IconData get icon {
    switch (iconKey) {
      case 'military_tech':
        return Icons.military_tech_rounded;
      case 'star':
        return Icons.star_rounded;
      case 'bookmark_added':
        return Icons.bookmark_added_rounded;
      case 'school':
        return Icons.school_rounded;
      case 'workspace_premium':
        return Icons.workspace_premium_rounded;
      case 'forum':
        return Icons.forum_rounded;
      default:
        return Icons.emoji_events_rounded;
    }
  }
}
