import 'package:payment_verifier/core/constants/app_constants.dart';
import 'package:payment_verifier/data/models/user_profile_model.dart';
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
    String? role = 'ADMIN',
    String? ownerId,
    String? phone,
    String? ownerName,
    String? address,
    String? description,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'role': role,
          'owner_id': ownerId,
        'phone': phone,
        'owner_name': ownerName,
        'address': address,
        'description': description,
      },
    );
    final user = response.user!;

    if (response.session != null) {
      try {
        return await _fetchProfile(user.id, user.email ?? '');
      } catch (_) {
        await _client.from(AppConstants.profilesTable).upsert({
          'id': user.id,
          'email': user.email,
          'full_name': fullName,
          'role': 'ADMIN',
          'status': 'PENDING',
          'owner_id': user.id,
          'phone': phone,
          'owner_name': ownerName,
          'address': address,
          'description': description,
        });
        return _fetchProfile(user.id, user.email ?? '');
      }
    }

    return UserProfileModel(
      id: user.id,
      email: user.email ?? email,
      fullName: fullName,
      role: UserRole.admin,
      createdAt: DateTime.now(),
    );
  }

  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
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
      final data = response;
      data['email'] = email;
      return UserProfileModel.fromJson(data);
    } catch (_) {
      return UserProfileModel(
        id: userId,
        email: email,
        ownerId: null,
        role: UserRole.waitress,
        createdAt: DateTime.now(),
      );
    }
  }
}
