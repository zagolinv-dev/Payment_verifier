import 'package:payment_verifier/domain/entities/user_profile_entity.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class AuthRepository {
  Stream<AuthState> get authStateChanges;
  Future<UserProfileEntity?> getCurrentUser();
  Future<UserProfileEntity> signIn({required String email, required String password});
  Future<UserProfileEntity> signUp({required String email, required String password, String? fullName, String? role, String? phone, String? ownerName, String? address, String? description});
  Future<void> signOut();
  Future<void> resetPassword(String email);
}
