import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:payment_verifier/core/theme/app_theme.dart';
import 'package:payment_verifier/core/utils/formatters.dart';
import 'package:payment_verifier/core/constants/app_constants.dart';
import 'package:payment_verifier/presentation/providers/theme_provider.dart';
import 'package:payment_verifier/presentation/providers/transaction_provider.dart';

class _WaiterPeriodMetrics {
  final double amount;
  final double tips;
  final int count;
  const _WaiterPeriodMetrics({this.amount = 0, this.tips = 0, this.count = 0});
  double get total => amount + tips;
}

class _WaiterAggregated {
  final _WaiterPeriodMetrics today;
  final _WaiterPeriodMetrics thisWeek;
  final _WaiterPeriodMetrics thisMonth;
  const _WaiterAggregated({
    required this.today,
    required this.thisWeek,
    required this.thisMonth,
  });
}

final waiterAggregatedProvider =
    FutureProvider.family<_WaiterAggregated, String>((ref, waiterId) async {
  final allTxs = await ref.watch(transactionsProvider.future);

  final waiterTxs = allTxs
      .where((tx) => tx.verifiedBy == waiterId && tx.status == TransactionStatus.verified)
      .toList();

  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final weekStart = todayStart.subtract(Duration(days: todayStart.weekday - 1));
  final monthStart = now.subtract(const Duration(days: 30));

  _WaiterPeriodMetrics calc(DateTime since) {
    double amt = 0, tips = 0;
    int c = 0;
    for (final tx in waiterTxs) {
      if (tx.createdAt.isAfter(since)) {
        amt += tx.amount;
        tips += tx.tip;
        c++;
      }
    }
    return _WaiterPeriodMetrics(amount: amt, tips: tips, count: c);
  }

  return _WaiterAggregated(
    today: calc(todayStart),
    thisWeek: calc(weekStart),
    thisMonth: calc(monthStart),
  );
});

class WaiterDetailScreen extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final bg = isDark ? AppTheme.bgDark : AppTheme.lightBg;
    final card = isDark ? AppTheme.bgCard : AppTheme.lightCard;
    final borderColor = isDark ? AppTheme.borderSubtle : AppTheme.lightBorderSubtle;
    final textPrimary = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;
    final textTertiary = isDark ? AppTheme.textTertiary : AppTheme.lightTextTertiary;

    final aggAsync = ref.watch(waiterAggregatedProvider(waiterId));

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: aggAsync.when(
          data: (agg) => _buildContent(context, ref, agg, isDark, card, borderColor, textPrimary, textSecondary, textTertiary),
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
                  onPressed: () => ref.refresh(waiterAggregatedProvider(waiterId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, _WaiterAggregated agg,
      bool isDark, Color card, Color borderColor, Color textPrimary, Color textSecondary, Color textTertiary) {
    return RefreshIndicator(
      onRefresh: () => ref.refresh(waiterAggregatedProvider(waiterId).future),
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
                      Text(waiterName, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, color: textPrimary)),
                      Text(waiterEmail, style: GoogleFonts.inter(fontSize: 12, color: textSecondary)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => ref.refresh(waiterAggregatedProvider(waiterId)),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.refresh_rounded, color: AppTheme.primaryGreen, size: 20),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 44, height: 44,
                  decoration: const BoxDecoration(gradient: AppTheme.primaryGradient, shape: BoxShape.circle),
                  child: Center(
                    child: Text(
                      waiterName.isNotEmpty ? waiterName[0].toUpperCase() : 'W',
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Today Card ────────────────────────────────────────────────
            _PeriodCard(
              title: 'Today',
              subtitle: _dateLabel(DateTime.now()),
              metrics: agg.today,
              icon: Icons.today_rounded,
              gradientColors: [AppTheme.primaryGreen, const Color(0xFF059669)],
              card: card, borderColor: borderColor, textPrimary: textPrimary, textSecondary: textSecondary,
            ),
            const SizedBox(height: 14),

            // ── This Week Card ────────────────────────────────────────────
            _PeriodCard(
              title: 'This Week',
              subtitle: '${_dateLabel(_weekStart())} – ${_dateLabel(DateTime.now())}',
              metrics: agg.thisWeek,
              icon: Icons.date_range_rounded,
              gradientColors: [const Color(0xFF3B82F6), const Color(0xFF2563EB)],
              card: card, borderColor: borderColor, textPrimary: textPrimary, textSecondary: textSecondary,
            ),
            const SizedBox(height: 14),

            // ── This Month Card ───────────────────────────────────────────
            _PeriodCard(
              title: 'Last 30 Days',
              subtitle: '${_dateLabel(DateTime.now().subtract(const Duration(days: 30)))} – ${_dateLabel(DateTime.now())}',
              metrics: agg.thisMonth,
              icon: Icons.calendar_month_rounded,
              gradientColors: [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)],
              card: card, borderColor: borderColor, textPrimary: textPrimary, textSecondary: textSecondary,
            ),
            const SizedBox(height: 16),

            // ── All-Time Banner ──────────────────────────────────────────
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
                            Text('Total Collected (Last 30 days)', style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withOpacity(0.8))),
                            Text(AppFormatters.formatETB(agg.thisMonth.total), style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${agg.thisMonth.count} scans', style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withOpacity(0.7))),
                          Text('${AppFormatters.formatETB(agg.thisMonth.tips)} tips', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.accentGold)),
                        ],
                      ),
                    ],
                  ),
                  if (agg.thisWeek.count > 0 || agg.today.count > 0) ...[
                    const SizedBox(height: 12),
                    const Divider(color: Colors.white24, height: 1),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _miniStat('Week', AppFormatters.formatETB(agg.thisWeek.amount), agg.thisWeek.count),
                        const SizedBox(width: 16),
                        _miniStat('Today', AppFormatters.formatETB(agg.today.amount), agg.today.count),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),
            Center(
              child: Text(
                'Data refreshes automatically · Last 30 days shown',
                style: GoogleFonts.inter(fontSize: 11, color: textTertiary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, String amount, int count) {
    return Expanded(
      child: Row(
        children: [
          Icon(Icons.circle, size: 6, color: Colors.white.withOpacity(0.5)),
          const SizedBox(width: 6),
          Text('$label: ', style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withOpacity(0.7))),
          Text(amount, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
          if (count > 0)
            Text(' ($count)', style: GoogleFonts.inter(fontSize: 10, color: Colors.white.withOpacity(0.6))),
        ],
      ),
    );
  }

  DateTime _weekStart() {
    final now = DateTime.now();
    final d = DateTime(now.year, now.month, now.day);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  String _dateLabel(DateTime d) {
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.day}';
  }
}

class _PeriodCard extends StatelessWidget {
  final String title, subtitle;
  final _WaiterPeriodMetrics metrics;
  final IconData icon;
  final List<Color> gradientColors;
  final Color card, borderColor, textPrimary, textSecondary;

  const _PeriodCard({
    required this.title,
    required this.subtitle,
    required this.metrics,
    required this.icon,
    required this.gradientColors,
    required this.card,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradientColors),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary)),
                    Text(subtitle, style: GoogleFonts.inter(fontSize: 10, color: textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppFormatters.formatETB(metrics.amount), style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: textPrimary)),
                    Text('Revenue', style: GoogleFonts.inter(fontSize: 11, color: textSecondary)),
                  ],
                ),
              ),
              Container(width: 1, height: 40, color: borderColor),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppFormatters.formatETB(metrics.tips), style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.accentGold)),
                    Text('Tips', style: GoogleFonts.inter(fontSize: 11, color: textSecondary)),
                  ],
                ),
              ),
              Container(width: 1, height: 40, color: borderColor),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${metrics.count}', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.primaryGreen)),
                    Text('Scans', style: GoogleFonts.inter(fontSize: 11, color: textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
