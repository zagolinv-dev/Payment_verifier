import 'package:payment_verifier/core/constants/app_constants.dart';
import 'package:payment_verifier/data/models/user_profile_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseUserDatasource {
  SupabaseUserDatasource(this._client);
  final SupabaseClient _client;

  Future<List<UserProfileModel>> getAllUsers() async {
    final response = await _client
        .from(AppConstants.profilesTable)
        .select()
        .order('created_at', ascending: false);

    return (response as List)
        .map((e) => UserProfileModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<UserProfileModel> updateUserRole(String userId, String role) async {
    final response = await _client
        .from(AppConstants.profilesTable)
        .update({'role': role})
        .eq('id', userId)
        .select()
        .single();

    return UserProfileModel.fromJson(response as Map<String, dynamic>);
  }

  Future<void> deleteUser(String userId) async {
    await _client.from(AppConstants.profilesTable).delete().eq('id', userId);
  }
}
