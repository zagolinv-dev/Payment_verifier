import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:payment_verifier/core/theme/app_theme.dart';
import 'package:payment_verifier/core/constants/app_constants.dart';

/// Status chip for transaction status badges
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});
  final TransactionStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color, bg) = switch (status) {
      TransactionStatus.verified => ('VERIFIED', AppTheme.success, AppTheme.success.withOpacity(0.12)),
      TransactionStatus.failed => ('FAILED', AppTheme.error, AppTheme.error.withOpacity(0.12)),
      TransactionStatus.pending => ('PENDING', AppTheme.pending, AppTheme.pending.withOpacity(0.12)),
      TransactionStatus.needsReview => ('FAILED', AppTheme.error, AppTheme.error.withOpacity(0.12)),
      TransactionStatus.duplicate => ('DUPLICATE', AppTheme.accentGold, AppTheme.accentGold.withOpacity(0.12)),
      TransactionStatus.fraudSuspected => ('FRAUD', AppTheme.error, AppTheme.error.withOpacity(0.12)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Role badge chip
class RoleBadge extends StatelessWidget {
  const RoleBadge({super.key, required this.role});
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (role) {
      UserRole.admin => ('ADMIN', AppTheme.accentGold),
      UserRole.waitress => ('WAITRESS', AppTheme.primaryGreen),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
