import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:payment_verifier/core/theme/app_theme.dart';
import 'package:payment_verifier/core/utils/formatters.dart';
import 'package:payment_verifier/core/utils/pdf_export.dart';
import 'package:payment_verifier/core/constants/app_constants.dart';
import 'package:payment_verifier/domain/entities/transaction_entity.dart';
import 'package:payment_verifier/presentation/providers/theme_provider.dart';
import 'package:payment_verifier/presentation/providers/transaction_provider.dart';
import 'package:payment_verifier/presentation/providers/user_provider.dart';
import 'package:payment_verifier/presentation/widgets/status_chip.dart';
import 'package:payment_verifier/presentation/widgets/blur_overlay.dart';
import 'package:flutter/services.dart';
import 'package:payment_verifier/presentation/providers/auth_provider.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final waiterTransactionsProvider =
    FutureProvider.family<List<TransactionEntity>, String>((ref, waiterId) async {
  // Query directly filtered by waiterId — does NOT depend on transactionsProvider
  // so the admin's global view doesn't bleed through.
  final repo = ref.read(transactionRepositoryProvider);
  final txs = await repo.getTransactions(userId: waiterId);
  return txs
      .where((tx) => tx.status == TransactionStatus.verified)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
});

// ── Screen ────────────────────────────────────────────────────────────────────

class WaiterDetailScreen extends ConsumerStatefulWidget {
  const WaiterDetailScreen({
    super.key,
    required this.waiterId,
    required this.waiterName,
    required this.waiterEmail,
  });

  final String waiterId;
  final String waiterName;
  final String waiterEmail;

  @override
  ConsumerState<WaiterDetailScreen> createState() => _WaiterDetailScreenState();
}

class _WaiterDetailScreenState extends ConsumerState<WaiterDetailScreen> {
  String _chartPeriod = 'Weekly';
  bool _deleting = false;

  List<TransactionEntity> _filterByPeriod(List<TransactionEntity> txs, String period) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(Duration(days: todayStart.weekday - 1));
    final monthStart = todayStart.subtract(const Duration(days: 30));
    final since = period == 'Daily'
        ? todayStart
        : period == 'Weekly'
            ? weekStart
            : monthStart;
    return txs.where((tx) => tx.createdAt.isAfter(since)).toList();
  }

  Map<String, double> _chartData(List<TransactionEntity> txs, String period) {
    final result = <String, double>{};
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    if (period == 'Daily') {
      for (int h = 0; h < 12; h++) {
        final label = '${h + 8}';
        double total = 0;
        for (final tx in txs) {
          final hour = tx.createdAt.hour;
          if (hour >= 8 && hour < 20 && (hour - 8) ~/ 2 == h) {
            total += tx.amount;
          }
        }
        result[label] = total;
      }
    } else if (period == 'Weekly') {
      final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final weekStart = todayStart.subtract(Duration(days: todayStart.weekday - 1));
      for (int i = 0; i < 7; i++) {
        final day = weekStart.add(Duration(days: i));
        final label = dayNames[i];
        double total = 0;
        for (final tx in txs) {
          if (tx.createdAt.year == day.year &&
              tx.createdAt.month == day.month &&
              tx.createdAt.day == day.day) {
            total += tx.amount;
          }
        }
        result[label] = total;
      }
    } else {
      for (int m = 0; m < 12; m++) {
        final label = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m];
        double total = 0;
        for (final tx in txs) {
          if (tx.createdAt.year == now.year && tx.createdAt.month == m + 1) {
            total += tx.amount;
          }
        }
        result[label] = total;
      }
    }
    return result;
  }

  Future<void> _exportPdf(List<TransactionEntity> txs) async {
    await ReceiptPdfExport.exportWaiterReceipts(
      transactions: txs,
      waiterName: widget.waiterName,
    );
  }

  Future<void> _deleteWaiter() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ref.watch(themeProvider) == ThemeMode.dark
            ? AppTheme.bgCard
            : AppTheme.lightCard,
        title: Text('Delete Waiter',
            style: GoogleFonts.outfit(color: ref.watch(themeProvider) == ThemeMode.dark
                ? AppTheme.textPrimary
                : AppTheme.lightTextPrimary)),
        content: Text(
          'Are you sure you want to delete ${widget.waiterName}? This action cannot be undone.',
          style: GoogleFonts.inter(
            color: ref.watch(themeProvider) == ThemeMode.dark
                ? AppTheme.textSecondary
                : AppTheme.lightTextSecondary,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppTheme.textTertiary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            child: Text('Delete', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _deleting = true);
    final success = await ref.read(userManagementProvider.notifier).deleteUser(widget.waiterId);
    if (mounted) {
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '${widget.waiterName} deleted' : 'Failed to delete'),
          backgroundColor: success ? AppTheme.primaryGreen : AppTheme.error,
        ),
      );
      if (success) Navigator.pop(context);
    }
  }

  void _showResetPasswordDialog() {
    final isDark = ref.read(themeProvider) == ThemeMode.dark;
    final card = isDark ? AppTheme.bgCard : AppTheme.lightCard;
    final textPrimary = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;

    String newPassword = '';
    bool isResetting = false;
    String resetSuccessPassword = '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              backgroundColor: card,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.lock_reset_rounded, color: AppTheme.warning, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text('Reset Password', style: GoogleFonts.outfit(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              content: resetSuccessPassword.isNotEmpty
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: AppTheme.primaryGreen, size: 18),
                            const SizedBox(width: 8),
                            Text('Password reset!', style: GoogleFonts.inter(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: resetSuccessPassword));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: AppTheme.primaryGreen,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                content: Text('Password copied!', style: GoogleFonts.inter(color: Colors.white)),
                              ),
                            );
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.warning.withOpacity(0.2)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    resetSuccessPassword,
                                    style: GoogleFonts.robotoMono(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.5),
                                  ),
                                ),
                                const Icon(Icons.copy_rounded, size: 18, color: AppTheme.warning),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('Tap to copy and send to ${widget.waiterName}.', style: GoogleFonts.inter(color: textSecondary, fontSize: 11)),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Set a new password for ${widget.waiterName}.',
                          style: GoogleFonts.inter(color: textSecondary, fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          onChanged: (v) => newPassword = v,
                          style: GoogleFonts.inter(color: textPrimary),
                          obscureText: false,
                          decoration: InputDecoration(
                            hintText: 'Min 8 characters',
                            hintStyle: GoogleFonts.inter(color: textSecondary.withOpacity(0.5)),
                            filled: true,
                            fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppTheme.warning.withOpacity(0.4)),
                            ),
                            prefixIcon: Icon(Icons.lock_outline_rounded, color: textSecondary.withOpacity(0.5), size: 20),
                          ),
                        ),
                      ],
                    ),
              actions: resetSuccessPassword.isNotEmpty
                  ? [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text('Done', style: GoogleFonts.inter(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold)),
                      ),
                    ]
                  : [
                      TextButton(
                        onPressed: isResetting ? null : () => Navigator.pop(ctx),
                        child: Text('Cancel', style: GoogleFonts.inter(color: textSecondary)),
                      ),
                      ElevatedButton(
                        onPressed: isResetting || newPassword.length < 8
                            ? null
                            : () async {
                                setState(() => isResetting = true);
                                try {
                                  final supabase = ref.read(supabaseClientProvider);
                                  final res = await supabase.functions.invoke(
                                    'reset-user-password',
                                    body: {'email': widget.waiterEmail, 'newPassword': newPassword},
                                  );
                                  if (res.status == 200) {
                                    setState(() => resetSuccessPassword = newPassword);
                                  } else {
                                    throw Exception(res.data['error'] ?? 'Unknown error');
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        behavior: SnackBarBehavior.floating,
                                        backgroundColor: AppTheme.error,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        content: Text('Failed: $e', style: GoogleFonts.inter(color: Colors.white)),
                                      ),
                                    );
                                  }
                                }
                                setState(() => isResetting = false);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.warning,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: isResetting
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                            : Text('Set Password', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                      ),
                    ],
            );
          },
        );
      },
    );
  }

  void _showReceiptDetail(TransactionEntity tx) {
    final isDark = ref.watch(themeProvider) == ThemeMode.dark;
    final bg = isDark ? AppTheme.bgDark : AppTheme.lightBg;
    final card = isDark ? AppTheme.bgCard : AppTheme.lightCard;
    final textPrimary = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;

    showBlurredDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Receipt image with zoom
              if (tx.receiptImage != null)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 5.0,
                    child: _buildReceiptImage(tx.receiptImage!, card),
                  ),
                ),
              // Details
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(tx.buyerName,
                                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary)),
                          ),
                          StatusChip(status: tx.status),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _detailRow(Icons.account_balance_rounded, 'Bank', tx.bankName, textSecondary, textPrimary),
                      _detailRow(Icons.tag_rounded, 'Reference', tx.referenceCode, textSecondary, textPrimary),
                      _detailRow(Icons.person_rounded, 'Buyer', tx.buyerName, textSecondary, textPrimary),
                      _detailRow(Icons.monetization_on_rounded, 'Amount', AppFormatters.formatETB(tx.amount), textSecondary, textPrimary),
                      if (tx.orderTotal > 0)
                        _detailRow(Icons.receipt_long_rounded, 'Order Total', AppFormatters.formatETB(tx.orderTotal), textSecondary, textPrimary),
                      _detailRow(Icons.calendar_today_rounded, 'Date', AppFormatters.formatDateTime(tx.createdAt), textSecondary, textPrimary),
                      if (tx.riskFlags.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Risk Flags', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.error)),
                              const SizedBox(height: 4),
                              ...tx.riskFlags.map((f) => Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text('• $f', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.error)),
                              )),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Close button
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text('Close', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptImage(String path, Color card) {
    final isUrl = path.startsWith('http://') || path.startsWith('https://');
    if (isUrl) {
      return Image.network(
        path,
        width: double.infinity,
        height: 300,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Container(
          height: 200,
          color: card,
          child: const Center(child: Icon(Icons.broken_image_rounded, size: 48, color: AppTheme.textTertiary)),
        ),
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return Container(
            height: 200,
            color: card,
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        },
      );
    }
    return Image.file(
      File(path),
      width: double.infinity,
      height: 300,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Container(
        height: 200,
        color: card,
        child: const Center(child: Icon(Icons.broken_image_rounded, size: 48, color: AppTheme.textTertiary)),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value, Color textSecondary, Color textPrimary) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.primaryGreen),
          const SizedBox(width: 10),
          SizedBox(width: 90, child: Text(label, style: GoogleFonts.inter(fontSize: 12, color: textSecondary))),
          Expanded(child: Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: textPrimary))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final bg = isDark ? AppTheme.bgDark : AppTheme.lightBg;
    final card = isDark ? AppTheme.bgCard : AppTheme.lightCard;
    final borderColor = isDark ? AppTheme.borderSubtle : AppTheme.lightBorderSubtle;
    final textPrimary = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;
    final textTertiary = isDark ? AppTheme.textTertiary : AppTheme.lightTextTertiary;

    final txsAsync = ref.watch(waiterTransactionsProvider(widget.waiterId));

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: txsAsync.when(
          data: (allTxs) => _buildContent(allTxs, isDark, card, borderColor, textPrimary, textSecondary, textTertiary),
          loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded, size: 48, color: textTertiary),
                const SizedBox(height: 12),
                Text('Failed to load', style: GoogleFonts.inter(color: textSecondary)),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => ref.refresh(waiterTransactionsProvider(widget.waiterId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(List<TransactionEntity> allTxs, bool isDark, Color card,
      Color borderColor, Color textPrimary, Color textSecondary, Color textTertiary) {
    final periodTxs = _filterByPeriod(allTxs, _chartPeriod);
    final chartValues = _chartData(periodTxs, _chartPeriod);

    final periodTotalAmt = periodTxs.fold(0.0, (s, t) => s + t.amount);
    final allTotalAmt = allTxs.fold(0.0, (s, t) => s + t.amount);
    final allCount = allTxs.length;

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(Duration(days: todayStart.weekday - 1));
    final monthStart = todayStart.subtract(const Duration(days: 30));

    final dailyTxs = allTxs.where((tx) => tx.createdAt.isAfter(todayStart)).toList();
    final weeklyTxs = allTxs.where((tx) => tx.createdAt.isAfter(weekStart)).toList();
    final monthlyTxs = allTxs.where((tx) => tx.createdAt.isAfter(monthStart)).toList();

    final dailyTotal = dailyTxs.fold(0.0, (s, t) => s + t.amount);
    final weeklyTotal = weeklyTxs.fold(0.0, (s, t) => s + t.amount);
    final monthlyTotal = monthlyTxs.fold(0.0, (s, t) => s + t.amount);

    final periodTipsAmt = periodTxs.fold(0.0, (s, t) => s + t.tip);
    final dailyTips = dailyTxs.fold(0.0, (s, t) => s + t.tip);
    final weeklyTips = weeklyTxs.fold(0.0, (s, t) => s + t.tip);
    final monthlyTips = monthlyTxs.fold(0.0, (s, t) => s + t.tip);
    final allTipsAmt = allTxs.fold(0.0, (s, t) => s + t.tip);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(waiterTransactionsProvider(widget.waiterId).future),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Icon(Icons.arrow_back_rounded, size: 20, color: textPrimary),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.waiterName, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, color: textPrimary)),
                      Text(widget.waiterEmail, style: GoogleFonts.inter(fontSize: 12, color: textSecondary)),
                    ],
                  ),
                ),
                // PDF export
                GestureDetector(
                  onTap: allTxs.isEmpty ? null : () => _exportPdf(allTxs),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: allTxs.isEmpty ? AppTheme.textTertiary.withOpacity(0.1) : AppTheme.error.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.picture_as_pdf_rounded, color: allTxs.isEmpty ? AppTheme.textTertiary : AppTheme.error, size: 20),
                  ),
                ),
                const SizedBox(width: 8),
                // Reset Password
                GestureDetector(
                  onTap: _showResetPasswordDialog,
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.lock_reset_rounded, color: AppTheme.warning, size: 20),
                  ),
                ),
                const SizedBox(width: 8),
                // Delete
                GestureDetector(
                  onTap: _deleting ? null : _deleteWaiter,
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: _deleting ? AppTheme.textTertiary.withOpacity(0.1) : AppTheme.error.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _deleting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.textTertiary))
                        : const Icon(Icons.delete_outline_rounded, color: AppTheme.error, size: 20),
                  ),
                ),
                const SizedBox(width: 10),
                // Refresh
                GestureDetector(
                  onTap: () => ref.refresh(waiterTransactionsProvider(widget.waiterId)),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.refresh_rounded, color: AppTheme.primaryGreen, size: 20),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 44, height: 44,
                  decoration: const BoxDecoration(gradient: AppTheme.primaryGradient, shape: BoxShape.circle),
                  child: Center(
                    child: Text(
                      widget.waiterName.isNotEmpty ? widget.waiterName[0].toUpperCase() : 'W',
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── KPI Summary ─────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _KpiTile(
                    label: 'Revenue',
                    value: AppFormatters.formatETB(periodTotalAmt),
                    icon: Icons.trending_up_rounded,
                    color: AppTheme.primaryGreen,
                    card: card,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    borderColor: borderColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _KpiTile(
                    label: 'Tips',
                    value: AppFormatters.formatETB(periodTipsAmt),
                    icon: Icons.volunteer_activism_rounded,
                    color: AppTheme.accentGold,
                    card: card,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    borderColor: borderColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _KpiTile(
                    label: 'Scans',
                    value: '${periodTxs.length}',
                    icon: Icons.qr_code_scanner_rounded,
                    color: AppTheme.pending,
                    card: card,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    borderColor: borderColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Period Selector ─────────────────────────────────────────
            _PeriodToggle(
              selected: _chartPeriod,
              periods: const ['Daily', 'Weekly', 'Monthly'],
              onChanged: (p) => setState(() => _chartPeriod = p),
              isDark: isDark,
              borderColor: borderColor,
              card: card,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            const SizedBox(height: 14),

            // ── Chart ───────────────────────────────────────────────────
            _ChartCard(
              title: 'Revenue',
              subtitle: _chartPeriod,
              isDark: isDark,
              card: card,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              borderColor: borderColor,
              child: SizedBox(
                height: 160,
                child: _RevenueBarChart(
                  data: chartValues,
                  isDark: isDark,
                  period: _chartPeriod,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Period Totals Summary ───────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.date_range_rounded, size: 18, color: AppTheme.primaryGreen),
                      const SizedBox(width: 8),
                      Text('Collected', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _PeriodTotalRow(Icons.today_rounded, 'Today', dailyTotal, dailyTips, dailyTxs.length, AppTheme.primaryGreen, textPrimary, textSecondary),
                  const SizedBox(height: 10),
                  _PeriodTotalRow(Icons.date_range_rounded, 'This Week', weeklyTotal, weeklyTips, weeklyTxs.length, AppTheme.pending, textPrimary, textSecondary),
                  const SizedBox(height: 10),
                  _PeriodTotalRow(Icons.calendar_month_rounded, 'Last 30 Days', monthlyTotal, monthlyTips, monthlyTxs.length, AppTheme.accentGold, textPrimary, textSecondary),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── All-Time Banner ─────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: AppTheme.primaryGreen.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calculate_rounded, color: Colors.white, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total Collected', style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withOpacity(0.8))),
                            Text(AppFormatters.formatETB(allTotalAmt), style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('$allCount total scans', style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withOpacity(0.7))),
                          Text('${AppFormatters.formatETB(allTipsAmt)} tips', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.accentGold)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Receipts Section ────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Scanned Receipts',
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary)),
                Text('${allTxs.length} total',
                    style: GoogleFonts.inter(fontSize: 12, color: textSecondary)),
              ],
            ),
            const SizedBox(height: 12),

            if (allTxs.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 48, color: textTertiary),
                    const SizedBox(height: 12),
                    Text('No receipts yet', style: GoogleFonts.inter(fontSize: 14, color: textSecondary)),
                  ],
                ),
              )
            else
              ...allTxs.map((tx) => _ReceiptCard(
                transaction: tx,
                isDark: isDark,
                card: card,
                borderColor: borderColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                textTertiary: textTertiary,
                onTap: () => _showReceiptDetail(tx),
              )),

            const SizedBox(height: 16),
            Center(
              child: Text(
                'Pull down to refresh',
                style: GoogleFonts.inter(fontSize: 11, color: textTertiary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── KPI Tile ──────────────────────────────────────────────────────────────────

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.card,
    required this.textPrimary,
    required this.textSecondary,
    required this.borderColor,
  });

  final String label, value;
  final IconData icon;
  final Color color, card, textPrimary, textSecondary, borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: textPrimary)),
          Text(label, style: GoogleFonts.inter(fontSize: 10, color: textSecondary)),
        ],
      ),
    );
  }
}

// ── Period Toggle ─────────────────────────────────────────────────────────────

class _PeriodToggle extends StatelessWidget {
  const _PeriodToggle({
    required this.selected,
    required this.periods,
    required this.onChanged,
    required this.isDark,
    required this.borderColor,
    required this.card,
    required this.textPrimary,
    required this.textSecondary,
  });

  final String selected;
  final List<String> periods;
  final void Function(String) onChanged;
  final bool isDark;
  final Color borderColor, card, textPrimary, textSecondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: periods
            .map((p) => Expanded(
                  child: GestureDetector(
                    onTap: () => onChanged(p),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        gradient: selected == p ? AppTheme.primaryGradient : null,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        p,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: selected == p ? FontWeight.w700 : FontWeight.w400,
                          color: selected == p ? Colors.white : textSecondary,
                        ),
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

// ── Chart Card ────────────────────────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.isDark,
    required this.card,
    required this.textPrimary,
    required this.textSecondary,
    required this.borderColor,
    required this.child,
  });

  final String title, subtitle;
  final bool isDark;
  final Color card, textPrimary, textSecondary, borderColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(subtitle,
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primaryGreen)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

// ── Revenue Bar Chart ─────────────────────────────────────────────────────────

class _RevenueBarChart extends StatelessWidget {
  const _RevenueBarChart({
    required this.data,
    required this.isDark,
    required this.period,
  });

  final Map<String, double> data;
  final bool isDark;
  final String period;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Center(
        child: Text('No data for this period',
            style: GoogleFonts.inter(fontSize: 12, color: isDark ? AppTheme.textTertiary : AppTheme.lightTextTertiary)),
      );
    }

    final entries = data.entries.toList();
    final maxVal = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final gridColor = isDark ? AppTheme.borderSubtle : AppTheme.lightBorderSubtle;

    return BarChart(
      BarChartData(
        maxY: maxVal * 1.25,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(color: gridColor, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (v, _) {
                if (v.toInt() >= entries.length) return const SizedBox.shrink();
                return Text(
                  entries[v.toInt()].key.length > 3 ? entries[v.toInt()].key.substring(0, 3) : entries[v.toInt()].key,
                  style: GoogleFonts.inter(fontSize: 9, color: isDark ? AppTheme.textTertiary : AppTheme.lightTextTertiary),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (v, _) => Text(
                '${(v / 1000).toStringAsFixed(0)}k',
                style: GoogleFonts.inter(fontSize: 9, color: isDark ? AppTheme.textTertiary : AppTheme.lightTextTertiary),
              ),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(
          entries.length,
          (i) => BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: entries[i].value,
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [AppTheme.primaryGreenDark, AppTheme.primaryGreen],
                ),
                width: period == 'Daily' ? 8 : 16,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, _, rod, __) => BarTooltipItem(
              '${entries[group.x].key}\n${AppFormatters.formatETB(rod.toY)}',
              TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Receipt Card ──────────────────────────────────────────────────────────────

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({
    required this.transaction,
    required this.isDark,
    required this.card,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.onTap,
  });

  final TransactionEntity transaction;
  final bool isDark;
  final Color card, borderColor, textPrimary, textSecondary, textTertiary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  transaction.bankName.isNotEmpty ? transaction.bankName[0] : 'B',
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.primaryGreen),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (transaction.receiptImage != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Icon(Icons.image_rounded, size: 14, color: AppTheme.primaryGreen),
                        ),
                      Expanded(
                        child: Text(transaction.buyerName,
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: Text(transaction.bankName,
                            style: GoogleFonts.inter(fontSize: 11, color: textSecondary),
                            overflow: TextOverflow.ellipsis),
                      ),
                      Text(' · ', style: GoogleFonts.inter(fontSize: 11, color: textTertiary)),
                      Flexible(
                        child: Text(transaction.referenceCode,
                            style: TextStyle(fontSize: 11, color: textTertiary, fontFamily: 'monospace'),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  Text(AppFormatters.formatDateShort(transaction.createdAt),
                      style: GoogleFonts.inter(fontSize: 10, color: textTertiary)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(AppFormatters.formatETB(transaction.amount),
                    style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: textPrimary)),
                if (transaction.tip > 0)
                  Text('+${AppFormatters.formatETB(transaction.tip)} tip',
                      style: GoogleFonts.inter(fontSize: 10, color: AppTheme.accentGold)),
                StatusChip(status: transaction.status),
              ],
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 18, color: textTertiary),
          ],
        ),
      ),
    );
  }
}

// ── Period Total Row ──────────────────────────────────────────────────────────

class _PeriodTotalRow extends StatelessWidget {
  const _PeriodTotalRow(
    this.icon,
    this.label,
    this.total,
    this.tips,
    this.count,
    this.color,
    this.textPrimary,
    this.textSecondary,
  );

  final IconData icon;
  final String label;
  final double total, tips;
  final int count;
  final Color color, textPrimary, textSecondary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: textPrimary)),
              if (tips > 0)
                Text('${AppFormatters.formatETB(tips)} tips', style: GoogleFonts.inter(fontSize: 10, color: AppTheme.accentGold)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(AppFormatters.formatETB(total), style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: textPrimary)),
            Text('$count scans', style: GoogleFonts.inter(fontSize: 10, color: textSecondary)),
          ],
        ),
      ],
    );
  }
}
