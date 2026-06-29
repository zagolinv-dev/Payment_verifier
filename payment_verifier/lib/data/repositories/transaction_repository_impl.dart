import 'package:payment_verifier/data/datasources/supabase_transaction_datasource.dart';
import 'package:payment_verifier/data/models/transaction_model.dart';
import 'package:payment_verifier/domain/entities/transaction_entity.dart';
import 'package:payment_verifier/domain/repositories/transaction_repository.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  TransactionRepositoryImpl(this._datasource);
  final SupabaseTransactionDatasource _datasource;

  @override
  Future<List<TransactionEntity>> getTransactions({
    String? statusFilter,
    String? bankFilter,
    String? searchQuery,
  }) => _datasource.getTransactions(
        statusFilter: statusFilter,
        bankFilter: bankFilter,
        searchQuery: searchQuery,
      );

  @override
  Future<List<TransactionEntity>> getRecentTransactions({int limit = 5}) =>
      _datasource.getRecentTransactions(limit: limit);

  @override
  Future<TransactionEntity> createTransaction({
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
  }) => _datasource.createTransaction(
        bankName: bankName,
        referenceCode: referenceCode,
        buyerName: buyerName,
        amount: amount,
        tip: tip,
        imageUrl: imageUrl,
        riskScore: riskScore,
        riskFlags: riskFlags,
        orderTotal: orderTotal,
        status: status,
      );

  @override
  Future<DashboardMetrics> getDashboardMetrics() =>
      _datasource.getDashboardMetrics();

  @override
  Future<double> getTotalIncome() async {
    final metrics = await _datasource.getDashboardMetrics();
    return metrics.totalIncome;
  }

  @override
  Future<double> getTotalTips() async {
    final metrics = await _datasource.getDashboardMetrics();
    return metrics.totalTips;
  }

  @override
  Future<({int verified, int failed})> getTodayVerificationCounts() async {
    final metrics = await _datasource.getDashboardMetrics();
    return (verified: metrics.verifiedToday, failed: metrics.failedToday);
  }

  @override
  Future<({double total, int count})> getTodaySummary() async {
    final metrics = await _datasource.getDashboardMetrics();
    return (total: metrics.todayTotal, count: metrics.todayCount);
  }

  @override
  Future<Map<String, double>> getWeeklyTotals() =>
      _datasource.getWeeklyTotals();

  @override
  Future<void> deleteTransaction(String id) =>
      _datasource.deleteTransaction(id);

  @override
  Future<void> clearAllTransactions() =>
      _datasource.clearAllTransactions();
}
