import 'package:payment_verifier/domain/entities/transaction_entity.dart';

abstract class TransactionRepository {
  /// Fetch all transactions (Admin) or own transactions (Waitress)
  Future<List<TransactionEntity>> getTransactions({
    String? statusFilter,
    String? bankFilter,
    String? searchQuery,
  });

  /// Fetch recent N transactions
  Future<List<TransactionEntity>> getRecentTransactions({int limit = 5});

  /// Submit a new payment verification
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
  });

  /// Get aggregated dashboard metrics
  Future<DashboardMetrics> getDashboardMetrics();

  /// Get total income
  Future<double> getTotalIncome();

  /// Get total tips
  Future<double> getTotalTips();

  /// Count verified and failed today
  Future<({int verified, int failed})> getTodayVerificationCounts();

  /// Today's summary total
  Future<({double total, int count})> getTodaySummary();

  /// Weekly totals grouped by day (Mon-Sun)
  Future<Map<String, double>> getWeeklyTotals();

  /// Delete all transactions (admin only)
  Future<void> clearAllTransactions();
}

class DashboardMetrics {
  const DashboardMetrics({
    required this.totalIncome,
    required this.totalTips,
    required this.verifiedToday,
    required this.failedToday,
    required this.todayTotal,
    required this.todayCount,
  });

  final double totalIncome;
  final double totalTips;
  final int verifiedToday;
  final int failedToday;
  final double todayTotal;
  final int todayCount;
}
