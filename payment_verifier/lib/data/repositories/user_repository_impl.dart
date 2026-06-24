import 'package:payment_verifier/data/datasources/supabase_user_datasource.dart';
import 'package:payment_verifier/domain/entities/user_profile_entity.dart';
import 'package:payment_verifier/domain/repositories/user_repository.dart';

class UserRepositoryImpl implements UserRepository {
  UserRepositoryImpl(this._datasource);
  final SupabaseUserDatasource _datasource;

  @override
  Future<List<UserProfileEntity>> getAllUsers() => _datasource.getAllUsers();

  @override
  Future<UserProfileEntity> inviteUser({
    required String email,
    required String role,
  }) {
    // Invitation requires Supabase Admin API — stubbed
    throw UnimplementedError('Invite requires Supabase Admin API');
  }

  @override
  Future<UserProfileEntity> updateUserRole(String userId, String role) =>
      _datasource.updateUserRole(userId, role);

  @override
  Future<void> deactivateUser(String userId) async {
    // Deactivation requires Supabase Admin API — stub
    throw UnimplementedError('Deactivate requires Supabase Admin API');
  }
}
