import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:payment_verifier/core/theme/app_theme.dart';
import 'package:payment_verifier/core/utils/formatters.dart';
import 'package:payment_verifier/presentation/providers/user_provider.dart';
import 'package:payment_verifier/core/constants/app_constants.dart';
import 'package:payment_verifier/domain/repositories/transaction_repository.dart';
import 'package:payment_verifier/presentation/providers/auth_provider.dart';
import 'package:payment_verifier/presentation/providers/theme_provider.dart';
import 'package:payment_verifier/presentation/providers/transaction_provider.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen>
    with SingleTickerProviderStateMixin {
  String _period = 'Weekly';
  late AnimationController _anim;
  late Animation<double> _progress;

  static const _periods = ['Daily', 'Weekly', 'Monthly', 'Yearly'];

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _progress = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _anim.forward();
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _changePeriod(String p) {
    setState(() => _period = p);
    _anim.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final metricsAsync = ref.watch(dashboardMetricsProvider);
    final isAdmin = ref.watch(isAdminProvider);

    final bg = isDark ? AppTheme.bgDark : AppTheme.lightBg;
    final card = isDark ? AppTheme.bgCard : AppTheme.lightCard;
    final textPrimary = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;
    final borderColor = isDark ? AppTheme.borderSubtle : AppTheme.lightBorderSubtle;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.primaryGreen,
          backgroundColor: card,
          onRefresh: () async => ref.invalidate(dashboardMetricsProvider),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ────────────────────────────────────────────
                Text(
                  'Reports',
                  style: GoogleFonts.outfit(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Performance analytics & insights',
                  style: GoogleFonts.inter(
                      fontSize: 14, color: textSecondary),
                ),
                const SizedBox(height: 20),

                // ── Period Selector ────────────────────────────────────
                _PeriodToggle(
                  selected: _period,
                  periods: _periods,
                  onChanged: _changePeriod,
                  isDark: isDark,
                  borderColor: borderColor,
                  card: card,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
                const SizedBox(height: 20),

                // ── KPI Summary Row ────────────────────────────────────
                metricsAsync.when(
                  data: (m) => _SummaryRow(
                    metrics: m,
                    isDark: isDark,
                    card: card,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    borderColor: borderColor,
                  ),
                  loading: () => const SizedBox(height: 90),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 20),

                // ── Revenue Chart ─────────────────────────────────────
                _ChartCard(
                  title: 'Revenue Trend',
                  subtitle: _period,
                  isDark: isDark,
                  card: card,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  borderColor: borderColor,
                  child: AnimatedBuilder(
                    animation: _progress,
                    builder: (_, __) => _RevenueLineChart(
                      period: _period,
                      progress: _progress.value,
                      isDark: isDark,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Tips Chart ────────────────────────────────────────
                _ChartCard(
                  title: 'Tips Earned',
                  subtitle: _period,
                  isDark: isDark,
                  card: card,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  borderColor: borderColor,
                  child: AnimatedBuilder(
                    animation: _progress,
                    builder: (_, __) => _TipsBarChart(
                      period: _period,
                      progress: _progress.value,
                      isDark: isDark,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Verification Success Rate ──────────────────────────
                _ChartCard(
                  title: 'Verification Rate',
                  subtitle: 'All Time',
                  isDark: isDark,
                  card: card,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  borderColor: borderColor,
                  child: metricsAsync.when(
                    data: (m) => _DonutChart(
                      verified: m.verifiedToday,
                      failed: m.failedToday,
                      isDark: isDark,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                    loading: () => const SizedBox(height: 180),
                    error: (_, __) => const SizedBox(height: 180),
                  ),
                ),

                if (isAdmin) ...[
                  const SizedBox(height: 16),
                  // ── Waiter Performance Table ────────────────────────
                  _WaiterPerformanceCard(
                    isDark: isDark,
                    card: card,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    borderColor: borderColor,
                  ),
                ],
              ],
            ),
          ),
        ),
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
                          fontWeight: selected == p
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: selected == p
                              ? Colors.white
                              : textSecondary,
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

// ── Summary Row ───────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.metrics,
    required this.isDark,
    required this.card,
    required this.textPrimary,
    required this.textSecondary,
    required this.borderColor,
  });

  final DashboardMetrics metrics;
  final bool isDark;
  final Color card, textPrimary, textSecondary, borderColor;

  @override
  Widget build(BuildContext context) {
    final items = [
      _SummaryData(
        label: 'Revenue',
        value: AppFormatters.formatETBCompact(metrics.totalIncome),
        icon: Icons.trending_up_rounded,
        color: AppTheme.primaryGreen,
      ),
      _SummaryData(
        label: 'Tips',
        value: AppFormatters.formatETBCompact(metrics.totalTips),
        icon: Icons.volunteer_activism_rounded,
        color: AppTheme.accentGold,
      ),
      _SummaryData(
        label: 'Verified',
        value: '${metrics.verifiedToday}',
        icon: Icons.check_circle_outline_rounded,
        color: AppTheme.success,
      ),
    ];

    return Row(
      children: items
          .map((item) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _SummaryTile(
                    data: item,
                    card: card,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    borderColor: borderColor,
                  ),
                ),
              ))
          .toList(),
    );
  }
}

class _SummaryData {
  const _SummaryData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label, value;
  final IconData icon;
  final Color color;
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.data,
    required this.card,
    required this.textPrimary,
    required this.textSecondary,
    required this.borderColor,
  });

  final _SummaryData data;
  final Color card, textPrimary, textSecondary, borderColor;

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
          Icon(data.icon, color: data.color, size: 20),
          const SizedBox(height: 8),
          Text(
            data.value,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          Text(
            data.label,
            style: GoogleFonts.inter(fontSize: 11, color: textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── Chart Card Wrapper ────────────────────────────────────────────────────────

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
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  subtitle,
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
          child,
        ],
      ),
    );
  }
}

// ── Revenue Line Chart ────────────────────────────────────────────────────────

class _RevenueLineChart extends StatelessWidget {
  const _RevenueLineChart({
    required this.period,
    required this.progress,
    required this.isDark,
  });

  final String period;
  final double progress;
  final bool isDark;

  List<FlSpot> get _spots {
    // Mock data adjusted per period
    final raw = period == 'Daily'
        ? [0.3, 0.5, 0.4, 0.8, 0.6, 0.9, 0.7, 1.0, 0.85, 0.75]
        : period == 'Monthly'
            ? [0.4, 0.6, 0.55, 0.7, 0.85, 0.9, 0.8, 0.95, 1.0, 0.88, 0.92, 0.87]
            : period == 'Yearly'
                ? [0.3, 0.45, 0.6, 0.5, 0.7, 0.8, 0.75, 0.9, 0.85, 0.95, 1.0, 0.9]
                : [0.45, 0.72, 0.58, 0.90, 0.65, 1.0, 0.35];
    return List.generate(
      raw.length,
      (i) => FlSpot(i.toDouble(), raw[i] * 12000 * progress),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gridColor = isDark
        ? AppTheme.borderSubtle
        : AppTheme.lightBorderSubtle;

    return SizedBox(
      height: 160,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 4000,
            getDrawingHorizontalLine: (_) => FlLine(
              color: gridColor,
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                interval: 4000,
                getTitlesWidget: (v, _) => Text(
                  '${(v / 1000).toStringAsFixed(0)}k',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: isDark
                        ? AppTheme.textTertiary
                        : AppTheme.lightTextTertiary,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (v, _) {
                  final labels = period == 'Daily'
                      ? ['8a','9a','10a','11a','12p','1p','2p','3p','4p','5p']
                      : period == 'Monthly'
                          ? ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec']
                          : period == 'Yearly'
                              ? ['\'18','\'19','\'20','\'21','\'22','\'23','\'24','\'25','\'26','\'27','\'28','\'29']
                              : ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
                  if (v.toInt() >= labels.length) return const SizedBox.shrink();
                  return Text(
                    labels[v.toInt()],
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      color: isDark
                          ? AppTheme.textTertiary
                          : AppTheme.lightTextTertiary,
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: _spots,
              isCurved: true,
              curveSmoothness: 0.35,
              color: AppTheme.primaryGreen,
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.primaryGreen.withOpacity(0.25),
                    AppTheme.primaryGreen.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tips Bar Chart ────────────────────────────────────────────────────────────

class _TipsBarChart extends StatelessWidget {
  const _TipsBarChart({
    required this.period,
    required this.progress,
    required this.isDark,
  });

  final String period;
  final double progress;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final raw = period == 'Daily'
        ? [120.0, 180.0, 90.0, 240.0, 160.0, 300.0, 210.0]
        : period == 'Monthly'
            ? [800.0, 1200.0, 950.0, 1400.0, 1100.0, 1600.0, 1350.0, 1800.0, 1500.0, 2000.0, 1700.0, 2200.0]
            : [600.0, 850.0, 720.0, 1100.0, 980.0, 1400.0, 1200.0];
    final labels = period == 'Daily'
        ? ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
        : period == 'Monthly'
            ? ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D']
            : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final maxVal = raw.reduce(math.max);

    return SizedBox(
      height: 140,
      child: BarChart(
        BarChartData(
          maxY: maxVal * 1.2,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: isDark ? AppTheme.borderSubtle : AppTheme.lightBorderSubtle,
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (v, _) {
                  if (v.toInt() >= labels.length) return const SizedBox.shrink();
                  return Text(
                    labels[v.toInt()],
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      color: isDark ? AppTheme.textTertiary : AppTheme.lightTextTertiary,
                    ),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(
            raw.length,
            (i) => BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: raw[i] * progress,
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [AppTheme.accentGold, AppTheme.accentGold.withOpacity(0.6)],
                  ),
                  width: 16,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                ),
              ],
            ),
          ),
          barTouchData: BarTouchData(enabled: false),
        ),
      ),
    );
  }
}

// ── Donut/Pie Chart ────────────────────────────────────────────────────────────

class _DonutChart extends StatelessWidget {
  const _DonutChart({
    required this.verified,
    required this.failed,
    required this.isDark,
    required this.textPrimary,
    required this.textSecondary,
  });

  final int verified, failed;
  final bool isDark;
  final Color textPrimary, textSecondary;

  @override
  Widget build(BuildContext context) {
    final total = verified + failed;
    final verifiedPct = total == 0 ? 0.0 : (verified / total) * 100;

    return SizedBox(
      height: 180,
      child: Row(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 45,
                sections: [
                  PieChartSectionData(
                    value: verified.toDouble() == 0 ? 0.001 : verified.toDouble(),
                    color: AppTheme.success,
                    radius: 36,
                    showTitle: false,
                  ),
                  PieChartSectionData(
                    value: failed.toDouble() == 0 ? 0.001 : failed.toDouble(),
                    color: AppTheme.error,
                    radius: 30,
                    showTitle: false,
                  ),
                ],
                pieTouchData: PieTouchData(enabled: false),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${verifiedPct.toStringAsFixed(1)}%',
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.success,
                ),
              ),
              Text(
                'Success Rate',
                style: GoogleFonts.inter(fontSize: 12, color: textSecondary),
              ),
              const SizedBox(height: 16),
              _Legend(color: AppTheme.success, label: 'Verified ($verified)', textSecondary: textSecondary),
              const SizedBox(height: 8),
              _Legend(color: AppTheme.error, label: 'Failed ($failed)', textSecondary: textSecondary),
            ],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, required this.textSecondary});
  final Color color, textSecondary;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: textSecondary)),
      ],
    );
  }
}

// ── Waiter Performance Table ──────────────────────────────────────────────────

class _WaiterPerformanceCard extends ConsumerWidget {
  const _WaiterPerformanceCard({
    required this.isDark,
    required this.card,
    required this.textPrimary,
    required this.textSecondary,
    required this.borderColor,
  });

  final bool isDark;
  final Color card, textPrimary, textSecondary, borderColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txs = ref.watch(transactionsProvider).valueOrNull ?? [];
    final allUsers = ref.watch(usersListProvider).valueOrNull ?? [];
    final users = allUsers.where((u) => u.role == UserRole.waitress).toList();

    final waiterStats = users.map((user) {
      final userTxs = txs.where((t) => t.verifiedBy == user.id).toList();
      final verified = userTxs.where((t) => t.status == TransactionStatus.verified).length;
      final total = userTxs.length;
      final tips = userTxs.fold(0.0, (sum, t) => sum + t.tip);
      return _WaiterStat(
        name: user.fullName ?? user.email.split('@').first,
        scans: total,
        tips: tips,
        rate: total == 0 ? 0.0 : verified / total,
      );
    }).toList();

    waiterStats.sort((a, b) => b.scans.compareTo(a.scans));

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
              Text(
                'Waiter Leaderboard',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accentGold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'All Time',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.accentGold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const SizedBox(width: 28),
              Expanded(
                flex: 3,
                child: Text('Waiter',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: textSecondary,
                        letterSpacing: 0.8)),
              ),
              Expanded(
                flex: 2,
                child: Text('Scans',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: textSecondary,
                        letterSpacing: 0.8)),
              ),
              Expanded(
                flex: 2,
                child: Text('Tips',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: textSecondary,
                        letterSpacing: 0.8)),
              ),
              Expanded(
                flex: 2,
                child: Text('Rate',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: textSecondary,
                        letterSpacing: 0.8)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(color: borderColor, thickness: 1),
          ...waiterStats.asMap().entries.map((e) => _WaiterRow(
                rank: e.key + 1,
                data: e.value,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                borderColor: borderColor,
              )),
        ],
      ),
    );
  }
}

class _WaiterStat {
  const _WaiterStat({
    required this.name,
    required this.scans,
    required this.tips,
    required this.rate,
  });
  final String name;
  final int scans;
  final double tips;
  final double rate;
}

class _WaiterRow extends StatelessWidget {
  const _WaiterRow({
    required this.rank,
    required this.data,
    required this.textPrimary,
    required this.textSecondary,
    required this.borderColor,
  });

  final int rank;
  final _WaiterStat data;
  final Color textPrimary, textSecondary, borderColor;

  Color get _rankColor {
    return switch (rank) {
      1 => AppTheme.accentGold,
      2 => const Color(0xFFA0A0A0),
      3 => const Color(0xFFCD7F32),
      _ => textSecondary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final rateColor = data.rate >= 0.95
        ? AppTheme.success
        : data.rate >= 0.85
            ? AppTheme.warning
            : AppTheme.error;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: rank <= 3
                ? Icon(Icons.emoji_events_rounded, size: 16, color: _rankColor)
                : Text(
                    '$rank',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: textSecondary),
                  ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      data.name[0],
                      style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    data.name,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${data.scans}',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: textPrimary),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${data.tips.toStringAsFixed(0)} ETB',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppTheme.accentGold,
                  fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              alignment: Alignment.centerRight,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: rateColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(data.rate * 100).toStringAsFixed(0)}%',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: rateColor),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
