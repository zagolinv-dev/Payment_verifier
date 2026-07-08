import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:payment_verifier/core/constants/supabase_constants.dart';
import 'package:payment_verifier/data/datasources/supabase_user_datasource.dart';
import 'package:payment_verifier/domain/entities/user_profile_entity.dart';
import 'package:payment_verifier/presentation/providers/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final userDatasourceProvider = Provider<SupabaseUserDatasource>((ref) {
  return SupabaseUserDatasource(ref.watch(supabaseClientProvider));
});

final usersListProvider =
    FutureProvider.autoDispose<List<UserProfileEntity>>((ref) async {
  final ds = ref.watch(userDatasourceProvider);
  final user = ref.watch(currentUserProvider);
  final scopeOwnerId = user == null ? null : (user.ownerId ?? user.id);
  return ds.getAllUsers(ownerId: scopeOwnerId);
});

class UserManagementNotifier extends StateNotifier<AsyncValue<void>> {
  UserManagementNotifier(this._ds) : super(const AsyncValue.data(null));
  final SupabaseUserDatasource _ds;

  Future<bool> updateRole(String userId, String roleStr) async {
    try {
      final scopeOwnerId = _scopeOwnerId;
      await _ds.updateUserRole(userId, roleStr, ownerId: scopeOwnerId);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String?> addWaiter({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      final client = Supabase.instance.client;
      final managerId = client.auth.currentUser?.id;
      if (managerId == null) return 'Not authenticated';

      final serviceKey = SupabaseConstants.supabaseServiceRoleKey;
      if (serviceKey.isEmpty || serviceKey == 'your-service-role-key-here') {
        return 'Service role key not set — add SUPABASE_SERVICE_ROLE_KEY to .env';
      }

      // Use service role key to call Supabase admin REST API directly.
      // This bypasses email rate limits and never touches the manager's session.
      final url = Uri.parse(
          '${SupabaseConstants.supabaseUrl}/auth/v1/admin/users');
      final res = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'apikey': serviceKey,
          'Authorization': 'Bearer $serviceKey',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
          'email_confirm': true,
          'user_metadata': {
            'full_name': fullName,
            'role': 'WAITRESS',
            'owner_id': managerId,
          },
        }),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode != 200 && res.statusCode != 201) {
        final b = jsonDecode(res.body) as Map;
        return b['msg']?.toString()
            ?? b['message']?.toString()
            ?? b['error_description']?.toString()
            ?? 'Create user failed (${res.statusCode})';
      }

      final body = jsonDecode(res.body) as Map;
      final newUserId = body['id']?.toString();
      if (newUserId == null) return 'Could not retrieve new user ID';

      // Insert / update profile row with owner_id via SECURITY DEFINER RPC.
      // The DB trigger (handle_new_user) may have already created the row,
      // but the RPC ensures owner_id is set correctly.
      await client.rpc('create_waiter_profile', params: {
        'waiter_id': newUserId,
        'waiter_email': email,
        'waiter_name': fullName,
        'manager_id': managerId,
      });

      return null; // success
    } catch (e) {
      debugPrint('[addWaiter Error] $e');
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<bool> deleteUser(String userId) async {
    try {
      await _ds.deleteUser(userId, ownerId: _scopeOwnerId);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> resetPassword(String userId, String newPassword) async {
    try {
      await Supabase.instance.client.auth.admin.updateUserById(
        userId,
        attributes: AdminUserAttributes(password: newPassword),
      );
      return true;
    } catch (_) {
      await Future.delayed(const Duration(milliseconds: 300));
      return false;
    }
  }

  String? get _scopeOwnerId {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;
    return user.id;
  }
}

final userManagementProvider =
    StateNotifierProvider.autoDispose<UserManagementNotifier, AsyncValue<void>>(
        (ref) {
  return UserManagementNotifier(ref.watch(userDatasourceProvider));
});
