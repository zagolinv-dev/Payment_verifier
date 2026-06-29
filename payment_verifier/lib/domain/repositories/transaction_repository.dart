import 'package:payment_verifier/domain/entities/transaction_entity.dart';

abstract class TransactionRepository {
  /// Fetch all transactions (Admin) or own transactions (Waitress)
  Future<List<TransactionEntity>> getTransactions({
    String? statusFilter,
    String? bankFilter,
    String? searchQuery,
  });

  /// Fetch recent N transactions — pass [userId] to scope to a single waiter
  Future<List<TransactionEntity>> getRecentTransactions({int limit = 5, String? userId});

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

  /// Get aggregated dashboard metrics — pass [userId] to scope to a single waiter
  Future<DashboardMetrics> getDashboardMetrics({String? userId});

  /// Get total income
  Future<double> getTotalIncome({String? userId});

  /// Get total tips
  Future<double> getTotalTips({String? userId});

  /// Count verified and failed today
  Future<({int verified, int failed})> getTodayVerificationCounts({String? userId});

  /// Today's summary total
  Future<({double total, int count})> getTodaySummary({String? userId});

  /// Weekly totals grouped by day (Mon-Sun)
  Future<Map<String, double>> getWeeklyTotals();

  /// Delete a single transaction (admin only)
  Future<void> deleteTransaction(String id);

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
    required this.totalVerified,
    required this.totalFailed,
  });

  final double totalIncome;
  final double totalTips;
  final int verifiedToday;
  final int failedToday;
  final double todayTotal;
  final int todayCount;
  final int totalVerified;
  final int totalFailed;
}
