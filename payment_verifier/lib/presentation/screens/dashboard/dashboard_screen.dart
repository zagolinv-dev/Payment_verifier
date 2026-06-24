import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:payment_verifier/core/router/app_router.dart';
import 'package:payment_verifier/core/theme/app_theme.dart';
import 'package:payment_verifier/core/utils/formatters.dart';
import 'package:payment_verifier/domain/repositories/transaction_repository.dart';
import 'package:payment_verifier/presentation/providers/auth_provider.dart';
import 'package:payment_verifier/presentation/providers/transaction_provider.dart';
import 'package:payment_verifier/presentation/widgets/kpi_card.dart';
import 'package:payment_verifier/presentation/widgets/transaction_list_item.dart';
import 'package:shimmer/shimmer.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final metricsAsync = ref.watch(dashboardMetricsProvider);
    final recentAsync = ref.watch(recentTransactionsProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: RefreshIndicator(
        color: AppTheme.primaryGreen,
        backgroundColor: AppTheme.bgCard,
        onRefresh: () async {
          ref.invalidate(dashboardMetricsProvider);
          ref.invalidate(recentTransactionsProvider);
        },
        child: CustomScrollView(
          slivers: [
            // ── App Bar ────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  24,
                  MediaQuery.of(context).padding.top + 16,
                  24,
                  24,
                ),
                decoration: const BoxDecoration(
                  gradient: AppTheme.bgGradient,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hello, ${user?.displayName ?? 'there'}',
                            style: GoogleFonts.outfit(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppFormatters.formatDate(DateTime.now()),
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Avatar
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.primaryGreen.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          user?.displayName.isNotEmpty == true
                              ? user!.displayName[0].toUpperCase()
                              : 'U',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textOnPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── KPI Cards ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: metricsAsync.when(
                  data: (metrics) => _KpiGrid(metrics: metrics),
                  loading: () => _KpiGridShimmer(),
                  error: (e, _) => Center(
                    child: Text('Failed to load metrics',
                        style:
                            GoogleFonts.inter(color: AppTheme.textSecondary)),
                  ),
                ),
              ),
            ),

            // ── Today's Ledger ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: metricsAsync.when(
                  data: (m) => _TodayLedgerCard(metrics: m),
                  loading: () => _shimmerBlock(height: 90),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),
            ),

            // ── Weekly Analytics Chart ─────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _WeeklyChart(),
              ),
            ),

            // ── Recent Transactions ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Transactions',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.go(AppRoutes.transactions),
                      child: Text(
                        'See all',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppTheme.primaryGreen,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              sliver: recentAsync.when(
                data: (txs) => txs.isEmpty
                    ? SliverToBoxAdapter(child: _EmptyTransactions())
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => TransactionListItem(transaction: txs[i]),
                          childCount: txs.length,
                        ),
                      ),
                loading: () => SliverToBoxAdapter(
                  child: Column(
                    children: List.generate(
                        3, (_) => _shimmerBlock(height: 76, margin: 8)),
                  ),
                ),
                error: (e, _) => SliverToBoxAdapter(
                  child: Center(
                    child: Text('Failed to load transactions',
                        style:
                            GoogleFonts.inter(color: AppTheme.textSecondary)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shimmerBlock({double height = 80, double margin = 0}) {
    return Shimmer.fromColors(
      baseColor: AppTheme.bgCard,
      highlightColor: AppTheme.bgCardElevated,
      child: Container(
        height: height,
        margin: EdgeInsets.only(bottom: margin),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.metrics});
  final DashboardMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: KpiCard(
                label: 'Total Income',
                value: AppFormatters.formatETBCompact(metrics.totalIncome),
                icon: Icons.trending_up_rounded,
                iconColor: AppTheme.primaryGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: KpiCard(
                label: 'Total Tips',
                value: AppFormatters.formatETBCompact(metrics.totalTips),
                icon: Icons.volunteer_activism_rounded,
                iconColor: AppTheme.accentGold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: KpiCard(
                label: 'Verified Today',
                value: '${metrics.verifiedToday}',
                icon: Icons.check_circle_outline_rounded,
                iconColor: AppTheme.success,
                subLabel: '${metrics.failedToday} failed',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: KpiCard(
                label: 'Verification Rate',
                value: metrics.verifiedToday + metrics.failedToday == 0
                    ? '—'
                    : '${((metrics.verifiedToday / (metrics.verifiedToday + metrics.failedToday)) * 100).toStringAsFixed(0)}%',
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
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.bgCard,
      highlightColor: AppTheme.bgCardElevated,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Container(height: 110, decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(20)))),
              const SizedBox(width: 12),
              Expanded(child: Container(height: 110, decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(20)))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Container(height: 110, decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(20)))),
              const SizedBox(width: 12),
              Expanded(child: Container(height: 110, decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(20)))),
            ],
          ),
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
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.today_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Today's Ledger",
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppFormatters.formatETB(metrics.todayTotal),
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${metrics.todayCount} txns',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyTransactions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 60,
            color: AppTheme.textTertiary.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No transactions yet',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Verified payments will appear here',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Weekly Analytics Bar Chart ─────────────────────────────────────────────────

class _WeeklyChart extends StatefulWidget {
  @override
  State<_WeeklyChart> createState() => _WeeklyChartState();
}

class _WeeklyChartState extends State<_WeeklyChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _progress;

  // Mock weekly data (Mon → Sun)
  final List<_BarData> _bars = const [
    _BarData(day: 'Mon', value: 0.45),
    _BarData(day: 'Tue', value: 0.72),
    _BarData(day: 'Wed', value: 0.58),
    _BarData(day: 'Thu', value: 0.90),
    _BarData(day: 'Fri', value: 0.65),
    _BarData(day: 'Sat', value: 1.0),
    _BarData(day: 'Sun', value: 0.35),
  ];

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _progress = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _anim.forward();
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'This Week',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Volume',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          AnimatedBuilder(
            animation: _progress,
            builder: (_, __) => SizedBox(
              height: 100,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _bars
                    .map(
                      (b) => _BarColumn(
                        data: b,
                        progress: _progress.value,
                        isToday: b.day == 'Sat',
                      ),
                    )
                    .toList(),
              ),
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
  const _BarColumn({
    required this.data,
    required this.progress,
    required this.isToday,
  });

  final _BarData data;
  final double progress;
  final bool isToday;

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
              colors: isToday
                  ? [AppTheme.primaryGreen, AppTheme.accentGold]
                  : [
                      AppTheme.primaryGreen.withOpacity(0.7),
                      AppTheme.primaryGreen.withOpacity(0.3),
                    ],
            ),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          data.day,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: isToday ? AppTheme.primaryGreen : AppTheme.textTertiary,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
