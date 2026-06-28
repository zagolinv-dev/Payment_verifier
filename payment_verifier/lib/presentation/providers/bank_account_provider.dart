import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:payment_verifier/data/datasources/supabase_bank_account_datasource.dart';
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

final bankAccountsProvider =
    FutureProvider.autoDispose<List<BankAccountEntity>>((ref) async {
  final repo = ref.watch(bankAccountRepositoryProvider);
  return repo.getBankAccounts();
});

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
      await _repo.createBankAccount(
        holderName: holderName,
        bankName: bankName,
        accountNumber: accountNumber,
        phone: phone,
        notes: notes,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> toggleActive(String id, bool isActive) async {
    try {
      await _repo.toggleActive(id, isActive);
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
    state = const AsyncValue.loading();
    try {
      await _repo.updateBankAccount(
        id: id,
        holderName: holderName,
        bankName: bankName,
        accountNumber: accountNumber,
        phone: phone,
        notes: notes,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> deleteAccount(String id) async {
    try {
      await _repo.deleteBankAccount(id);
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
