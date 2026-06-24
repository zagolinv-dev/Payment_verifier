import 'package:payment_verifier/domain/entities/user_profile_entity.dart';

abstract class UserRepository {
  Future<List<UserProfileEntity>> getAllUsers();
  Future<UserProfileEntity> inviteUser({required String email, required String role});
  Future<UserProfileEntity> updateUserRole(String userId, String role);
  Future<void> deactivateUser(String userId);
}
