import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:payment_verifier/core/theme/app_theme.dart';
import 'package:payment_verifier/core/utils/formatters.dart';
import 'package:payment_verifier/core/utils/pdf_export.dart';
import 'package:payment_verifier/domain/entities/transaction_entity.dart';
import 'package:payment_verifier/core/constants/app_constants.dart';
import 'package:payment_verifier/presentation/providers/theme_provider.dart';
import 'package:payment_verifier/presentation/widgets/status_chip.dart';
import 'package:payment_verifier/presentation/providers/transaction_provider.dart';

// Provider: transactions for a specific waiter
final waiterTransactionsProvider =
    FutureProvider.family<List<TransactionEntity>, String>((ref, waiterId) async {
  final allTxs = await ref.watch(transactionsProvider.future);
  final filtered = allTxs.where((tx) => tx.verifiedBy == waiterId).toList();
  filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return filtered;
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

    final txsAsync = ref.watch(waiterTransactionsProvider(waiterId));

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: txsAsync.when(
          data: (txs) => _buildContent(context, ref, txs, isDark, card, borderColor, textPrimary, textSecondary, textTertiary),
          loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
          error: (e, _) => Center(child: Text('Failed to load transactions', style: GoogleFonts.inter(color: textSecondary))),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, List<TransactionEntity> txs,
      bool isDark, Color card, Color borderColor, Color textPrimary, Color textSecondary, Color textTertiary) {
    double totalAmount = 0;
    double totalTips = 0;
    int verifiedCount = 0;
    for (final tx in txs) {
      if (tx.status == TransactionStatus.verified) {
        totalAmount += tx.amount;
        totalTips += tx.tip;
        verifiedCount++;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
            // ── Header ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
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
                    onTap: () async {
                      await ReceiptPdfExport.exportWaiterReceipts(
                        transactions: txs,
                        waiterName: waiterName,
                      );
                    },
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.accentGold.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.picture_as_pdf_rounded, color: AppTheme.accentGold, size: 22),
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
            ),
            const SizedBox(height: 20),

            // ── Summary Cards ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(child: _StatCard(label: 'Scans', value: '$verifiedCount', icon: Icons.qr_code_scanner, color: AppTheme.primaryGreen, card: card, borderColor: borderColor, textPrimary: textPrimary, textSecondary: textSecondary)),
                  const SizedBox(width: 10),
                  Expanded(child: _StatCard(label: 'Revenue', value: AppFormatters.formatETBCompact(totalAmount), icon: Icons.trending_up_rounded, color: AppTheme.success, card: card, borderColor: borderColor, textPrimary: textPrimary, textSecondary: textSecondary)),
                  const SizedBox(width: 10),
                  Expanded(child: _StatCard(label: 'Tips', value: AppFormatters.formatETBCompact(totalTips), icon: Icons.volunteer_activism_rounded, color: AppTheme.accentGold, card: card, borderColor: borderColor, textPrimary: textPrimary, textSecondary: textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Total Banner ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: AppTheme.primaryGreen.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 6))],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calculate_rounded, color: Colors.white, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total Collected', style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withOpacity(0.8))),
                          Text(AppFormatters.formatETB(totalAmount + totalTips), style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('incl. tips', style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withOpacity(0.7))),
                        Text(AppFormatters.formatETB(totalTips), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.accentGold)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Transaction List ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('All Scans', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary)),
            ),

            Expanded(
              child: txs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 56, color: textTertiary.withOpacity(0.4)),
                          const SizedBox(height: 12),
                          Text('No scans yet', style: GoogleFonts.outfit(fontSize: 16, color: textSecondary)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                      itemCount: txs.length,
                      itemBuilder: (ctx, i) => _WaiterTxRow(
                        tx: txs[i],
                        card: card,
                        borderColor: borderColor,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        textTertiary: textTertiary,
                      ),
                    ),
            ),
          ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.card,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
  });

  final String label, value;
  final IconData icon;
  final Color color, card, borderColor, textPrimary, textSecondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary)),
          Text(label, style: GoogleFonts.inter(fontSize: 10, color: textSecondary)),
        ],
      ),
    );
  }
}

class _WaiterTxRow extends StatelessWidget {
  const _WaiterTxRow({
    required this.tx,
    required this.card,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
  });

  final TransactionEntity tx;
  final Color card, borderColor, textPrimary, textSecondary, textTertiary;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: AppTheme.primaryGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Center(child: Text(tx.bankName.isNotEmpty ? tx.bankName[0] : 'B', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.primaryGreen))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tx.buyerName, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary)),
                    const SizedBox(height: 2),
                    Text('${tx.bankName} · ${tx.referenceCode}', style: GoogleFonts.inter(fontSize: 11, color: textTertiary), overflow: TextOverflow.ellipsis),
                    Text(AppFormatters.formatDate(tx.createdAt), style: GoogleFonts.inter(fontSize: 10, color: textTertiary)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(AppFormatters.formatETB(tx.amount), style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary)),
                  if (tx.tip > 0)
                    Text('+${AppFormatters.formatETB(tx.tip)} tip', style: GoogleFonts.inter(fontSize: 10, color: AppTheme.accentGold)),
                  const SizedBox(height: 4),
                  StatusChip(status: tx.status),
                ],
              ),
            ],
          ),
          if (tx.receiptImage != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _showReceiptImage(context),
              child: Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                  image: DecorationImage(
                    image: FileImage(File(tx.receiptImage!)),
                    fit: BoxFit.cover,
                  ),
                ),
                alignment: Alignment.bottomRight,
                child: Container(
                  margin: const EdgeInsets.all(6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: card.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('Tap to view receipt', style: GoogleFonts.inter(fontSize: 10, color: AppTheme.primaryGreen)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showReceiptImage(BuildContext context) {
    if (tx.receiptImage == null) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: InteractiveViewer(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(File(tx.receiptImage!), fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
