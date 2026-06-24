import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:payment_verifier/data/datasources/supabase_bank_account_datasource.dart';
import 'package:payment_verifier/data/repositories/bank_account_repository_impl.dart';
import 'package:payment_verifier/domain/entities/bank_account_entity.dart';
import 'package:payment_verifier/presentation/providers/auth_provider.dart';
import 'package:payment_verifier/core/utils/mock_data.dart';

// ── Datasource & Repository Providers ─────────────────────────────────────────

final bankAccountDatasourceProvider =
    Provider<SupabaseBankAccountDatasource>((ref) {
  return SupabaseBankAccountDatasource(ref.watch(supabaseClientProvider));
});

final bankAccountRepositoryProvider =
    Provider<BankAccountRepositoryImpl>((ref) {
  return BankAccountRepositoryImpl(ref.watch(bankAccountDatasourceProvider));
});

// ── Bank Accounts List ────────────────────────────────────────────────────────

final bankAccountsProvider =
    FutureProvider.autoDispose<List<BankAccountEntity>>((ref) async {
  return MockData.bankAccounts;
});

// ── Bank Account Operations Notifier ─────────────────────────────────────────

class BankAccountNotifier extends StateNotifier<AsyncValue<void>> {
  BankAccountNotifier(this._repo) : super(const AsyncValue.data(null));
  final BankAccountRepositoryImpl _repo;

  Future<bool> createAccount({
    required String holderName,
    required String bankName,
    required String accountNumber,
    String? phone,
    String? notes,
  }) async {
    state = const AsyncValue.loading();
    try {
      await Future.delayed(const Duration(milliseconds: 600));
      final account = BankAccountEntity(
        id: 'acc-${DateTime.now().millisecondsSinceEpoch}',
        holderName: holderName,
        bankName: bankName,
        accountNumber: accountNumber,
        phone: phone,
        notes: notes,
        isActive: true,
        createdAt: DateTime.now(),
      );
      MockData.bankAccounts.add(account);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> toggleActive(String id, bool isActive) async {
    try {
      final index = MockData.bankAccounts.indexWhere((a) => a.id == id);
      if (index != -1) {
        final acc = MockData.bankAccounts[index];
        MockData.bankAccounts[index] = BankAccountEntity(
          id: acc.id,
          holderName: acc.holderName,
          bankName: acc.bankName,
          accountNumber: acc.accountNumber,
          phone: acc.phone,
          notes: acc.notes,
          isActive: isActive,
          createdAt: acc.createdAt,
        );
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteAccount(String id) async {
    try {
      MockData.bankAccounts.removeWhere((a) => a.id == id);
      return true;
    } catch (_) {
      return false;
    }
  }
}

final bankAccountNotifierProvider =
    StateNotifierProvider.autoDispose<BankAccountNotifier, AsyncValue<void>>(
        (ref) {
  return BankAccountNotifier(ref.watch(bankAccountRepositoryProvider));
});
