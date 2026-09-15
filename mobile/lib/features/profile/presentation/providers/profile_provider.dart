import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:apuntesuct_mobile/features/auth/data/mock_auth_repository.dart';
import '../../domain/profile_models.dart';

/// Enum para las pestañas de contenido en el perfil
enum ProfileSectionTab { materialSubido, cursos }

/// Notifier que expone los datos del perfil activo
class ProfileDataNotifier extends Notifier<UserProfileData> {
  @override
  UserProfileData build() {
    final authState = ref.watch(authStateProvider);
    final currentUserName = authState.asData?.value?.name;

    return UserProfileData.mock(customName: currentUserName);
  }

  void updateBio(String newBio) {
    state = state.copyWith(bio: newBio);
  }

  void updateProfile({String? name, String? career, String? bio}) {
    state = state.copyWith(
      name: name,
      career: career,
      bio: bio,
    );
  }
}

/// Provider reactivo de datos de perfil
final profileDataProvider =
    NotifierProvider<ProfileDataNotifier, UserProfileData>(
  ProfileDataNotifier.new,
);

/// Notifier que controla la pestaña seleccionada en el perfil
class ProfileTabNotifier extends Notifier<ProfileSectionTab> {
  @override
  ProfileSectionTab build() => ProfileSectionTab.materialSubido;

  void selectTab(ProfileSectionTab tab) {
    state = tab;
  }
}

/// Provider de pestaña seleccionada
final profileTabProvider =
    NotifierProvider<ProfileTabNotifier, ProfileSectionTab>(
  ProfileTabNotifier.new,
);
