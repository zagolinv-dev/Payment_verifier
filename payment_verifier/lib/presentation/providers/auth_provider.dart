import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:payment_verifier/data/datasources/supabase_auth_datasource.dart';
import 'package:payment_verifier/data/repositories/auth_repository_impl.dart';
import 'package:payment_verifier/domain/entities/user_profile_entity.dart';


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

  Future<void> _init() async {
    state = const AsyncValue.loading();
    try {
      final user = await _repo.getCurrentUser();
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.data(null);
    }
  }

  Future<void> signIn({required String email, required String password, String role = 'Manager'}) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repo.signIn(email: email, password: password);
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repo.signUp(email: email, password: password, fullName: fullName);
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signOut() async {
    try {
      await _repo.signOut();
    } catch (_) {}
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
