import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:payment_verifier/data/datasources/supabase_user_datasource.dart';
import 'package:payment_verifier/domain/entities/user_profile_entity.dart';
import 'package:payment_verifier/presentation/providers/auth_provider.dart';
import 'package:payment_verifier/core/utils/mock_data.dart';
import 'package:payment_verifier/core/constants/app_constants.dart';

// ── Datasource Provider ───────────────────────────────────────────────────────

final userDatasourceProvider = Provider<SupabaseUserDatasource>((ref) {
  return SupabaseUserDatasource(ref.watch(supabaseClientProvider));
});

// ── Users List ────────────────────────────────────────────────────────────────

final usersListProvider =
    FutureProvider.autoDispose<List<UserProfileEntity>>((ref) async {
  return MockData.users;
});

// ── User Operations Notifier ──────────────────────────────────────────────────

class UserManagementNotifier extends StateNotifier<AsyncValue<void>> {
  UserManagementNotifier(this._ds) : super(const AsyncValue.data(null));
  final SupabaseUserDatasource _ds;

  Future<bool> updateRole(String userId, String roleStr) async {
    try {
      final index = MockData.users.indexWhere((u) => u.id == userId);
      if (index != -1) {
        final u = MockData.users[index];
        final role = roleStr == 'ADMIN' ? UserRole.admin : UserRole.waitress;
        MockData.users[index] = UserProfileEntity(
          id: u.id,
          email: u.email,
          fullName: u.fullName,
          avatarUrl: u.avatarUrl,
          role: role,
          createdAt: u.createdAt,
        );
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}

final userManagementProvider =
    StateNotifierProvider.autoDispose<UserManagementNotifier, AsyncValue<void>>(
        (ref) {
  return UserManagementNotifier(ref.watch(userDatasourceProvider));
});
