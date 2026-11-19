import 'package:apuntesuct_mobile/features/auth/data/mock_auth_repository.dart';
import 'package:apuntesuct_mobile/models/user_model.dart';

class MaterialAuthorFixture extends AuthStateNotifier {
  @override
  Future<UserModel?> build() async => UserModel.mock(id: 'author-1');
}
