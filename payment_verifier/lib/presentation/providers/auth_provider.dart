import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:payment_verifier/data/datasources/supabase_auth_datasource.dart';
import 'package:payment_verifier/data/repositories/auth_repository_impl.dart';
import 'package:payment_verifier/domain/entities/user_profile_entity.dart';
import 'package:payment_verifier/core/constants/app_constants.dart';
import 'package:payment_verifier/core/utils/mock_data.dart';

// ── Supabase Client Provider ──────────────────────────────────────────────────

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// ── Auth Datasource & Repository ──────────────────────────────────────────────

final authDatasourceProvider = Provider<SupabaseAuthDatasource>((ref) {
  return SupabaseAuthDatasource(ref.watch(supabaseClientProvider));
});

final authRepositoryProvider = Provider<AuthRepositoryImpl>((ref) {
  return AuthRepositoryImpl(ref.watch(authDatasourceProvider));
});

// ── Auth State ────────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AsyncValue<UserProfileEntity?>> {
  AuthNotifier(this._repo) : super(const AsyncValue.data(null)) {
    _init();
  }

  final AuthRepositoryImpl _repo;
  static UserProfileEntity? _currentUser;

  Future<void> _init() async {
    state = AsyncValue.data(_currentUser);
  }

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncValue.loading();
    await Future.delayed(const Duration(milliseconds: 600));
    _currentUser = UserProfileEntity(
      id: 'mock-admin-id',
      email: email.isNotEmpty ? email : 'simonnjege@gmail.com',
      fullName: 'Simon Njege',
      role: UserRole.admin,
      createdAt: DateTime.now(),
    );
    state = AsyncValue.data(_currentUser);
  }

  Future<void> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    state = const AsyncValue.loading();
    await Future.delayed(const Duration(milliseconds: 600));
    _currentUser = UserProfileEntity(
      id: 'mock-admin-id',
      email: email.isNotEmpty ? email : 'simonnjege@gmail.com',
      fullName: fullName?.isNotEmpty == true ? fullName : 'Simon Njege',
      role: UserRole.admin,
      createdAt: DateTime.now(),
    );
    state = AsyncValue.data(_currentUser);
  }

  Future<void> signOut() async {
    _currentUser = null;
    state = const AsyncValue.data(null);
  }

  void refresh() => _init();
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<UserProfileEntity?>>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});

/// Quick accessor — current user or null
final currentUserProvider = Provider<UserProfileEntity?>((ref) {
  return ref.watch(authProvider).valueOrNull;
});

/// Is admin?
final isAdminProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider)?.isAdmin ?? false;
});
