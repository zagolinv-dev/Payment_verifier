import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:payment_verifier/core/theme/app_theme.dart';

/// Dashboard KPI metric card — theme-aware
class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.subLabel,
    this.gradient,
    this.iconColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? subLabel;
  final LinearGradient? gradient;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.bgCard : AppTheme.lightCard;
    final border = isDark ? AppTheme.borderSubtle : AppTheme.lightBorderSubtle;
    final textPrimary = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;
    final textTertiary = isDark ? AppTheme.textTertiary : AppTheme.lightTextTertiary;
    final iColor = iconColor ?? AppTheme.primaryGreen;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: gradient != null
          ? BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: border),
            )
          : BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: border),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iColor, size: 20),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: textPrimary,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 12, color: textSecondary),
          ),
          if (subLabel != null) ...[
            const SizedBox(height: 2),
            Text(
              subLabel!,
              style: GoogleFonts.inter(fontSize: 11, color: textTertiary),
            ),
          ],
        ],
      ),
    );
  }
}
