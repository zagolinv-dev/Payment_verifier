import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:payment_verifier/data/datasources/supabase_bank_account_datasource.dart';
import 'package:payment_verifier/data/datasources/supabase_notification_datasource.dart';
import 'package:payment_verifier/data/repositories/bank_account_repository_impl.dart';
import 'package:payment_verifier/domain/entities/bank_account_entity.dart';
import 'package:payment_verifier/presentation/providers/auth_provider.dart';

final bankAccountDatasourceProvider =
    Provider<SupabaseBankAccountDatasource>((ref) {
  return SupabaseBankAccountDatasource(ref.watch(supabaseClientProvider));
});

final bankAccountRepositoryProvider =
    Provider<BankAccountRepositoryImpl>((ref) {
  return BankAccountRepositoryImpl(ref.watch(bankAccountDatasourceProvider));
});

// ── Single notifier that owns the list AND all CRUD operations ────────────────

class BankAccountNotifier
    extends StateNotifier<AsyncValue<List<BankAccountEntity>>> {
  BankAccountNotifier(this._repo) : super(const AsyncValue.loading()) {
    _load();
  }

  final BankAccountRepositoryImpl _repo;

  Future<void> _load() async {
    try {
      final accounts = await _repo.getBankAccounts();
      if (mounted) state = AsyncValue.data(accounts);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  /// Pull-to-refresh: reload from server.
  Future<void> reload() => _load();

  Future<bool> createAccount({
    required String holderName,
    required String bankName,
    required String accountNumber,
    String? phone,
    String? notes,
  }) async {
    try {
      final created = await _repo.createBankAccount(
        holderName: holderName,
        bankName: bankName,
        accountNumber: accountNumber,
        phone: phone,
        notes: notes,
      );
      final current = state.valueOrNull ?? [];
      if (mounted) state = AsyncValue.data([created, ...current]);
      return true;
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> toggleActive(String id, bool isActive) async {
    try {
      final updated = await _repo.toggleActive(id, isActive);
      _replaceById(updated);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateAccount({
    required String id,
    required String holderName,
    required String bankName,
    required String accountNumber,
    String? phone,
    String? notes,
  }) async {
    try {
      final updated = await _repo.updateBankAccount(
        id: id,
        holderName: holderName,
        bankName: bankName,
        accountNumber: accountNumber,
        phone: phone,
        notes: notes,
      );
      _replaceById(updated);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteAccount(String id) async {
    try {
      await _repo.deleteBankAccount(id);
      final current = state.valueOrNull ?? [];
      if (mounted) {
        state = AsyncValue.data(current.where((a) => a.id != id).toList());
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  void _replaceById(BankAccountEntity updated) {
    final current = state.valueOrNull ?? [];
    if (mounted) {
      state = AsyncValue.data(
        current.map((a) => a.id == updated.id ? updated : a).toList(),
      );
    }
  }
}

/// The one provider the whole app uses.
final bankAccountNotifierProvider = StateNotifierProvider<BankAccountNotifier,
    AsyncValue<List<BankAccountEntity>>>((ref) {
  return BankAccountNotifier(ref.watch(bankAccountRepositoryProvider));
});

/// Convenience alias so widgets can watch the list directly.
final bankAccountsProvider =
    Provider<AsyncValue<List<BankAccountEntity>>>((ref) {
  return ref.watch(bankAccountNotifierProvider);
});
