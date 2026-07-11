import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:payment_verifier/core/constants/app_constants.dart';
import 'package:payment_verifier/data/models/transaction_model.dart';
import 'package:payment_verifier/domain/repositories/transaction_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseTransactionDatasource {
  SupabaseTransactionDatasource(this._client);
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

  Future<List<TransactionModel>> getTransactions({
    String? statusFilter,
    String? bankFilter,
    String? searchQuery,
    String? userId,
    String? ownerId,
  }) async {
    // Filters must be applied before transform operations (order)
    // ownerId == '' means explicitly skip the owner_id scope (e.g. admin viewing a waiter)
    final resolvedOwnerId = (ownerId == '') ? null : (ownerId ?? await _resolveScopeOwnerId());
    var transactions = <TransactionModel>[];
    try {
      final base = _client.from(AppConstants.transactionsTable).select();
      var baseFiltered = base;
      if (resolvedOwnerId != null) {
        baseFiltered = baseFiltered.eq('owner_id', resolvedOwnerId);
      }
      if (userId != null) {
        baseFiltered = baseFiltered.eq('verified_by', userId);
      }
      final response = await baseFiltered.order('created_at', ascending: false);
      transactions = (response as List)
          .map((e) => TransactionModel.fromJson(e))
          .toList();
    } catch (_) {
      var fallbackQuery = _client
          .from(AppConstants.transactionsTable)
          .select();
      if (resolvedOwnerId != null) {
        fallbackQuery = fallbackQuery.eq('owner_id', resolvedOwnerId);
      }
      final response = await fallbackQuery.order('created_at', ascending: false);
      transactions = (response as List)
          .map((e) => TransactionModel.fromJson(e))
          .toList();
      if (userId != null) {
        transactions = transactions.where((t) => t.verifiedBy == userId).toList();
      }
    }

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

  Future<List<TransactionModel>> getRecentTransactions({int limit = 5, String? userId, String? ownerId}) async {
    // Filters (eq) must come before transform operations (order, limit)
    final scopeOwnerId = ownerId ?? await _resolveScopeOwnerId();
    try {
      final base = _client.from(AppConstants.transactionsTable).select();
      var filtered = base;
      if (scopeOwnerId != null) {
        filtered = filtered.eq('owner_id', scopeOwnerId);
      }
      if (userId != null) {
        filtered = filtered.eq('verified_by', userId);
      }
      final response = await filtered
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((e) => TransactionModel.fromJson(e))
          .toList();
    } catch (_) {
      var fallbackQuery = _client
          .from(AppConstants.transactionsTable)
          .select();
      if (scopeOwnerId != null) {
        fallbackQuery = fallbackQuery.eq('owner_id', scopeOwnerId);
      }
      final response = await fallbackQuery
          .order('created_at', ascending: false)
          .limit(limit);
      var txs = (response as List)
          .map((e) => TransactionModel.fromJson(e))
          .toList();
      if (userId != null) {
        txs = txs.where((t) => t.verifiedBy == userId).toList();
      }
      return txs;
    }
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
    final ownerId = await _resolveScopeOwnerId() ?? userId;
    final data = {
      'bank_name': bankName,
      'reference_code': referenceCode,
      'buyer_name': buyerName,
      'amount': amount,
      'tip': tip,
      'status': status,
      'verified_by': userId,
      'owner_id': ownerId,
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

    return TransactionModel.fromJson(response);
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
    final ownerId = await _resolveScopeOwnerId();

    List<Map<String, dynamic>> todayTxs;
    List<Map<String, dynamic>> allTxs;
    try {
      var todayQuery = _client
        .from(AppConstants.transactionsTable)
          .select('amount, tip, status, verified_by')
        .gte('created_at', todayStart.toIso8601String())
        .lt('created_at', todayEnd.toIso8601String());
      if (ownerId != null) todayQuery = todayQuery.eq('owner_id', ownerId);
      if (userId != null) todayQuery = todayQuery.eq('verified_by', userId);
      final todayResponse = await todayQuery;
      todayTxs = (todayResponse as List).cast<Map<String, dynamic>>();

      var allQuery = _client
        .from(AppConstants.transactionsTable)
          .select('amount, tip, status, verified_by');
      if (ownerId != null) allQuery = allQuery.eq('owner_id', ownerId);
      if (userId != null) allQuery = allQuery.eq('verified_by', userId);
      final allResponse = await allQuery;
      allTxs = (allResponse as List).cast<Map<String, dynamic>>();
    } catch (_) {
      var todayFallback = _client
          .from(AppConstants.transactionsTable)
          .select('amount, tip, status, created_at')
          .gte('created_at', todayStart.toIso8601String())
          .lt('created_at', todayEnd.toIso8601String());
      if (ownerId != null) todayFallback = todayFallback.eq('owner_id', ownerId);
      final todayResponse = await todayFallback;

      var allFallback = _client
          .from(AppConstants.transactionsTable)
          .select('amount, tip, status, verified_by');
      if (ownerId != null) allFallback = allFallback.eq('owner_id', ownerId);
      final allResponse = await allFallback;

      todayTxs = (todayResponse as List).cast<Map<String, dynamic>>();
      allTxs = (allResponse as List).cast<Map<String, dynamic>>();
      if (userId != null) {
      todayTxs = todayTxs.where((t) => t['verified_by'] == userId).toList();
      allTxs = allTxs.where((t) => t['verified_by'] == userId).toList();
      }
    }

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

  Future<Map<String, double>> getWeeklyTotals({String? ownerId}) async {
    final now = DateTime.now();
    final weekday = now.weekday;
    final weekStart = DateTime(now.year, now.month, now.day - weekday + 1);
    final weekEnd = weekStart.add(const Duration(days: 7));
    final scopeOwnerId = ownerId ?? await _resolveScopeOwnerId();

    final response = await (() async {
      try {
        var query = _client
            .from(AppConstants.transactionsTable)
            .select('amount, created_at')
            .gte('created_at', weekStart.toIso8601String())
            .lt('created_at', weekEnd.toIso8601String());
        if (scopeOwnerId != null) query = query.eq('owner_id', scopeOwnerId);
        return await query;
      } catch (_) {
        var fallbackQuery = _client
            .from(AppConstants.transactionsTable)
            .select('amount, created_at')
            .gte('created_at', weekStart.toIso8601String())
            .lt('created_at', weekEnd.toIso8601String());
        if (scopeOwnerId != null) fallbackQuery = fallbackQuery.eq('owner_id', scopeOwnerId);
        return await fallbackQuery;
      }
    })();

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
        fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: false),
      );
      // Try public URL first; if the bucket is private this will still work
      // as long as the bucket has public read enabled.
      // We embed the storagePath as a fragment so we can regenerate a signed
      // URL later without storing a separate column.
      final publicUrl = _client.storage.from('receipts').getPublicUrl(storagePath);
      // Append storagePath as a custom query param so the widget can retry
      return '$publicUrl#path=$storagePath';
    } catch (e) {
      debugPrint('[uploadReceiptImage] failed: $e');
      return null;
    }
  }

  /// Generates a fresh 1-year signed URL for a receipt.
  /// [storagePath] is the path inside the "receipts" bucket, e.g. "userId/receipt_123.jpg"
  Future<String?> getSignedReceiptUrl(String storagePath) async {
    try {
      return await _client.storage
          .from('receipts')
          .createSignedUrl(storagePath, 60 * 60 * 24 * 365); // 1 year
    } catch (e) {
      debugPrint('[getSignedReceiptUrl] failed: $e');
      return null;
    }
  }

  Future<void> deleteTransaction(String id) async {
    final scopeOwnerId = await _resolveScopeOwnerId();
    try {
      var query = _client.from(AppConstants.transactionsTable).delete().eq('id', id);
      if (scopeOwnerId != null) {
        query = query.eq('owner_id', scopeOwnerId);
      }
      await query;
    } catch (_) {
      var fallbackQuery = _client.from(AppConstants.transactionsTable).delete().eq('id', id);
      if (scopeOwnerId != null) {
        fallbackQuery = fallbackQuery.eq('owner_id', scopeOwnerId);
      }
      await fallbackQuery;
    }
  }

  Future<void> clearAllTransactions({String? ownerId}) async {
    int beforeCount = 0;
    final scopeOwnerId = ownerId ?? await _resolveScopeOwnerId();
    try {
      var rowsQuery = _client.from(AppConstants.transactionsTable).select('id');
      if (scopeOwnerId != null) rowsQuery = rowsQuery.eq('owner_id', scopeOwnerId);
      final rows = await rowsQuery;
      beforeCount = (rows as List).length;
    } catch (_) {}

    if (beforeCount == 0) return;

    // 1) Try the SECURITY DEFINER RPC first (bypasses RLS entirely).
    try {
      await _client.rpc('clear_all_data');
    } catch (e) {
      print('[clearAll] RPC failed – will try per-ID deletes: $e');
      var rowsQuery = _client.from(AppConstants.transactionsTable).select('id');
      if (scopeOwnerId != null) rowsQuery = rowsQuery.eq('owner_id', scopeOwnerId);
      final rows = await rowsQuery;
      final ids = (rows as List).map((r) => r['id'] as String).toList();
      var deleted = 0;
      Object? lastError;
      for (final id in ids) {
        try {
          var deleteQuery = _client.from(AppConstants.transactionsTable).delete().eq('id', id);
          if (scopeOwnerId != null) deleteQuery = deleteQuery.eq('owner_id', scopeOwnerId);
          await deleteQuery;
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
  var remainingQuery = _client.from(AppConstants.transactionsTable).select('id');
  if (scopeOwnerId != null) remainingQuery = remainingQuery.eq('owner_id', scopeOwnerId);
  final remaining = await remainingQuery;
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
