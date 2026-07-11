import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:payment_verifier/core/constants/app_constants.dart';
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
      final scopeOwnerId = await _scopeOwnerId;
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
      final ownerId = Supabase.instance.client.auth.currentUser?.id;
      if (ownerId == null) return 'Not authenticated';

      await Supabase.instance.client.functions.invoke(
        'create-waiter',
        body: {
          'fullName': fullName,
          'email': email,
          'password': password,
          'ownerId': ownerId,
        },
      );

      return null;
    } on FunctionException catch (e) {
      debugPrint('[addWaiter Error] $e');
      return e.details?.toString() ?? 'Failed to create waiter';
    } catch (e) {
      debugPrint('[addWaiter Error] $e');
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<bool> deleteUser(String userId) async {
    try {
      await _ds.deleteUser(userId, ownerId: await _scopeOwnerId);
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

  Future<String?> get _scopeOwnerId async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;
    try {
      final response = await Supabase.instance.client
          .from(AppConstants.profilesTable)
          .select('owner_id')
          .eq('id', user.id)
          .single();
      return response['owner_id'] as String? ?? user.id;
    } catch (_) {
      return user.id;
    }
  }
}

final userManagementProvider =
    StateNotifierProvider.autoDispose<UserManagementNotifier, AsyncValue<void>>(
        (ref) {
  return UserManagementNotifier(ref.watch(userDatasourceProvider));
});
