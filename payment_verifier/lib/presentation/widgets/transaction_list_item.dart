import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:payment_verifier/core/theme/app_theme.dart';
import 'package:payment_verifier/core/utils/formatters.dart';
import 'package:payment_verifier/domain/entities/transaction_entity.dart';
import 'package:payment_verifier/presentation/widgets/status_chip.dart';
import 'package:payment_verifier/presentation/widgets/blur_overlay.dart';

class TransactionListItem extends StatelessWidget {
  const TransactionListItem({
    super.key,
    required this.transaction,
    this.onTap,
    this.onDelete,
  });

  final TransactionEntity transaction;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.bgCard : AppTheme.lightCard;
    final border = isDark ? AppTheme.borderSubtle : AppTheme.lightBorderSubtle;
    final textPrimary = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;
    final textTertiary = isDark ? AppTheme.textTertiary : AppTheme.lightTextTertiary;
    final iconBg = isDark ? AppTheme.primaryGreenDark : AppTheme.primaryGreen.withOpacity(0.1);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  transaction.bankName.isNotEmpty ? transaction.bankName[0] : 'B',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryGreen,
                  ),
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
                      if (transaction.receiptImage != null) ...[
                        GestureDetector(
                          onTap: () => _showReceipt(context),
                          child: Container(
                            width: 28, height: 28,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.image_rounded, color: AppTheme.primaryGreen, size: 16),
                          ),
                        ),
                      ],
                      Expanded(
                        child: Text(
                          transaction.buyerName,
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      StatusChip(status: transaction.status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          transaction.bankName,
                          style: GoogleFonts.inter(fontSize: 12, color: textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(' · ', style: GoogleFonts.inter(fontSize: 12, color: textTertiary)),
                      Flexible(
                        child: Text(
                          transaction.referenceCode,
                          style: TextStyle(fontSize: 12, color: textTertiary, fontFamily: 'monospace'),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  AppFormatters.formatETB(transaction.amount),
                  style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: textPrimary),
                ),
                if (transaction.tip > 0)
                  Text(
                    '+${AppFormatters.formatETB(transaction.tip)} tip',
                    style: GoogleFonts.inter(fontSize: 11, color: AppTheme.accentGold),
                  ),
                if (onDelete != null) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: onDelete,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.delete_outline_rounded, color: AppTheme.error, size: 16),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptImage(String path) {
    final isUrl = path.startsWith('http://') || path.startsWith('https://');
    if (isUrl) {
      return Image.network(
        path,
        fit: BoxFit.contain,
        width: double.infinity,
        height: 400,
        errorBuilder: (_, error, __) {
          debugPrint('[TransactionListItem] Image.network error: $error');
          return _brokenImage();
        },
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return Container(
            height: 200,
            color: AppTheme.bgCard,
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        },
      );
    }
    return Image.file(
      File(path),
      fit: BoxFit.contain,
      width: double.infinity,
      height: 400,
      errorBuilder: (_, error, __) {
        debugPrint('[TransactionListItem] Image.file error: $error');
        return _brokenImage();
      },
    );
  }

  Widget _brokenImage() {
    return Container(
      height: 200,
      color: AppTheme.bgCard,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_rounded, color: AppTheme.textTertiary, size: 48),
            const SizedBox(height: 8),
            Text('Receipt image no longer available', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  Future<void> _showReceipt(BuildContext context) async {
    if (transaction.receiptImage == null) return;
    final path = transaction.receiptImage!;

    final isUrl = path.startsWith('http://') || path.startsWith('https://');
    if (!isUrl) {
      final file = File(path);
      if (!await file.exists()) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Receipt image was saved locally and is no longer available.'),
            backgroundColor: AppTheme.error.withOpacity(0.9),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }
    }

    final imageWidget = _buildReceiptImage(path);

    if (!context.mounted) return;
    showBlurredDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: imageWidget,
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('Close', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppTheme.bgDark)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
