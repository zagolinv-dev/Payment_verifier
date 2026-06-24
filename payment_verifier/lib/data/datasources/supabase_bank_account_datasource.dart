import 'package:payment_verifier/core/constants/app_constants.dart';
import 'package:payment_verifier/data/models/bank_account_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseBankAccountDatasource {
  SupabaseBankAccountDatasource(this._client);
  final SupabaseClient _client;

  Future<List<BankAccountModel>> getBankAccounts() async {
    final response = await _client
        .from(AppConstants.bankAccountsTable)
        .select()
        .order('created_at', ascending: false);

    return (response as List)
        .map((e) => BankAccountModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<BankAccountModel> createBankAccount({
    required String holderName,
    required String bankName,
    required String accountNumber,
    String? phone,
    String? notes,
  }) async {
    final data = {
      'holder_name': holderName,
      'bank_name': bankName,
      'account_number': accountNumber,
      'phone': phone,
      'notes': notes,
      'is_active': true,
    };

    final response = await _client
        .from(AppConstants.bankAccountsTable)
        .insert(data)
        .select()
        .single();

    return BankAccountModel.fromJson(response as Map<String, dynamic>);
  }

  Future<BankAccountModel> toggleActive(String id, bool isActive) async {
    final response = await _client
        .from(AppConstants.bankAccountsTable)
        .update({'is_active': isActive})
        .eq('id', id)
        .select()
        .single();

    return BankAccountModel.fromJson(response as Map<String, dynamic>);
  }

  Future<void> deleteBankAccount(String id) async {
    await _client.from(AppConstants.bankAccountsTable).delete().eq('id', id);
  }
}
