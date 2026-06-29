import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:payment_verifier/data/datasources/supabase_notification_datasource.dart';
import 'package:payment_verifier/data/datasources/supabase_transaction_datasource.dart';
import 'package:payment_verifier/data/repositories/transaction_repository_impl.dart';
import 'package:payment_verifier/data/services/verification_service.dart';
import 'package:payment_verifier/domain/entities/transaction_entity.dart';
import 'package:payment_verifier/domain/repositories/transaction_repository.dart';
import 'package:payment_verifier/presentation/providers/auth_provider.dart';
import 'package:payment_verifier/core/constants/app_constants.dart';
import 'package:payment_verifier/data/services/ocr_service.dart';

final transactionDatasourceProvider =
    Provider<SupabaseTransactionDatasource>((ref) {
  return SupabaseTransactionDatasource(ref.watch(supabaseClientProvider));
});

final transactionRepositoryProvider =
    Provider<TransactionRepositoryImpl>((ref) {
  return TransactionRepositoryImpl(ref.watch(transactionDatasourceProvider));
});

class TransactionFilters {
  const TransactionFilters({
    this.status = 'All Status',
    this.bank = 'All Banks',
    this.search = '',
    this.dateRangeStart,
    this.dateRangeEnd,
    this.amountMin,
    this.amountMax,
  });

  final String status;
  final String bank;
  final String search;
  final DateTime? dateRangeStart;
  final DateTime? dateRangeEnd;
  final double? amountMin;
  final double? amountMax;

  bool get hasDateRange => dateRangeStart != null && dateRangeEnd != null;
  bool get hasAmountRange => amountMin != null || amountMax != null;

  TransactionFilters copyWith({
    String? status,
    String? bank,
    String? search,
    DateTime? dateRangeStart,
    DateTime? dateRangeEnd,
    double? amountMin,
    double? amountMax,
    bool clearDates = false,
    bool clearAmounts = false,
  }) {
    return TransactionFilters(
      status: status ?? this.status,
      bank: bank ?? this.bank,
      search: search ?? this.search,
      dateRangeStart: clearDates ? null : (dateRangeStart ?? this.dateRangeStart),
      dateRangeEnd: clearDates ? null : (dateRangeEnd ?? this.dateRangeEnd),
      amountMin: clearAmounts ? null : (amountMin ?? this.amountMin),
      amountMax: clearAmounts ? null : (amountMax ?? this.amountMax),
    );
  }
}

final transactionFiltersProvider =
    StateProvider<TransactionFilters>((ref) => const TransactionFilters());

final transactionsProvider =
    FutureProvider.autoDispose<List<TransactionEntity>>((ref) async {
  final filters = ref.watch(transactionFiltersProvider);
  final repo = ref.watch(transactionRepositoryProvider);
  final user = ref.watch(currentUserProvider);
  // Waiters only see their own transactions; admins see all
  final userId = (user != null && !user.isAdmin) ? user.id : null;
  return repo.getTransactions(
    statusFilter: filters.status,
    bankFilter: filters.bank,
    searchQuery: filters.search.isEmpty ? null : filters.search,
    userId: userId,
  );
});

final recentTransactionsProvider =
    FutureProvider.autoDispose<List<TransactionEntity>>((ref) async {
  final repo = ref.watch(transactionRepositoryProvider);
  final user = ref.watch(currentUserProvider);
  // Waiters only see their own recent transactions
  final userId = (user != null && !user.isAdmin) ? user.id : null;
  return repo.getRecentTransactions(limit: 5, userId: userId);
});

final dashboardMetricsProvider =
    FutureProvider.autoDispose<DashboardMetrics>((ref) async {
  final repo = ref.watch(transactionRepositoryProvider);
  final user = ref.watch(currentUserProvider);
  // Waiters only see their own metrics; admins see everything
  final userId = (user != null && !user.isAdmin) ? user.id : null;
  return repo.getDashboardMetrics(userId: userId);
});

final deleteTransactionProvider =
    Provider.autoDispose<Future<void> Function(String)>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  return (String id) => repo.deleteTransaction(id);
});

final weeklyTotalsProvider =
    FutureProvider.autoDispose<Map<String, double>>((ref) async {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.getWeeklyTotals();
});

class VerifyState {
  const VerifyState({
    this.selectedBank,
    this.ocrDetectedBank,
    this.ocrRawText = '',
    this.referenceCode = '',
    this.buyerName = '',
    this.receiverName = '',
    this.receiverAccount = '',
    this.transactionDate = '',
    this.orderTotal = 0.0,
    this.amount = 0.0,
    this.tip = 0.0,
    this.isLoading = false,
    this.result,
    this.error,
    this.receiptImage,
    this.ocrCompleted = false,
    this.attemptCount = 0,
    this.verifyResult,
    this.dateElapsed = '',
    this.ocrExtractedCustomerName = '',
    this.ocrExtractedReceiverName = '',
  });

  final String? selectedBank;
  final String? ocrDetectedBank;
  final String ocrRawText;
  final String referenceCode;
  final String buyerName;
  final String receiverName;
  final String receiverAccount;
  final String transactionDate;
  final double orderTotal;
  final double amount;
  final double tip;
  final bool isLoading;
  final TransactionEntity? result;
  final String? error;
  final String? receiptImage;
  final bool ocrCompleted;
  final int attemptCount;
  final VerifyResult? verifyResult;
  final String dateElapsed;
  final String ocrExtractedCustomerName;
  final String ocrExtractedReceiverName;

  bool get canVerify =>
      selectedBank != null &&
      receiptImage != null &&
      referenceCode.isNotEmpty &&
      orderTotal > 0;

  VerifyState copyWith({
    String? selectedBank,
    String? ocrDetectedBank,
    String? ocrRawText,
    String? referenceCode,
    String? buyerName,
    String? receiverName,
    String? receiverAccount,
    String? transactionDate,
    double? orderTotal,
    double? amount,
    double? tip,
    bool? isLoading,
    TransactionEntity? result,
    String? error,
    String? receiptImage,
    bool? ocrCompleted,
    int? attemptCount,
    VerifyResult? verifyResult,
    String? dateElapsed,
    String? ocrExtractedCustomerName,
    String? ocrExtractedReceiverName,
    bool clearResult = false,
    bool clearError = false,
  }) {
    return VerifyState(
      selectedBank: selectedBank ?? this.selectedBank,
      ocrDetectedBank: ocrDetectedBank ?? this.ocrDetectedBank,
      ocrRawText: ocrRawText ?? this.ocrRawText,
      referenceCode: referenceCode ?? this.referenceCode,
      buyerName: buyerName ?? this.buyerName,
      receiverName: receiverName ?? this.receiverName,
      receiverAccount: receiverAccount ?? this.receiverAccount,
      transactionDate: transactionDate ?? this.transactionDate,
      orderTotal: orderTotal ?? this.orderTotal,
      amount: amount ?? this.amount,
      tip: tip ?? this.tip,
      isLoading: isLoading ?? this.isLoading,
      result: clearResult ? null : (result ?? this.result),
      error: clearError ? null : (error ?? this.error),
      receiptImage: receiptImage ?? this.receiptImage,
      ocrCompleted: ocrCompleted ?? this.ocrCompleted,
      attemptCount: attemptCount ?? this.attemptCount,
      verifyResult: verifyResult ?? this.verifyResult,
      dateElapsed: dateElapsed ?? this.dateElapsed,
      ocrExtractedCustomerName: ocrExtractedCustomerName ?? this.ocrExtractedCustomerName,
      ocrExtractedReceiverName: ocrExtractedReceiverName ?? this.ocrExtractedReceiverName,
    );
  }
}

class FraudDetectionResult {
  final double riskScore;
  final List<String> flags;
  final TransactionStatus suggestedStatus;

  const FraudDetectionResult({
    required this.riskScore,
    required this.flags,
    required this.suggestedStatus,
  });
}

FraudDetectionResult analyzeFraudRisk({
  required double amount,
  required String referenceCode,
  required String bankName,
  required String buyerName,
  double orderTotal = 0,
  List<TransactionEntity> existingTransactions = const [],
}) {
  final flags = <String>[];
  double score = 0.0;

  final duplicateCount = existingTransactions
      .where((t) => t.referenceCode == referenceCode)
      .length;
  if (duplicateCount > 0) {
    flags.add('Reference already used in ${duplicateCount + 1} transaction(s)');
    score += 0.4;
  }

  if (amount > 5000) {
    flags.add('Large transaction amount: ${amount.toStringAsFixed(0)} ETB');
    score += 0.2;
  }

  if (orderTotal > 0 && amount < orderTotal) {
    flags.add('Amount paid ($amount ETB) is less than order total ($orderTotal ETB)');
    score += 0.3;
  }

  if (amount > 1000 && amount % 100 == 0) {
    flags.add('Suspiciously round amount for large payment');
    score += 0.1;
  }

  final hour = DateTime.now().hour;
  if (hour >= 23 || hour < 5) {
    flags.add('Transaction at unusual hour (${hour.toString().padLeft(2, '0')}:00)');
    score += 0.15;
  }

  if (amount < 10) {
    flags.add('Unusually low amount');
    score += 0.1;
  }

  final status = score >= 0.7
      ? (duplicateCount > 0
          ? TransactionStatus.duplicate
          : TransactionStatus.fraudSuspected)
      : score >= 0.35
          ? TransactionStatus.needsReview
          : (amount < orderTotal * 0.5
              ? TransactionStatus.failed
              : TransactionStatus.verified);

  return FraudDetectionResult(
    riskScore: score,
    flags: flags,
    suggestedStatus: status,
  );
}

class VerifyNotifier extends StateNotifier<VerifyState> {
  VerifyNotifier(this._repo, this._notifDatasource, this._txDatasource)
      : super(const VerifyState());
  final TransactionRepositoryImpl _repo;
  final SupabaseNotificationDatasource _notifDatasource;
  final SupabaseTransactionDatasource _txDatasource;

  void setBank(String bank) => state = state.copyWith(selectedBank: bank);
  void setOcrDetectedBank(String bank) => state = state.copyWith(ocrDetectedBank: bank);
  void setOcrRawText(String text) => state = state.copyWith(ocrRawText: text);
  void setCode(String code) => state = state.copyWith(referenceCode: normalizeFTReference(code));
  void setBuyerName(String name) => state = state.copyWith(buyerName: name);
  void setReceiverName(String name) => state = state.copyWith(receiverName: name);
  void setReceiverAccount(String acct) => state = state.copyWith(receiverAccount: acct);
  void setTransactionDate(String date) => state = state.copyWith(transactionDate: date);
  void setOcrExtractedCustomerName(String name) => state = state.copyWith(ocrExtractedCustomerName: name);
  void setOcrExtractedReceiverName(String name) => state = state.copyWith(ocrExtractedReceiverName: name);
  void setOrderTotal(double val) {
    final t = state.amount > val ? state.amount - val : 0.0;
    state = state.copyWith(orderTotal: val, tip: t);
  }
  void setAmount(double amt) {
    final tip = amt > state.orderTotal ? amt - state.orderTotal : 0.0;
    state = state.copyWith(amount: amt, tip: tip);
  }
  void setReceiptImage(String? path) {
    // Reset attempt count when a new image is picked so users aren't permanently blocked
    state = state.copyWith(receiptImage: path, attemptCount: 0, ocrCompleted: false);
  }
  void setOcrCompleted() => state = state.copyWith(ocrCompleted: true);
  void setVerifyResult(VerifyResult? r) => state = state.copyWith(
    verifyResult: r,
    dateElapsed: r?.dateElapsed ?? '',
  );

  void setError(String msg) => state = state.copyWith(error: msg);

  Future<TransactionEntity> saveTransaction() async {
    final refCode = state.referenceCode;
    final bank = state.selectedBank ?? 'Telebirr';

    String? imageUrl;
    if (state.receiptImage != null && state.receiptImage!.startsWith('http')) {
      imageUrl = state.receiptImage;
    } else if (state.receiptImage != null) {
      final uploaded = await _txDatasource.uploadReceiptImage(state.receiptImage!);
      if (uploaded != null) imageUrl = uploaded;
    }

    final existingTxs = await _repo.getTransactions();
    final fraudAnalysis = analyzeFraudRisk(
      amount: state.amount,
      referenceCode: refCode,
      bankName: bank,
      buyerName: state.buyerName,
      orderTotal: state.orderTotal,
      existingTransactions: existingTxs,
    );

    final tx = await _repo.createTransaction(
      bankName: bank,
      referenceCode: refCode,
      buyerName: state.buyerName.isEmpty ? 'Unknown Buyer' : state.buyerName,
      amount: state.amount,
      tip: state.tip,
      imageUrl: imageUrl,
      riskScore: fraudAnalysis.riskScore,
      riskFlags: fraudAnalysis.flags,
      orderTotal: state.orderTotal,
      status: fraudAnalysis.suggestedStatus.value,
    );

    if (fraudAnalysis.riskScore >= 0.3) {
      await _notifDatasource.createNotification(
        type: fraudAnalysis.riskScore >= 0.7 ? 'alert' : 'warning',
        title: fraudAnalysis.suggestedStatus == TransactionStatus.fraudSuspected
            ? 'Fraud Suspected'
            : fraudAnalysis.suggestedStatus == TransactionStatus.duplicate
                ? 'Duplicate Detected'
                : 'Needs Review',
        message: fraudAnalysis.flags.isNotEmpty ? fraudAnalysis.flags.first : 'Transaction flagged',
        transactionId: tx.id,
        amount: state.amount,
      );
    }

    state = state.copyWith(isLoading: false, result: tx, attemptCount: 0);
    return tx;
  }

  void reset() => state = const VerifyState();
}

final verifyProvider =
    StateNotifierProvider.autoDispose<VerifyNotifier, VerifyState>((ref) {
  return VerifyNotifier(
    ref.watch(transactionRepositoryProvider),
    SupabaseNotificationDatasource(ref.watch(supabaseClientProvider)),
    ref.watch(transactionDatasourceProvider),
  );
});
