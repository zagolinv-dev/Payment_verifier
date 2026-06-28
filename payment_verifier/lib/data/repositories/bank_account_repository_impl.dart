import 'package:payment_verifier/data/datasources/supabase_bank_account_datasource.dart';
import 'package:payment_verifier/domain/entities/bank_account_entity.dart';
import 'package:payment_verifier/domain/repositories/bank_account_repository.dart';

class BankAccountRepositoryImpl implements BankAccountRepository {
  BankAccountRepositoryImpl(this._datasource);
  final SupabaseBankAccountDatasource _datasource;

  @override
  Future<List<BankAccountEntity>> getBankAccounts() =>
      _datasource.getBankAccounts();

  @override
  Future<BankAccountEntity> createBankAccount({
    required String holderName,
    required String bankName,
    required String accountNumber,
    String? phone,
    String? notes,
  }) => _datasource.createBankAccount(
        holderName: holderName,
        bankName: bankName,
        accountNumber: accountNumber,
        phone: phone,
        notes: notes,
      );

  @override
  Future<BankAccountEntity> toggleActive(String id, bool isActive) =>
      _datasource.toggleActive(id, isActive);

  @override
  Future<BankAccountEntity> updateBankAccount({
    required String id,
    required String holderName,
    required String bankName,
    required String accountNumber,
    String? phone,
    String? notes,
  }) => _datasource.updateBankAccount(
        id: id,
        holderName: holderName,
        bankName: bankName,
        accountNumber: accountNumber,
        phone: phone,
        notes: notes,
      );

  @override
  Future<void> deleteBankAccount(String id) =>
      _datasource.deleteBankAccount(id);
}
