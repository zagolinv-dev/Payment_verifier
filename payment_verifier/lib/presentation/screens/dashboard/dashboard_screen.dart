import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:payment_verifier/core/router/app_router.dart';
import 'package:payment_verifier/core/theme/app_theme.dart';
import 'package:payment_verifier/core/utils/formatters.dart';
import 'package:payment_verifier/core/utils/pdf_export.dart';
import 'package:payment_verifier/presentation/providers/user_provider.dart';
import 'package:payment_verifier/core/constants/app_constants.dart';
import 'package:payment_verifier/domain/entities/transaction_entity.dart';
import 'package:payment_verifier/domain/repositories/transaction_repository.dart';
import 'package:payment_verifier/presentation/providers/auth_provider.dart';
import 'package:payment_verifier/presentation/providers/theme_provider.dart';
import 'package:payment_verifier/presentation/providers/transaction_provider.dart';
import 'package:payment_verifier/presentation/widgets/kpi_card.dart';
import 'package:payment_verifier/presentation/widgets/transaction_list_item.dart';
import 'package:payment_verifier/presentation/widgets/blur_overlay.dart';
import 'package:shimmer/shimmer.dart';

final _hasShownCleanupProvider = StateProvider<bool>((ref) => false);

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final metricsAsync = ref.watch(dashboardMetricsProvider);
    final recentAsync = ref.watch(recentTransactionsProvider);
    final isAdmin = ref.watch(isAdminProvider);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;

    final bg = isDark ? AppTheme.bgDark : AppTheme.lightBg;
    final card = isDark ? AppTheme.bgCard : AppTheme.lightCard;
    final cardElevated = isDark ? AppTheme.bgCardElevated : AppTheme.lightCardElevated;
    final borderColor = isDark ? AppTheme.borderSubtle : AppTheme.lightBorderSubtle;
    final textPrimary = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;
    final textTertiary = isDark ? AppTheme.textTertiary : AppTheme.lightTextTertiary;

    final hasShownCleanup = ref.watch(_hasShownCleanupProvider);
    final allTxsAsync = ref.watch(transactionsProvider);
    if (!hasShownCleanup && isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        final allTxs = ref.read(transactionsProvider).valueOrNull ?? [];
        final oldTxs = allTxs.where((tx) =>
          tx.createdAt.isBefore(DateTime.now().subtract(const Duration(days: 7)))
        ).toList();
        if (oldTxs.isNotEmpty) {
          _showCleanupDialog(context, ref, oldTxs);
          ref.read(_hasShownCleanupProvider.notifier).state = true;
        }
      });
    }

    return Scaffold(
      backgroundColor: bg,
      body: RefreshIndicator(
        color: AppTheme.primaryGreen,
        backgroundColor: card,
        onRefresh: () async {
          ref.invalidate(dashboardMetricsProvider);
          ref.invalidate(recentTransactionsProvider);
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  72,
                  MediaQuery.of(context).padding.top + 12,
                  24,
                  20,
                ),
                decoration: BoxDecoration(
                  gradient: isDark ? AppTheme.bgGradient : AppTheme.lightBgGradient,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hello, ${user?.displayName ?? 'there'}',
                            style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w700, color: textPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text(AppFormatters.formatDate(DateTime.now()), style: GoogleFonts.inter(fontSize: 13, color: textSecondary)),
                        ],
                      ),
                    ),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3), width: 2),
                      ),
                      child: Center(
                        child: Text(
                          user?.displayName.isNotEmpty == true ? user!.displayName[0].toUpperCase() : 'U',
                          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textOnPrimary),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (!isAdmin)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: _WaiterStatsCard(
                    userId: user?.id ?? '',
                    isDark: isDark,
                    card: card,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    borderColor: borderColor,
                  ),
                ),
              ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: metricsAsync.when(
                  data: (metrics) => _KpiGrid(metrics: metrics, card: card, cardElevated: cardElevated),
                  loading: () => _KpiGridShimmer(card: card, cardElevated: cardElevated),
                  error: (e, _) => Center(child: Text('Failed to load metrics', style: GoogleFonts.inter(color: textSecondary))),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: metricsAsync.when(
                  data: (m) => _TodayLedgerCard(metrics: m),
                  loading: () => _ShimmerBlock(height: 90, card: card, cardElevated: cardElevated),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _WeeklyChart(isDark: isDark, card: card, borderColor: borderColor, textPrimary: textPrimary, textTertiary: textTertiary),
              ),
            ),

            if (isAdmin)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: GestureDetector(
                    onTap: () => context.go(AppRoutes.reports),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: AppTheme.primaryGreen.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 6))],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.bar_chart_rounded, color: Colors.white, size: 24),
                          const SizedBox(width: 12),
                          Expanded(child: Text('View Reports & Analytics', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white))),
                          const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Recent Transactions', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary)),
                    ),
                    GestureDetector(
                      onTap: () async {
                        final txs = ref.read(recentTransactionsProvider).valueOrNull ?? [];
                        if (txs.isEmpty) return;
                        final ids = <String, String>{};
                        for (final tx in txs) {
                          if (tx.verifiedBy != null) ids[tx.verifiedBy!] = tx.verifiedBy!;
                        }
                        final users = await ref.read(usersListProvider.future);
                        for (final u in users) {
                          if (ids.containsKey(u.id)) ids[u.id] = u.fullName ?? u.email;
                        }
                        ReceiptPdfExport.exportAllReceipts(transactions: txs, scannerIdToName: ids);
                      },
                      child: Container(
                        width: 36, height: 36,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.picture_as_pdf_rounded, color: AppTheme.primaryGreen, size: 20),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.go(AppRoutes.transactions),
                      child: Text('See all', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.primaryGreen, fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
              sliver: recentAsync.when(
                data: (txs) => txs.isEmpty
                    ? SliverToBoxAdapter(child: _EmptyTransactions(textSecondary: textSecondary, textTertiary: textTertiary))
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => TransactionListItem(transaction: txs[i]),
                          childCount: txs.length,
                        ),
                      ),
                loading: () => SliverToBoxAdapter(
                  child: Column(children: List.generate(3, (_) => _ShimmerBlock(height: 76, margin: 8, card: card, cardElevated: cardElevated))),
                ),
                error: (e, _) => SliverToBoxAdapter(child: Center(child: Text('Failed to load transactions', style: GoogleFonts.inter(color: textSecondary)))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showCleanupDialog(BuildContext context, WidgetRef ref, List<TransactionEntity> oldTxs) async {
  final isDark = ref.read(themeProvider) == ThemeMode.dark;
  final isAdmin = ref.read(isAdminProvider);
  final card = isDark ? AppTheme.bgCard : AppTheme.lightCard;
  final textPrimary = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
  final textSecondary = isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;

  final action = await showBlurredDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: AppTheme.accentGold.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.inventory_2_outlined, color: AppTheme.accentGold, size: 32),
          ),
          const SizedBox(height: 20),
          Text('Receipt Cleanup', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, color: textPrimary)),
          const SizedBox(height: 8),
          Text(
            '${oldTxs.length} receipt${oldTxs.length > 1 ? 's' : ''} older than 7 days.',
            style: GoogleFonts.inter(fontSize: 14, color: textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Export as PDF before cleanup.',
            style: GoogleFonts.inter(fontSize: 13, color: textSecondary),
            textAlign: TextAlign.center,
          ),
          if (!isAdmin) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppTheme.primaryGreen, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The manager will also be notified before deletion.',
                      style: GoogleFonts.inter(fontSize: 12, color: AppTheme.primaryGreen),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, 'dismiss'),
          child: Text('Dismiss', style: GoogleFonts.inter(color: textSecondary, fontWeight: FontWeight.w600)),
        ),
        if (isAdmin)
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, 'export'),
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 18, color: Colors.white),
            label: Text('Export & Clean', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentGold,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          )
        else
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, 'export'),
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 18, color: Colors.white),
            label: Text('Export PDF', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
      ],
    ),
  );

  if (action == 'export' && context.mounted) {
    final scannerIds = <String, String>{};
    for (final tx in oldTxs) {
      if (tx.verifiedBy != null) {
        scannerIds[tx.verifiedBy!] = tx.verifiedBy!;
      }
    }
    final users = ref.read(usersListProvider).valueOrNull ?? [];
    for (final u in users) {
      if (scannerIds.containsKey(u.id)) {
        scannerIds[u.id] = u.fullName ?? u.email;
      }
    }
    await ReceiptPdfExport.exportAllReceipts(
      transactions: oldTxs,
      scannerIdToName: scannerIds,
    );

    if (context.mounted) {
      ref.invalidate(dashboardMetricsProvider);
      ref.invalidate(recentTransactionsProvider);
      final msg = isAdmin
          ? '${oldTxs.length} old receipt${oldTxs.length > 1 ? 's' : ''} exported.'
          : 'PDF exported. Manager will review for deletion.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppTheme.primaryGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }
}

class _ShimmerBlock extends StatelessWidget {
  const _ShimmerBlock({required this.card, required this.cardElevated, this.height = 80, this.margin = 0});
  final Color card, cardElevated;
  final double height, margin;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: card,
      highlightColor: cardElevated,
      child: Container(height: height, margin: EdgeInsets.only(bottom: margin), decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16))),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.metrics, required this.card, required this.cardElevated});
  final DashboardMetrics metrics;
  final Color card, cardElevated;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: KpiCard(label: 'Total Income', value: AppFormatters.formatETBCompact(metrics.totalIncome), icon: Icons.trending_up_rounded, iconColor: AppTheme.primaryGreen)),
            const SizedBox(width: 12),
            Expanded(child: KpiCard(label: 'Total Tips', value: AppFormatters.formatETBCompact(metrics.totalTips), icon: Icons.volunteer_activism_rounded, iconColor: AppTheme.accentGold)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: KpiCard(label: 'Verified Today', value: '${metrics.verifiedToday}', icon: Icons.check_circle_outline_rounded, iconColor: AppTheme.success, subLabel: '${metrics.failedToday} failed')),
            const SizedBox(width: 12),
            Expanded(
              child: KpiCard(
                label: 'Verification Rate',
                value: metrics.verifiedToday + metrics.failedToday == 0 ? '—' : '${((metrics.verifiedToday / (metrics.verifiedToday + metrics.failedToday)) * 100).toStringAsFixed(0)}%',
                icon: Icons.analytics_outlined,
                iconColor: AppTheme.pending,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _KpiGridShimmer extends StatelessWidget {
  const _KpiGridShimmer({required this.card, required this.cardElevated});
  final Color card, cardElevated;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: card,
      highlightColor: cardElevated,
      child: Column(
        children: [
          Row(children: [
            Expanded(child: Container(height: 110, decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(20)))),
            const SizedBox(width: 12),
            Expanded(child: Container(height: 110, decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(20)))),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: Container(height: 110, decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(20)))),
            const SizedBox(width: 12),
            Expanded(child: Container(height: 110, decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(20)))),
          ]),
        ],
      ),
    );
  }
}

class _TodayLedgerCard extends StatelessWidget {
  const _TodayLedgerCard({required this.metrics});
  final DashboardMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppTheme.primaryGreen.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.today_rounded, color: Colors.white, size: 24)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Today's Ledger", style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withOpacity(0.8))),
                const SizedBox(height: 4),
                Text(AppFormatters.formatETB(metrics.todayTotal), style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: Text('${metrics.todayCount} txns', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _EmptyTransactions extends StatelessWidget {
  const _EmptyTransactions({required this.textSecondary, required this.textTertiary});
  final Color textSecondary, textTertiary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined, size: 60, color: textTertiary.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text('No transactions yet', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: textSecondary)),
          const SizedBox(height: 6),
          Text('Verified payments will appear here', style: GoogleFonts.inter(fontSize: 13, color: textTertiary)),
        ],
      ),
    );
  }
}

class _WeeklyChart extends ConsumerStatefulWidget {
  const _WeeklyChart({required this.isDark, required this.card, required this.borderColor, required this.textPrimary, required this.textTertiary});
  final bool isDark;
  final Color card, borderColor, textPrimary, textTertiary;

  @override
  ConsumerState<_WeeklyChart> createState() => _WeeklyChartState();
}

class _WeeklyChartState extends ConsumerState<_WeeklyChart> with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _progress = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);
    Future.delayed(const Duration(milliseconds: 200), () { if (mounted) _anim.forward(); });
  }

  @override
  void dispose() { _anim.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final weeklyAsync = ref.watch(weeklyTotalsProvider);
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final now = DateTime.now();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: widget.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: widget.borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('This Week', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: widget.textPrimary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppTheme.primaryGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Text('Total', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primaryGreen)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          weeklyAsync.when(
            data: (totals) {
              final maxVal = totals.values.reduce((a, b) => a > b ? a : b);
              return AnimatedBuilder(
                animation: _progress,
                builder: (_, __) => SizedBox(
                  height: 100,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: dayNames.asMap().entries.map((e) {
                      final day = e.value;
                      final raw = totals[day] ?? 0;
                      final norm = maxVal > 0 ? raw / maxVal : 0.0;
                      return _BarColumn(
                        data: _BarData(day: day, value: norm),
                        progress: _progress.value,
                        isToday: e.key == now.weekday - 1,
                        textTertiary: widget.textTertiary,
                      );
                    }).toList(),
                  ),
                ),
              );
            },
            loading: () => const SizedBox(height: 100),
            error: (_, __) => SizedBox(
              height: 100,
              child: Center(child: Text('No data', style: GoogleFonts.inter(fontSize: 12, color: widget.textTertiary))),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarData {
  const _BarData({required this.day, required this.value});
  final String day;
  final double value;
}

class _BarColumn extends StatelessWidget {
  const _BarColumn({required this.data, required this.progress, required this.isToday, required this.textTertiary});
  final _BarData data;
  final double progress;
  final bool isToday;
  final Color textTertiary;

  @override
  Widget build(BuildContext context) {
    final barHeight = 80.0 * data.value * progress;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 28,
          height: math.max(barHeight, 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: isToday ? [AppTheme.primaryGreen, AppTheme.accentGold] : [AppTheme.primaryGreen.withOpacity(0.7), AppTheme.primaryGreen.withOpacity(0.3)],
            ),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 6),
        Text(data.day, style: GoogleFonts.inter(fontSize: 10, color: isToday ? AppTheme.primaryGreen : textTertiary, fontWeight: isToday ? FontWeight.w700 : FontWeight.w400)),
      ],
    );
  }
}

// ── Waiter Personal Stats Card ──────────────────────────────────────────────────

class _WaiterStatsCard extends ConsumerWidget {
  const _WaiterStatsCard({
    required this.userId,
    required this.isDark,
    required this.card,
    required this.textPrimary,
    required this.textSecondary,
    required this.borderColor,
  });

  final String userId;
  final bool isDark;
  final Color card, textPrimary, textSecondary, borderColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allTxs = ref.watch(transactionsProvider).valueOrNull ?? [];
    final txs = allTxs.where((t) => t.verifiedBy == userId).toList();
    final total = txs.length;
    final verified = txs.where((t) => t.status == TransactionStatus.verified).length;
    final totalTips = txs.fold(0.0, (s, t) => s + t.tip);
    final totalAmount = txs.fold(0.0, (s, t) => s + t.amount);
    final rate = total == 0 ? 0.0 : verified / total;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryGreen.withOpacity(0.1), AppTheme.primaryGreen.withOpacity(0.03)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline_rounded, color: AppTheme.primaryGreen, size: 18),
              const SizedBox(width: 8),
              Text(
                'Your Performance',
                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.primaryGreen),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _WaiterStatItem(label: 'Receipts', value: '$total', color: AppTheme.primaryGreen),
              _WaiterStatItem(label: 'Tips', value: '${totalTips.toStringAsFixed(0)} ETB', color: AppTheme.accentGold),
              _WaiterStatItem(label: 'Revenue', value: '${totalAmount.toStringAsFixed(0)} ETB', color: AppTheme.success),
              _WaiterStatItem(label: 'Success', value: '${(rate * 100).toStringAsFixed(0)}%', color: rate >= 0.85 ? AppTheme.success : rate >= 0.7 ? AppTheme.warning : AppTheme.error),
            ],
          ),
        ],
      ),
    );
  }
}

class _WaiterStatItem extends StatelessWidget {
  const _WaiterStatItem({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 10, color: color.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }
}
