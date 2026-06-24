import 'package:payment_verifier/domain/entities/bank_account_entity.dart';

abstract class BankAccountRepository {
  Future<List<BankAccountEntity>> getBankAccounts();
  Future<BankAccountEntity> createBankAccount({
    required String holderName,
    required String bankName,
    required String accountNumber,
    String? phone,
    String? notes,
  });
  Future<BankAccountEntity> toggleActive(String id, bool isActive);
  Future<void> deleteBankAccount(String id);
}
