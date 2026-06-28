import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:payment_verifier/core/theme/app_theme.dart';
import 'package:payment_verifier/presentation/providers/theme_provider.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;

    final bg = isDark ? AppTheme.bgDark : AppTheme.lightBg;
    final card = isDark ? AppTheme.bgCard : AppTheme.lightCard;
    final textPrimary = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;
    final borderColor = isDark ? AppTheme.borderSubtle : AppTheme.lightBorderSubtle;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text('About', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          const SizedBox(height: 20),

          // ── App Header ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Center(
                    child: Text('T', style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 16),
                Text("T's Verify", style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 4),
                Text('Ethiopian Payments Simplified', style: GoogleFonts.inter(fontSize: 13, color: Colors.white70)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Version 1.0.0', style: GoogleFonts.inter(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Description ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('About', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary)),
                const SizedBox(height: 10),
                Text(
                  "T's Verify is a payment verification platform built for Ethiopian cafés, restaurants, and service businesses. "
                  "Waiters scan or enter reference codes from supported banks and mobile money services. "
                  "Every verified payment is recorded instantly with amount and transaction details, "
                  "giving managers full visibility into daily revenue.",
                  style: GoogleFonts.inter(fontSize: 13, color: textSecondary, height: 1.6),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Supported Payment Methods ──────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
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
                    Icon(Icons.account_balance_rounded, size: 18, color: AppTheme.primaryGreen),
                    const SizedBox(width: 8),
                    Text('Supported Payment Methods', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary)),
                  ],
                ),
                const SizedBox(height: 16),
                _PaymentMethodRow(
                  icon: Icons.account_balance_rounded,
                  label: 'Commercial Bank of Ethiopia',
                  sublabel: 'CBE',
                  color: AppTheme.primaryGreen,
                ),
                _PaymentMethodRow(
                  icon: Icons.account_balance_rounded,
                  label: 'Bank of Abyssinia',
                  sublabel: 'BOA',
                  color: AppTheme.pending,
                ),
                _PaymentMethodRow(
                  icon: Icons.phone_android_rounded,
                  label: 'Telebirr',
                  sublabel: 'Mobile Money',
                  color: AppTheme.accentGold,
                ),
                _PaymentMethodRow(
                  icon: Icons.account_balance_rounded,
                  label: 'Awash Bank',
                  sublabel: 'Awash',
                  color: AppTheme.success,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Features ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Key Features', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary)),
                const SizedBox(height: 14),
                _FeatureRow(icon: Icons.qr_code_scanner_rounded, text: 'Receipt scanning with OCR', textSecondary: textSecondary),
                _FeatureRow(icon: Icons.verified_rounded, text: 'Real-time payment verification', textSecondary: textSecondary),
                _FeatureRow(icon: Icons.bar_chart_rounded, text: 'Daily revenue & settlement reports', textSecondary: textSecondary),
                _FeatureRow(icon: Icons.people_rounded, text: 'Waiter & team management', textSecondary: textSecondary),
                _FeatureRow(icon: Icons.notifications_rounded, text: 'Instant notifications', textSecondary: textSecondary),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Footer ─────────────────────────────────────────────────
          Center(
            child: Column(
              children: [
                Text("© 2026 T's Verify", style: GoogleFonts.inter(fontSize: 12, color: textSecondary)),
                const SizedBox(height: 4),
                Text('All rights reserved', style: GoogleFonts.inter(fontSize: 11, color: textSecondary)),
              ],
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _PaymentMethodRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;

  const _PaymentMethodRow({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
                const SizedBox(height: 2),
                Text(sublabel, style: GoogleFonts.inter(fontSize: 11, color: color.withValues(alpha: 0.7))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.check_rounded, size: 16, color: color),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color textSecondary;

  const _FeatureRow({
    required this.icon,
    required this.text,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: AppTheme.primaryGreen),
          ),
          const SizedBox(width: 12),
          Text(text, style: GoogleFonts.inter(fontSize: 13, color: textSecondary)),
        ],
      ),
    );
  }
}
