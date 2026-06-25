import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    this.referenceCode = '',
    this.buyerName = '',
    this.orderTotal = 0.0,
    this.amount = 0.0,
    this.tip = 0.0,
    this.isLoading = false,
    this.result,
    this.error,
    this.receiptImage,
    this.verification,
    this.isVerifying = false,
  });

  final String? selectedBank;
  final String referenceCode;
  final String buyerName;
  final double orderTotal;
  final double amount;
  final double tip;
  final bool isLoading;
  final TransactionEntity? result;
  final String? error;
  final String? receiptImage;
  final ReceiptVerification? verification;
  final bool isVerifying;

  bool get canVerify =>
      selectedBank != null &&
      orderTotal > 0 &&
      amount > 0 &&
      receiptImage != null &&
      buyerName.isNotEmpty;

  VerifyState copyWith({
    String? selectedBank,
    String? referenceCode,
    String? buyerName,
    double? orderTotal,
    double? amount,
    double? tip,
    bool? isLoading,
    TransactionEntity? result,
    String? error,
    String? receiptImage,
    ReceiptVerification? verification,
    bool? isVerifying,
    bool clearResult = false,
    bool clearError = false,
  }) {
    return VerifyState(
      selectedBank: selectedBank ?? this.selectedBank,
      referenceCode: referenceCode ?? this.referenceCode,
      buyerName: buyerName ?? this.buyerName,
      orderTotal: orderTotal ?? this.orderTotal,
      amount: amount ?? this.amount,
      tip: tip ?? this.tip,
      isLoading: isLoading ?? this.isLoading,
      result: clearResult ? null : (result ?? this.result),
      error: clearError ? null : (error ?? this.error),
      receiptImage: receiptImage ?? this.receiptImage,
      verification: verification ?? this.verification,
      isVerifying: isVerifying ?? this.isVerifying,
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
  VerifyNotifier(this._repo) : super(const VerifyState());
  final TransactionRepositoryImpl _repo;

  void setBank(String bank) => state = state.copyWith(selectedBank: bank);
  void setCode(String code) => state = state.copyWith(referenceCode: code);
  void setBuyerName(String name) => state = state.copyWith(buyerName: name);
  void setOrderTotal(double val) => state = state.copyWith(orderTotal: val);
  void setAmount(double amt) {
    final tip = amt > state.orderTotal ? amt - state.orderTotal : 0.0;
    state = state.copyWith(amount: amt, tip: tip);
  }
  void setReceiptImage(String? path) => state = state.copyWith(receiptImage: path);

  void simulateVerification() {
    if (state.selectedBank == null || state.amount <= 0) return;
    final bank = BankName.values.firstWhere(
      (b) => b.displayName == state.selectedBank,
      orElse: () => BankName.cbe,
    );
    final refCode = 'MOCK-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';
    state = state.copyWith(
      referenceCode: refCode,
      isVerifying: true,
      verification: null,
    );
    final verification = ReceiptVerification(
      ownerNameMatch: true,
      amountValid: state.amount >= state.orderTotal,
      referenceFormatValid: PaymentValidators.validateReference(refCode, bank),
      imageIntegrity: true,
      ownerName: "T's Verify Cafe",
    );
    state = state.copyWith(
      verification: verification,
      isVerifying: false,
    );
  }

  Future<void> verify({String? waiterName}) async {
    final bank = state.selectedBank ?? 'Telebirr';
    final refCode = state.referenceCode.isNotEmpty
        ? state.referenceCode
        : 'MOCK-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';

    state = state.copyWith(
      isLoading: true,
      clearResult: true,
      clearError: true,
      selectedBank: bank,
      referenceCode: refCode,
    );
    try {
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
        imageUrl: state.receiptImage,
        riskScore: fraudAnalysis.riskScore,
        riskFlags: fraudAnalysis.flags,
        orderTotal: state.orderTotal,
        status: fraudAnalysis.suggestedStatus.value,
      );

      if (fraudAnalysis.riskScore >= 0.3) {
        AppNotifications.add(NotificationItem(
          id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
          type: fraudAnalysis.riskScore >= 0.7 ? NotificationType.alert : NotificationType.warning,
          title: fraudAnalysis.suggestedStatus == TransactionStatus.fraudSuspected
              ? 'Fraud Suspected'
              : fraudAnalysis.suggestedStatus == TransactionStatus.duplicate
                  ? 'Duplicate Detected'
                  : 'Needs Review',
          message: fraudAnalysis.flags.isNotEmpty ? fraudAnalysis.flags.first : 'Transaction flagged',
          transactionId: tx.id,
          amount: state.amount,
          createdAt: DateTime.now(),
        ));
      }

      state = state.copyWith(isLoading: false, result: tx);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void reset() => state = const VerifyState();
}

final verifyProvider =
    StateNotifierProvider.autoDispose<VerifyNotifier, VerifyState>((ref) {
  return VerifyNotifier(ref.watch(transactionRepositoryProvider));
});

enum NotificationType { info, warning, alert }

class NotificationItem {
  final String id;
  final NotificationType type;
  final String title;
  final String message;
  final String? transactionId;
  final double amount;
  final DateTime createdAt;
  final bool isRead;

  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.transactionId,
    this.amount = 0,
    required this.createdAt,
    this.isRead = false,
  });

  NotificationItem copyWith({bool? isRead}) {
    return NotificationItem(
      id: id,
      type: type,
      title: title,
      message: message,
      transactionId: transactionId,
      amount: amount,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
    );
  }
}

class AppNotifications {
  static final List<NotificationItem> _items = [];

  static List<NotificationItem> get all => List.unmodifiable(_items);
  static int get unreadCount => _items.where((n) => !n.isRead).length;

  static void add(NotificationItem item) {
    _items.insert(0, item);
  }

  static void markRead(String id) {
    final idx = _items.indexWhere((n) => n.id == id);
    if (idx >= 0) {
      _items[idx] = _items[idx].copyWith(isRead: true);
    }
  }

  static void markAllRead() {
    for (var i = 0; i < _items.length; i++) {
      _items[i] = _items[i].copyWith(isRead: true);
    }
  }

  static void clear() => _items.clear();
}

final notificationsProvider = Provider.autoDispose<List<NotificationItem>>((ref) {
  return AppNotifications.all;
});

final unreadCountProvider = Provider.autoDispose<int>((ref) {
  return AppNotifications.unreadCount;
});
