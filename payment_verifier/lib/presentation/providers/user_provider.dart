import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:payment_verifier/data/datasources/supabase_auth_datasource.dart';
import 'package:payment_verifier/data/datasources/supabase_user_datasource.dart';
import 'package:payment_verifier/domain/entities/user_profile_entity.dart';
import 'package:payment_verifier/presentation/providers/auth_provider.dart';
import 'package:payment_verifier/core/constants/app_constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final userDatasourceProvider = Provider<SupabaseUserDatasource>((ref) {
  return SupabaseUserDatasource(ref.watch(supabaseClientProvider));
});

final usersListProvider =
    FutureProvider.autoDispose<List<UserProfileEntity>>((ref) async {
  final ds = ref.watch(userDatasourceProvider);
  return ds.getAllUsers();
});

class UserManagementNotifier extends StateNotifier<AsyncValue<void>> {
  UserManagementNotifier(this._ds) : super(const AsyncValue.data(null));
  final SupabaseUserDatasource _ds;

  Future<bool> updateRole(String userId, String roleStr) async {
    try {
      await _ds.updateUserRole(userId, roleStr);
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
      final authDs = SupabaseAuthDatasource(Supabase.instance.client);
      await authDs.signUp(email: email, password: password, fullName: fullName, role: 'WAITRESS');
      return null;
    } catch (e) {
      debugPrint('[addWaiter Error] $e');
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<bool> deleteUser(String userId) async {
    try {
      await _ds.deleteUser(userId);
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
}

final userManagementProvider =
    StateNotifierProvider.autoDispose<UserManagementNotifier, AsyncValue<void>>(
        (ref) {
  return UserManagementNotifier(ref.watch(userDatasourceProvider));
});
