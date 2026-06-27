import 'dart:io';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:payment_verifier/data/datasources/supabase_notification_datasource.dart';
import 'package:payment_verifier/data/datasources/supabase_transaction_datasource.dart';
import 'package:payment_verifier/data/repositories/transaction_repository_impl.dart';
import 'package:payment_verifier/domain/entities/transaction_entity.dart';
import 'package:payment_verifier/domain/repositories/transaction_repository.dart';
import 'package:payment_verifier/presentation/providers/auth_provider.dart';
import 'package:payment_verifier/core/constants/app_constants.dart';

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
  return repo.getTransactions(
    statusFilter: filters.status,
    bankFilter: filters.bank,
    searchQuery: filters.search.isEmpty ? null : filters.search,
  );
});

final recentTransactionsProvider =
    FutureProvider.autoDispose<List<TransactionEntity>>((ref) async {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.getRecentTransactions(limit: 5);
});

final dashboardMetricsProvider =
    FutureProvider.autoDispose<DashboardMetrics>((ref) async {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.getDashboardMetrics();
});

final weeklyTotalsProvider =
    FutureProvider.autoDispose<Map<String, double>>((ref) async {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.getWeeklyTotals();
});

class ReceiptVerification {
  final bool ownerNameMatch;
  final bool amountValid;
  final bool referenceFormatValid;
  final bool imageIntegrity;
  final String ownerName;

  const ReceiptVerification({
    this.ownerNameMatch = false,
    this.amountValid = false,
    this.referenceFormatValid = false,
    this.imageIntegrity = false,
    this.ownerName = '',
  });

  bool get allPassed => ownerNameMatch && amountValid && referenceFormatValid && imageIntegrity;
  int get passedCount => [ownerNameMatch, amountValid, referenceFormatValid, imageIntegrity].where((b) => b).length;
}

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
    this.expectedAmount = 0.0,
    this.amount = 0.0,
    this.tip = 0.0,
    this.isLoading = false,
    this.result,
    this.error,
    this.receiptImage,
    this.verification,
    this.isVerifying = false,
    this.accountMatchPassed = false,
    this.accountMatchNote = '',
    this.ocrCompleted = false,
    this.duplicateCheckPassed = false,
    this.duplicateCheckNote = '',
    this.hasVerified = false,
    this.attemptCount = 0,
    this.maxAttempts = 3,
    this.dateFreshnessPassed = false,
    this.dateFreshnessNote = '',
    this.showFinalRejected = false,
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
  final double expectedAmount;
  final double amount;
  final double tip;
  final bool isLoading;
  final TransactionEntity? result;
  final String? error;
  final String? receiptImage;
  final ReceiptVerification? verification;
  final bool isVerifying;
  final bool accountMatchPassed;
  final String accountMatchNote;
  final bool ocrCompleted;
  final bool duplicateCheckPassed;
  final String duplicateCheckNote;
  final bool hasVerified;
  final int attemptCount;
  final int maxAttempts;
  final bool dateFreshnessPassed;
  final String dateFreshnessNote;
  final bool showFinalRejected;

  double get tolerancePercent {
    if (expectedAmount <= 0 || amount <= 0) return 0;
    return ((amount - expectedAmount) / expectedAmount * 100).abs();
  }

  bool get tolerancePassed => tolerancePercent <= 5.0;

  bool get canVerify =>
      selectedBank != null &&
      receiptImage != null &&
      referenceCode.isNotEmpty;

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
    double? expectedAmount,
    double? amount,
    double? tip,
    bool? isLoading,
    TransactionEntity? result,
    String? error,
    String? receiptImage,
    ReceiptVerification? verification,
    bool? isVerifying,
    bool? accountMatchPassed,
    String? accountMatchNote,
    bool? ocrCompleted,
    bool? duplicateCheckPassed,
    String? duplicateCheckNote,
    bool? hasVerified,
    int? attemptCount,
    bool? dateFreshnessPassed,
    String? dateFreshnessNote,
    bool? showFinalRejected,
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
      expectedAmount: expectedAmount ?? this.expectedAmount,
      amount: amount ?? this.amount,
      tip: tip ?? this.tip,
      isLoading: isLoading ?? this.isLoading,
      result: clearResult ? null : (result ?? this.result),
      error: clearError ? null : (error ?? this.error),
      receiptImage: receiptImage ?? this.receiptImage,
      verification: verification ?? this.verification,
      isVerifying: isVerifying ?? this.isVerifying,
      accountMatchPassed: accountMatchPassed ?? this.accountMatchPassed,
      accountMatchNote: accountMatchNote ?? this.accountMatchNote,
      ocrCompleted: ocrCompleted ?? this.ocrCompleted,
      duplicateCheckPassed: duplicateCheckPassed ?? this.duplicateCheckPassed,
      duplicateCheckNote: duplicateCheckNote ?? this.duplicateCheckNote,
      hasVerified: hasVerified ?? this.hasVerified,
      attemptCount: attemptCount ?? this.attemptCount,
      dateFreshnessPassed: dateFreshnessPassed ?? this.dateFreshnessPassed,
      dateFreshnessNote: dateFreshnessNote ?? this.dateFreshnessNote,
      showFinalRejected: showFinalRejected ?? this.showFinalRejected,
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

// Date parsing helpers ------------------------------------------------

/// Parse a receipt date string into a [DateTime]. Returns null on failure.
DateTime? parseReceiptDate(String raw) {
  final s = raw.trim();
  // "Jun 24, 2026 01:11 PM"
  final m1 = RegExp(
    r'^([A-Z][a-z]{2,8})\s+(\d{1,2}),?\s+(\d{4})(?:\s+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([APap][Mm]?\.?)?)?',
  ).firstMatch(s);
  if (m1 != null) {
    final months = {
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
      'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
    };
    final mon = months[m1.group(1)!.substring(0, 3).toLowerCase()];
    if (mon == null) return null;
    final day = int.parse(m1.group(2)!);
    final year = int.parse(m1.group(3)!);
    int h = int.parse(m1.group(4) ?? '0');
    final min = int.parse(m1.group(5) ?? '0');
    final sec = int.parse((m1.group(6) ?? '0'));
    final ampm = (m1.group(7) ?? '').toUpperCase();
    if (ampm.startsWith('P') && h < 12) h += 12;
    if (ampm.startsWith('A') && h == 12) h = 0;
    return DateTime(year, mon, day, h, min, sec);
  }
  // "19/06/2026, 21:10:59"  or  "2026/05/28 18:24:51"  or  "2026-05-04 16:24:49"
  for (final sep in ['/', '/', '-']) {
    final pattern = sep == '/'
        ? r'^(\d{1,2})/(\d{1,2})/(\d{4})[ ,]+(\d{1,2}):(\d{2})(?::(\d{2}))?'
        : r'^(\d{4})-(\d{1,2})-(\d{1,2})[ ,]+(\d{1,2}):(\d{2})(?::(\d{2}))?';
    final m2 = RegExp(pattern).firstMatch(s);
    if (m2 != null) {
      final a = int.parse(m2.group(1)!);
      final b = int.parse(m2.group(2)!);
      final c = int.parse(m2.group(3)!);
      final h = int.parse(m2.group(4)!);
      final min = int.parse(m2.group(5)!);
      final sec = int.parse((m2.group(6) ?? '0'));
      if (sep == '-') {
        return DateTime(a, b, c, h, min, sec);
      } else {
        // DD/MM/YYYY or MM/DD/YYYY — assume DD/MM/YYYY
        return DateTime(c, b, a, h, min, sec);
      }
    }
  }
  // date-only with no time component
  final m3 = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(s);
  if (m3 != null) {
    return DateTime(int.parse(m3.group(3)!), int.parse(m3.group(2)!), int.parse(m3.group(1)!));
  }
  final m4 = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(s);
  if (m4 != null) {
    return DateTime(int.parse(m4.group(1)!), int.parse(m4.group(2)!), int.parse(m4.group(3)!));
  }
  return null;
}

/// Check whether a receipt date is fresh enough to pass verification.
/// Not in the future (2 min clock-skew allowance), not older than [maxAge].
({bool passed, String note}) checkDateFreshness(String rawDate, {Duration maxAge = const Duration(hours: 24)}) {
  if (rawDate.isEmpty) return (passed: false, note: 'unreadable date');
  final dt = parseReceiptDate(rawDate);
  if (dt == null) return (passed: false, note: 'unreadable date');
  final now = DateTime.now();
  final diff = now.difference(dt);
  // Allow 2 minutes clock skew into the future
  if (diff.isNegative && diff.abs().inMinutes > 2) {
    return (passed: false, note: 'future-dated (${dt.toString().substring(0, 16)})');
  }
  if (diff > maxAge) {
    final hours = diff.inHours;
    return (passed: false, note: 'receipt too old ($hours hours ago, max ${maxAge.inHours}h)');
  }
  return (passed: true, note: 'fresh (${dt.toString().substring(0, 16)})');
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
  void setCode(String code) => state = state.copyWith(referenceCode: code);
  void setBuyerName(String name) => state = state.copyWith(buyerName: name);
  void setReceiverName(String name) => state = state.copyWith(receiverName: name);
  void setReceiverAccount(String acct) => state = state.copyWith(receiverAccount: acct);
  void setTransactionDate(String date) => state = state.copyWith(transactionDate: date);
  void setOrderTotal(double val) {
    final t = state.amount > val ? state.amount - val : 0.0;
    state = state.copyWith(orderTotal: val, expectedAmount: val, tip: t);
  }
  void setAmount(double amt) {
    final tip = amt > state.orderTotal ? amt - state.orderTotal : 0.0;
    state = state.copyWith(amount: amt, tip: tip);
  }
  void setReceiptImage(String? path) => state = state.copyWith(receiptImage: path);
  void setAccountMatch(bool passed, String note) => state = state.copyWith(accountMatchPassed: passed, accountMatchNote: note);
  void setOcrCompleted() => state = state.copyWith(ocrCompleted: true);
  void setAttemptCount(int n) => state = state.copyWith(attemptCount: n);
  void setDateFreshness(bool passed, String note) => state = state.copyWith(dateFreshnessPassed: passed, dateFreshnessNote: note);

  Future<void> checkDuplicate() async {
    if (state.referenceCode.isEmpty) return;
    try {
      final existingTxs = await _repo.getTransactions();
      final dup = existingTxs.where((t) => t.referenceCode == state.referenceCode).toList();
      if (dup.isNotEmpty) {
        final dates = dup.map((t) => t.createdAt.toString().substring(0, 10)).join(', ');
        state = state.copyWith(
          duplicateCheckPassed: false,
          duplicateCheckNote: 'Already used on $dates',
        );
      } else {
        state = state.copyWith(
          duplicateCheckPassed: true,
          duplicateCheckNote: 'No duplicate found — ready to verify',
        );
      }
    } catch (_) {}
  }

  void runDateFreshnessCheck() {
    if (state.transactionDate.isEmpty) {
      state = state.copyWith(dateFreshnessPassed: false, dateFreshnessNote: 'unreadable date');
      return;
    }
    final result = checkDateFreshness(state.transactionDate);
    state = state.copyWith(dateFreshnessPassed: result.passed, dateFreshnessNote: result.note);
  }

  void runLiveCheck() {
    if (state.selectedBank == null || state.amount <= 0) return;
    final bank = BankName.values.firstWhere(
      (b) => b.displayName == state.selectedBank,
      orElse: () => BankName.cbe,
    );
    final hasImage = state.receiptImage != null && File(state.receiptImage!).existsSync();
    final verification = ReceiptVerification(
      ownerNameMatch: state.buyerName.trim().length >= 2,
      amountValid: state.amount >= state.orderTotal,
      referenceFormatValid: state.referenceCode.isNotEmpty
          ? PaymentValidators.validateReference(state.referenceCode, bank)
          : false,
      imageIntegrity: hasImage,
      ownerName: state.buyerName,
    );
    state = state.copyWith(verification: verification);
  }

  Future<void> verify({String? waiterName, String? managerName}) async {
    if (state.referenceCode.isEmpty) {
      state = state.copyWith(error: 'Reference code is required. Enter it manually or scan a valid receipt.');
      return;
    }

    final bank = state.selectedBank ?? 'Telebirr';
    final refCode = state.referenceCode;

    state = state.copyWith(
      isLoading: true,
      clearResult: true,
      clearError: true,
      hasVerified: true,
      selectedBank: bank,
      referenceCode: refCode,
    );
    try {
      await _doVerify(managerName: managerName, waiterName: waiterName).timeout(const Duration(seconds: 10));
    } on TimeoutException {
      state = state.copyWith(
        accountMatchNote: 'could not confirm — check manually',
        accountMatchPassed: false,
        hasVerified: true,
      );
      _handleFailure('Fetch receipt page timed out after 10s — could not confirm', waiterName);
    } catch (e) {
      state = state.copyWith(
        accountMatchNote: 'could not confirm — check manually',
        accountMatchPassed: false,
        hasVerified: true,
      );
      _handleFailure(e.toString(), waiterName);
    }
  }

  void _handleFailure(String errorMsg, String? waiterName) {
    final attempt = state.attemptCount + 1;
    if (attempt >= state.maxAttempts) {
      // 3rd failure — final reject
      _recordInvalidAttempt(errorMsg, attempt);
      state = state.copyWith(
        isLoading: false,
        error: 'This receipt is not valid',
        attemptCount: attempt,
        showFinalRejected: true,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        error: 'Scan failed — please scan again ($attempt/${state.maxAttempts})',
        attemptCount: attempt,
      );
    }
  }

  Future<void> _recordInvalidAttempt(String reason, int attempt) async {
    try {
      await _txDatasource.recordInvalidAttempt(
        referenceCode: state.referenceCode,
        amount: state.amount,
        receiverAccount: state.receiverAccount,
        transactionDate: state.transactionDate,
        bankName: state.selectedBank ?? '',
        buyerName: state.buyerName,
        failureReason: reason,
        attemptCount: attempt,
      );
      print('[Verify] invalid attempt #$attempt recorded: $reason');
    } catch (e) {
      print('[Verify] failed to record invalid attempt: $e');
    }
  }

  Future<void> _doVerify({String? managerName, String? waiterName}) async {
    final bank = state.selectedBank ?? 'Telebirr';
    final refCode = state.referenceCode;

    // Run freshness check
    runDateFreshnessCheck();

    final existingTxs = await _repo.getTransactions();
    final fraudAnalysis = analyzeFraudRisk(
      amount: state.amount,
      referenceCode: refCode,
      bankName: bank,
      buyerName: state.buyerName,
      orderTotal: state.orderTotal,
      existingTransactions: existingTxs,
    );
    final flags = [...fraudAnalysis.flags];

    // ── Critical Failure Checks ─────────────────────────────────────────

    // 0. Bank method mismatch — selected bank must match receipt
    if (state.ocrDetectedBank != null && state.selectedBank != null &&
        state.ocrDetectedBank != state.selectedBank) {
      _handleFailure('Bank mismatch: receipt shows "${state.ocrDetectedBank}" but "${state.selectedBank}" was selected', waiterName);
      return;
    }

    // 1. Receiver account mismatch
    if (state.receiverAccount.isNotEmpty && !state.accountMatchPassed) {
      _handleFailure('Receiver account mismatch: ${state.accountMatchNote}', waiterName);
      return;
    }

    // 2. Duplicate receipt → fraud
    if (!state.duplicateCheckPassed && state.duplicateCheckNote.isNotEmpty) {
      _handleFailure('Duplicate receipt: ${state.duplicateCheckNote}', waiterName);
      return;
    }

    // 3. Old receipt
    if (state.transactionDate.isNotEmpty && !state.dateFreshnessPassed) {
      _handleFailure('Receipt too old: ${state.dateFreshnessNote}', waiterName);
      return;
    }

    // 4. Receiver name mismatch (manager name check)
    if (state.receiverName.isNotEmpty && managerName != null && managerName.isNotEmpty) {
      final receiptName = state.receiverName.trim().toLowerCase();
      final manager = managerName.trim().toLowerCase();
      if (!receiptName.contains(manager) && !manager.contains(receiptName)) {
        _handleFailure('Receiver name mismatch: receipt pays "$receiptName" which does not match your business name', waiterName);
        return;
      }
    }

    // 5. Amount less than expected (exact match required)
    if (state.orderTotal > 0 && state.amount < state.orderTotal) {
      _handleFailure('Amount underpaid: ${state.amount.toStringAsFixed(0)} ETB < ${state.orderTotal.toStringAsFixed(0)} ETB', waiterName);
      return;
    }

    // ── Non-critical flags ──────────────────────────────────────────────

    if (state.accountMatchPassed && state.receiverAccount.isNotEmpty) {
      flags.insert(0, 'Receiver account verified: ${state.accountMatchNote}');
    }
    if (!state.dateFreshnessPassed && state.transactionDate.isNotEmpty) {
      flags.insert(0, 'Date freshness: ${state.dateFreshnessNote}');
    }

    print('[Verify] amount=${state.amount} ref=$refCode receiver=${state.receiverAccount} date=${state.transactionDate} attempts=${state.attemptCount + 1}');

    final tx = await _repo.createTransaction(
      bankName: bank,
      referenceCode: refCode,
      buyerName: state.buyerName.isEmpty ? 'Unknown Buyer' : state.buyerName,
      amount: state.amount,
      tip: state.tip,
      imageUrl: state.receiptImage,
      riskScore: fraudAnalysis.riskScore,
      riskFlags: flags,
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

    // Success — reset attempt counter
    state = state.copyWith(isLoading: false, result: tx, attemptCount: 0);
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
