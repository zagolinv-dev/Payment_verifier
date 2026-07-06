import 'package:payment_verifier/data/datasources/supabase_auth_datasource.dart';
import 'package:payment_verifier/domain/entities/user_profile_entity.dart';
import 'package:payment_verifier/domain/repositories/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._datasource);
  final SupabaseAuthDatasource _datasource;

  @override
  Stream<AuthState> get authStateChanges => _datasource.authStateChanges;

  @override
  Future<UserProfileEntity?> getCurrentUser() => _datasource.getCurrentUser();

  @override
  Future<UserProfileEntity> signIn({
    required String email,
    required String password,
  }) => _datasource.signIn(email: email, password: password);

  @override
  Future<UserProfileEntity> signUp({
    required String email,
    required String password,
    String? fullName,
    String? role,
    String? ownerId,
    String? phone,
    String? ownerName,
    String? address,
    String? description,
  }) => _datasource.signUp(
        email: email,
        password: password,
        fullName: fullName,
        role: role,
        ownerId: ownerId,
        phone: phone,
        ownerName: ownerName,
        address: address,
        description: description,
      );

  @override
  Future<void> resetPassword(String email) => _datasource.resetPassword(email);

  @override
  Future<void> signOut() => _datasource.signOut();
}
