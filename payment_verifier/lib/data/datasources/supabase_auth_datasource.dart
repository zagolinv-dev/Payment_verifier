import 'package:payment_verifier/core/constants/app_constants.dart';
import 'package:payment_verifier/data/models/user_profile_model.dart';
import 'package:payment_verifier/domain/entities/user_profile_entity.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthDatasource {
  SupabaseAuthDatasource(this._client);
  final SupabaseClient _client;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<UserProfileModel?> getCurrentUser() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    return _fetchProfile(user.id, user.email ?? '');
  }

  Future<UserProfileModel> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final user = response.user!;
    return _fetchProfile(user.id, user.email ?? '');
  }

  Future<UserProfileModel> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );
    final user = response.user!;
    // Profile is created by Supabase trigger; fetch or create it
    try {
      return await _fetchProfile(user.id, user.email ?? '');
    } catch (_) {
      await _client.from(AppConstants.profilesTable).upsert({
        'id': user.id,
        'email': user.email,
        'full_name': fullName,
        'role': 'WAITRESS',
      });
      return _fetchProfile(user.id, user.email ?? '');
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<UserProfileModel> _fetchProfile(String userId, String email) async {
    try {
      final response = await _client
          .from(AppConstants.profilesTable)
          .select()
          .eq('id', userId)
          .single();
      final data = response as Map<String, dynamic>;
      data['email'] = email;
      return UserProfileModel.fromJson(data);
    } catch (_) {
      return UserProfileModel(
        id: userId,
        email: email,
        role: UserRole.waitress,
        createdAt: DateTime.now(),
      );
    }
  }
}
