import 'package:payment_verifier/core/constants/app_constants.dart';
import 'package:payment_verifier/data/models/user_profile_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseUserDatasource {
  SupabaseUserDatasource(this._client);
  final SupabaseClient _client;

  Future<List<UserProfileModel>> getAllUsers({String? ownerId}) async {
    final scopeOwnerId = ownerId ?? await _resolveScopeOwnerId();
    try {
      final query = _client.from(AppConstants.profilesTable).select();
      final response = scopeOwnerId == null
        ? await query.order('created_at', ascending: false)
        : await query
          .or('id.eq.$scopeOwnerId,owner_id.eq.$scopeOwnerId')
          .order('created_at', ascending: false);

      return (response as List)
        .map((e) => UserProfileModel.fromJson(e))
        .toList();
    } catch (_) {
      final response = await _client
        .from(AppConstants.profilesTable)
        .select()
        .order('created_at', ascending: false);
      return (response as List)
        .map((e) => UserProfileModel.fromJson(e))
        .toList();
    }
  }

  Future<UserProfileModel> updateUserRole(String userId, String role, {String? ownerId}) async {
    final scopeOwnerId = ownerId ?? await _resolveScopeOwnerId();
    final response = await _client
        .from(AppConstants.profilesTable)
        .update({'role': role})
        .eq('owner_id', scopeOwnerId ?? userId)
        .eq('id', userId)
        .select()
        .single();

    return UserProfileModel.fromJson(response);
  }

  Future<void> deleteUser(String userId, {String? ownerId}) async {
    final scopeOwnerId = ownerId ?? await _resolveScopeOwnerId();
    final query = _client.from(AppConstants.profilesTable).delete().eq('id', userId);
    if (scopeOwnerId != null) {
      await query.eq('owner_id', scopeOwnerId);
      return;
    }
    await query;
  }

  Future<String?> _resolveScopeOwnerId() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    try {
      final response = await _client
          .from(AppConstants.profilesTable)
          .select('id, owner_id')
          .eq('id', user.id)
          .single();
      final data = response;
      return data['owner_id'] as String? ?? user.id;
    } catch (_) {
      return user.id;
    }
  }
}
