import 'package:payment_verifier/core/constants/app_constants.dart';
import 'package:payment_verifier/data/models/bank_account_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseBankAccountDatasource {
  SupabaseBankAccountDatasource(this._client);
  final SupabaseClient _client;

  Future<String?> _resolveScopeOwnerId() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    try {
      final response = await _client
          .from(AppConstants.profilesTable)
          .select('id, owner_id')
          .eq('id', user.id)
          .single();
      final data = response;
      return data['owner_id'] as String? ?? user.id;
    } catch (_) {
      return user.id;
    }
  }

  Future<List<BankAccountModel>> getBankAccounts({String? ownerId}) async {
    final scopeOwnerId = ownerId ?? await _resolveScopeOwnerId();
    try {
      var query = _client.from(AppConstants.bankAccountsTable).select();
      if (scopeOwnerId != null) {
        query = query.eq('owner_id', scopeOwnerId);
      }
      final response = await query.order('created_at', ascending: false);

      return (response as List)
          .map((e) => BankAccountModel.fromJson(e))
          .toList();
    } catch (_) {
      var fallbackQuery = _client
          .from(AppConstants.bankAccountsTable)
          .select();
      if (scopeOwnerId != null) {
        fallbackQuery = fallbackQuery.eq('owner_id', scopeOwnerId);
      }
      final response = await fallbackQuery.order('created_at', ascending: false);
      return (response as List)
          .map((e) => BankAccountModel.fromJson(e))
          .toList();
    }
  }

  Future<BankAccountModel> createBankAccount({
    required String holderName,
    required String bankName,
    required String accountNumber,
    String? phone,
    String? notes,
  }) async {
    final ownerId = await _resolveScopeOwnerId();
    final data = {
      'holder_name': holderName,
      'bank_name': bankName,
      'account_number': accountNumber,
      'phone': phone,
      'notes': notes,
      'owner_id': ownerId,
      'is_active': true,
    };

    final response = await _client
        .from(AppConstants.bankAccountsTable)
        .insert(data)
        .select()
        .single();

    return BankAccountModel.fromJson(response);
  }

  Future<BankAccountModel> toggleActive(String id, bool isActive) async {
    final ownerId = await _resolveScopeOwnerId();
    var query = _client
        .from(AppConstants.bankAccountsTable)
        .update({'is_active': isActive})
        .eq('id', id);
    if (ownerId != null) {
      query = query.eq('owner_id', ownerId);
    }
    final response = await query.select().single();

    return BankAccountModel.fromJson(response);
  }

  Future<BankAccountModel> updateBankAccount({
    required String id,
    required String holderName,
    required String bankName,
    required String accountNumber,
    String? phone,
    String? notes,
  }) async {
    final ownerId = await _resolveScopeOwnerId();
    final data = {
      'holder_name': holderName,
      'bank_name': bankName,
      'account_number': accountNumber,
      'phone': phone,
      'notes': notes,
    };
    var query = _client
        .from(AppConstants.bankAccountsTable)
        .update(data)
        .eq('id', id);
    if (ownerId != null) {
      query = query.eq('owner_id', ownerId);
    }
    final response = await query.select().single();
    return BankAccountModel.fromJson(response);
  }

  Future<void> deleteBankAccount(String id) async {
    final ownerId = await _resolveScopeOwnerId();
    var query = _client.from(AppConstants.bankAccountsTable).delete().eq('id', id);
    if (ownerId != null) {
      query = query.eq('owner_id', ownerId);
    }
    await query;
  }
}
