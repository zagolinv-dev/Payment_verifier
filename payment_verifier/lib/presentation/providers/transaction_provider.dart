import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:payment_verifier/data/datasources/supabase_transaction_datasource.dart';
import 'package:payment_verifier/data/repositories/transaction_repository_impl.dart';
import 'package:payment_verifier/domain/entities/transaction_entity.dart';
import 'package:payment_verifier/domain/repositories/transaction_repository.dart';
import 'package:payment_verifier/presentation/providers/auth_provider.dart';
import 'package:payment_verifier/core/constants/app_constants.dart';
import 'package:payment_verifier/core/utils/mock_data.dart';

// ── Datasource & Repository Providers ─────────────────────────────────────────

final transactionDatasourceProvider =
    Provider<SupabaseTransactionDatasource>((ref) {
  return SupabaseTransactionDatasource(ref.watch(supabaseClientProvider));
});

final transactionRepositoryProvider =
    Provider<TransactionRepositoryImpl>((ref) {
  return TransactionRepositoryImpl(ref.watch(transactionDatasourceProvider));
});

// ── Filters State ─────────────────────────────────────────────────────────────

class TransactionFilters {
  const TransactionFilters({
    this.status = 'All Status',
    this.bank = 'All Banks',
    this.search = '',
  });

  final String status;
  final String bank;
  final String search;

  TransactionFilters copyWith({String? status, String? bank, String? search}) {
    return TransactionFilters(
      status: status ?? this.status,
      bank: bank ?? this.bank,
      search: search ?? this.search,
    );
  }
}

final transactionFiltersProvider =
    StateProvider<TransactionFilters>((ref) => const TransactionFilters());

// ── Transaction List ──────────────────────────────────────────────────────────

final transactionsProvider =
    FutureProvider.autoDispose<List<TransactionEntity>>((ref) async {
  final filters = ref.watch(transactionFiltersProvider);
  final all = MockData.transactions;
  
  return all.where((tx) {
    final matchesStatus = filters.status == 'All Status' ||
        tx.status.name.toLowerCase() == filters.status.toLowerCase();
    
    final matchesBank = filters.bank == 'All Banks' ||
        tx.bankName.toLowerCase().contains(filters.bank.toLowerCase());
        
    final matchesSearch = filters.search.isEmpty ||
        tx.referenceCode.toLowerCase().contains(filters.search.toLowerCase()) ||
        tx.buyerName.toLowerCase().contains(filters.search.toLowerCase());
        
    return matchesStatus && matchesBank && matchesSearch;
  }).toList();
});

// ── Recent Transactions (dashboard) ──────────────────────────────────────────

final recentTransactionsProvider =
    FutureProvider.autoDispose<List<TransactionEntity>>((ref) async {
  final all = MockData.transactions;
  return all.take(5).toList();
});

// ── Dashboard Metrics ─────────────────────────────────────────────────────────

final dashboardMetricsProvider =
    FutureProvider.autoDispose<DashboardMetrics>((ref) async {
  final txs = MockData.transactions;
  final now = DateTime.now();
  
  double totalIncome = 0;
  double totalTips = 0;
  for (final t in txs) {
    if (t.status == TransactionStatus.verified) {
      totalIncome += t.amount;
      totalTips += t.tip;
    }
  }

  int verifiedToday = 0;
  int failedToday = 0;
  double todayTotal = 0;
  int todayCount = 0;
  
  for (final t in txs) {
    final isToday = t.createdAt.year == now.year &&
        t.createdAt.month == now.month &&
        t.createdAt.day == now.day;
        
    if (isToday) {
      if (t.status == TransactionStatus.verified) {
        verifiedToday++;
        todayTotal += t.amount + t.tip;
        todayCount++;
      } else if (t.status == TransactionStatus.failed) {
        failedToday++;
      }
    }
  }

  return DashboardMetrics(
    totalIncome: totalIncome,
    totalTips: totalTips,
    verifiedToday: verifiedToday,
    failedToday: failedToday,
    todayTotal: todayTotal,
    todayCount: todayCount,
  );
});

// ── Verify Payment Notifier ───────────────────────────────────────────────────

enum VerifyMode { scan, code }

class VerifyState {
  const VerifyState({
    this.mode = VerifyMode.code,
    this.selectedBank,
    this.referenceCode = '',
    this.buyerName = '',
    this.amount = 0.0,
    this.tip = 0.0,
    this.isLoading = false,
    this.result,
    this.error,
  });

  final VerifyMode mode;
  final String? selectedBank;
  final String referenceCode;
  final String buyerName;
  final double amount;
  final double tip;
  final bool isLoading;
  final TransactionEntity? result;
  final String? error;

  VerifyState copyWith({
    VerifyMode? mode,
    String? selectedBank,
    String? referenceCode,
    String? buyerName,
    double? amount,
    double? tip,
    bool? isLoading,
    TransactionEntity? result,
    String? error,
    bool clearResult = false,
    bool clearError = false,
  }) {
    return VerifyState(
      mode: mode ?? this.mode,
      selectedBank: selectedBank ?? this.selectedBank,
      referenceCode: referenceCode ?? this.referenceCode,
      buyerName: buyerName ?? this.buyerName,
      amount: amount ?? this.amount,
      tip: tip ?? this.tip,
      isLoading: isLoading ?? this.isLoading,
      result: clearResult ? null : (result ?? this.result),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class VerifyNotifier extends StateNotifier<VerifyState> {
  VerifyNotifier(this._repo) : super(const VerifyState());
  final TransactionRepositoryImpl _repo;

  void setMode(VerifyMode mode) => state = state.copyWith(mode: mode);
  void setBank(String bank) => state = state.copyWith(selectedBank: bank);
  void setCode(String code) => state = state.copyWith(referenceCode: code);
  void setBuyerName(String name) => state = state.copyWith(buyerName: name);
  void setAmount(double amt) => state = state.copyWith(amount: amt);
  void setTip(double tip) => state = state.copyWith(tip: tip);

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
      await Future.delayed(const Duration(milliseconds: 1200));
      
      final tx = TransactionEntity(
        id: 'tx-${DateTime.now().millisecondsSinceEpoch}',
        bankName: bank,
        referenceCode: refCode,
        buyerName: state.buyerName.isEmpty ? 'Unknown Buyer' : state.buyerName,
        amount: state.amount,
        tip: state.tip,
        status: TransactionStatus.verified,
        verifiedBy: waiterName ?? 'System',
        createdAt: DateTime.now(),
      );
      MockData.transactions.insert(0, tx);
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
