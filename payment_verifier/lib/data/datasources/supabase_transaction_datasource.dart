import 'package:payment_verifier/core/constants/app_constants.dart';
import 'package:payment_verifier/data/models/transaction_model.dart';
import 'package:payment_verifier/domain/entities/transaction_entity.dart';
import 'package:payment_verifier/domain/repositories/transaction_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseTransactionDatasource {
  SupabaseTransactionDatasource(this._client);
  final SupabaseClient _client;

  Future<List<TransactionModel>> getTransactions({
    String? statusFilter,
    String? bankFilter,
    String? searchQuery,
  }) async {
    var query = _client
        .from(AppConstants.transactionsTable)
        .select()
        .order('created_at', ascending: false);

    final response = await query;
    var transactions = (response as List)
        .map((e) => TransactionModel.fromJson(e as Map<String, dynamic>))
        .toList();

    // Client-side filtering
    if (statusFilter != null && statusFilter != 'All Status') {
      transactions = transactions
          .where((t) => t.status.value == statusFilter)
          .toList();
    }
    if (bankFilter != null && bankFilter != 'All Banks') {
      transactions =
          transactions.where((t) => t.bankName == bankFilter).toList();
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      transactions = transactions
          .where((t) =>
              t.referenceCode.toLowerCase().contains(q) ||
              t.buyerName.toLowerCase().contains(q) ||
              t.bankName.toLowerCase().contains(q))
          .toList();
    }

    return transactions;
  }

  Future<List<TransactionModel>> getRecentTransactions({int limit = 5}) async {
    final response = await _client
        .from(AppConstants.transactionsTable)
        .select()
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List)
        .map((e) => TransactionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<TransactionModel> createTransaction({
    required String bankName,
    required String referenceCode,
    required String buyerName,
    required double amount,
    double tip = 0.0,
  }) async {
    final userId = _client.auth.currentUser?.id;
    final data = {
      'bank_name': bankName,
      'reference_code': referenceCode,
      'buyer_name': buyerName,
      'amount': amount,
      'tip': tip,
      'status': 'VERIFIED',
      'verified_by': userId,
    };

    final response = await _client
        .from(AppConstants.transactionsTable)
        .insert(data)
        .select()
        .single();

    return TransactionModel.fromJson(response as Map<String, dynamic>);
  }

  Future<DashboardMetrics> getDashboardMetrics() async {
    final all = await getTransactions();
    final today = DateTime.now();
    final todayTx = all.where((t) {
      final d = t.createdAt;
      return d.year == today.year && d.month == today.month && d.day == today.day;
    }).toList();

    return DashboardMetrics(
      totalIncome: all.fold(0.0, (sum, t) => sum + t.amount),
      totalTips: all.fold(0.0, (sum, t) => sum + t.tip),
      verifiedToday: todayTx.where((t) => t.status == TransactionStatus.verified).length,
      failedToday: todayTx.where((t) => t.status == TransactionStatus.failed).length,
      todayTotal: todayTx.fold(0.0, (sum, t) => sum + t.total),
      todayCount: todayTx.length,
    );
  }
}
