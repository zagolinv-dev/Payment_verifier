import 'dart:io';
import 'package:flutter/foundation.dart';
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

    if (statusFilter != null && statusFilter != 'All Status') {
      transactions = transactions
          .where((t) => t.status.value == statusFilter)
          .toList();
    }
    if (bankFilter != null && bankFilter != 'All Banks') {
      final filter = bankFilter.trim().toLowerCase();
      final matchingBank = BankName.values.firstWhere(
        (b) => b.displayName.toLowerCase() == filter || b.shortName.toLowerCase() == filter,
        orElse: () => BankName.values.first,
      );
      transactions = transactions
          .where((t) {
            final name = t.bankName.trim().toLowerCase();
            return name == matchingBank.displayName.toLowerCase() ||
                name == matchingBank.shortName.toLowerCase();
          })
          .toList();
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

  Future<List<TransactionModel>> getRecentTransactions({int limit = 5, String? userId}) async {
    // Filters (eq) must come before transform operations (order, limit)
    final base = _client
        .from(AppConstants.transactionsTable)
        .select();
    final filtered = userId != null ? base.eq('verified_by', userId) : base;
    final response = await filtered
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
    String? imageUrl,
    double riskScore = 0.0,
    List<String> riskFlags = const [],
    double orderTotal = 0.0,
    String status = 'VERIFIED',
  }) async {
    final userId = _client.auth.currentUser?.id;
    final data = {
      'bank_name': bankName,
      'reference_code': referenceCode,
      'buyer_name': buyerName,
      'amount': amount,
      'tip': tip,
      'status': status,
      'verified_by': userId,
      'receipt_image': imageUrl,
      'risk_score': riskScore,
      'risk_flags': riskFlags,
      'order_total': orderTotal,
    };

    final response = await _client
        .from(AppConstants.transactionsTable)
        .insert(data)
        .select()
        .single();

    return TransactionModel.fromJson(response as Map<String, dynamic>);
  }

  Future<void> updateTransactionStatus(String id, String status) async {
    await _client
        .from(AppConstants.transactionsTable)
        .update({'status': status})
        .eq('id', id);
  }

  Future<DashboardMetrics> getDashboardMetrics({String? userId}) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    var todayQuery = _client
        .from(AppConstants.transactionsTable)
        .select('amount, tip, status')
        .gte('created_at', todayStart.toIso8601String())
        .lt('created_at', todayEnd.toIso8601String());
    if (userId != null) todayQuery = todayQuery.eq('verified_by', userId);
    final todayResponse = await todayQuery;
    final todayTxs = (todayResponse as List).cast<Map<String, dynamic>>();

    var allQuery = _client
        .from(AppConstants.transactionsTable)
        .select('amount, tip, status');
    if (userId != null) allQuery = allQuery.eq('verified_by', userId);
    final allResponse = await allQuery;
    final allTxs = (allResponse as List).cast<Map<String, dynamic>>();

    double totalIncome = 0, totalTips = 0;
    int totalVerified = 0, totalFailed = 0;
    for (final t in allTxs) {
      totalIncome += (t['amount'] as num).toDouble();
      totalTips += (t['tip'] as num).toDouble();
      final status = t['status'] as String;
      if (status == 'VERIFIED') totalVerified++;
      if (status == 'FAILED' || status == 'FRAUD_SUSPECTED') totalFailed++;
    }

    int verifiedToday = 0, failedToday = 0;
    double todayTotal = 0;
    for (final t in todayTxs) {
      final status = t['status'] as String;
      final amt = (t['amount'] as num).toDouble();
      final tip = (t['tip'] as num).toDouble();
      if (status == 'VERIFIED') verifiedToday++;
      if (status == 'FAILED' || status == 'FRAUD_SUSPECTED') failedToday++;
      todayTotal += amt + tip;
    }

    return DashboardMetrics(
      totalIncome: totalIncome,
      totalTips: totalTips,
      verifiedToday: verifiedToday,
      failedToday: failedToday,
      todayTotal: todayTotal,
      todayCount: todayTxs.length,
      totalVerified: totalVerified,
      totalFailed: totalFailed,
    );
  }

  Future<Map<String, double>> getWeeklyTotals() async {
    final now = DateTime.now();
    final weekday = now.weekday;
    final weekStart = DateTime(now.year, now.month, now.day - weekday + 1);
    final weekEnd = weekStart.add(const Duration(days: 7));

    final response = await _client
        .from(AppConstants.transactionsTable)
        .select('amount, created_at')
        .gte('created_at', weekStart.toIso8601String())
        .lt('created_at', weekEnd.toIso8601String());

    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final totals = <String, double>{};
    for (final day in dayNames) totals[day] = 0;

    for (final t in (response as List).cast<Map<String, dynamic>>()) {
      final createdAt = DateTime.parse(t['created_at'] as String);
      totals[dayNames[createdAt.weekday - 1]] =
          (totals[dayNames[createdAt.weekday - 1]]! + (t['amount'] as num).toDouble());
    }

    return totals;
  }

  Future<void> recordInvalidAttempt({
    required String referenceCode,
    required double amount,
    required String receiverAccount,
    required String transactionDate,
    required String bankName,
    required String buyerName,
    required String failureReason,
    required int attemptCount,
  }) async {
    final userId = _client.auth.currentUser?.id;
    await _client.from('verification_attempts').insert({
      'reference_code': referenceCode,
      'amount': amount,
      'receiver_account': receiverAccount,
      'transaction_date': transactionDate,
      'bank_name': bankName,
      'buyer_name': buyerName,
      'failure_reason': failureReason,
      'attempt_count': attemptCount,
      'verified_by': userId,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<String?> uploadReceiptImage(String localPath) async {
    try {
      final userId = _client.auth.currentUser?.id ?? 'anonymous';
      final fileName = 'receipt_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storagePath = '$userId/$fileName';
      await _client.storage.from('receipts').upload(
        storagePath,
        File(localPath),
        fileOptions: const FileOptions(contentType: 'image/jpeg'),
      );
      return _client.storage.from('receipts').getPublicUrl(storagePath);
    } catch (e) {
      debugPrint('[uploadReceiptImage] failed: $e');
      return null;
    }
  }

  Future<void> deleteTransaction(String id) async {
    await _client
        .from(AppConstants.transactionsTable)
        .delete()
        .eq('id', id);
  }

  Future<void> clearAllTransactions() async {
    int beforeCount = 0;
    try {
      final rows = await _client.from(AppConstants.transactionsTable).select('id');
      beforeCount = (rows as List).length;
    } catch (_) {}

    if (beforeCount == 0) return;

    // 1) Try the SECURITY DEFINER RPC first (bypasses RLS entirely).
    try {
      await _client.rpc('clear_all_data');
    } catch (e) {
      print('[clearAll] RPC failed – will try per-ID deletes: $e');
      final rows = await _client
          .from(AppConstants.transactionsTable)
          .select('id');
      final ids = (rows as List).map((r) => r['id'] as String).toList();
      var deleted = 0;
      Object? lastError;
      for (final id in ids) {
        try {
          await _client.from(AppConstants.transactionsTable).delete().eq('id', id);
          deleted++;
        } catch (e) {
          lastError = e;
          print('[clearAll] skip tx $id: $e');
        }
      }
      if (deleted == 0 && lastError != null) {
        throw Exception('Delete blocked by database policy: $lastError');
      }
    }

    // Verify rows were actually removed.
    final remaining = await _client.from(AppConstants.transactionsTable).select('id');
    final afterCount = (remaining as List).length;
    if (afterCount > 0) {
      throw Exception(
        'Only ${beforeCount - afterCount} of $beforeCount transactions were deleted. '
        'Run supabase_fix_transaction_delete.sql in Supabase SQL Editor.',
      );
    }

    // Best-effort notification cleanup.
    try {
      final notifRows = await _client.from(AppConstants.notificationsTable).select('id');
      for (final row in notifRows as List) {
        try {
          await _client
              .from(AppConstants.notificationsTable)
              .delete()
              .eq('id', row['id'] as String);
        } catch (_) {}
      }
    } catch (e) {
      print('[clearAll] notification cleanup: $e');
    }
  }
}
