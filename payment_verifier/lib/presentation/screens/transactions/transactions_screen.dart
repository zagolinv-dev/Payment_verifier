import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:payment_verifier/core/theme/app_theme.dart';
import 'package:payment_verifier/core/utils/formatters.dart';
import 'package:payment_verifier/core/utils/pdf_export.dart';
import 'package:payment_verifier/domain/entities/transaction_entity.dart';
import 'package:payment_verifier/presentation/providers/auth_provider.dart';
import 'package:payment_verifier/presentation/providers/user_provider.dart';
import 'package:payment_verifier/presentation/providers/theme_provider.dart';
import 'package:payment_verifier/presentation/providers/transaction_provider.dart';
import 'package:payment_verifier/presentation/widgets/transaction_list_item.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
      initialDateRange: ref.read(transactionFiltersProvider).hasDateRange
          ? DateTimeRange(
              start: ref.read(transactionFiltersProvider).dateRangeStart!,
              end: ref.read(transactionFiltersProvider).dateRangeEnd!,
            )
          : DateTimeRange(
              start: now.subtract(const Duration(days: 30)),
              end: now,
            ),
      builder: (context, child) {
        final isDark = ref.read(themeProvider) == ThemeMode.dark;
        return Theme(
          data: isDark ? ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(primary: AppTheme.primaryGreen, surface: AppTheme.bgCard),
          ) : ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(primary: AppTheme.primaryGreen),
          ),
          child: child!,
        );
      },
    );
    if (range != null && context.mounted) {
      ref.read(transactionFiltersProvider.notifier).state =
          ref.read(transactionFiltersProvider.notifier).state.copyWith(
                dateRangeStart: range.start,
                dateRangeEnd: range.end,
              );
    }
  }

  Future<void> _exportPdf(WidgetRef ref) async {
    final txs = ref.read(transactionsProvider).valueOrNull ?? [];
    if (txs.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No transactions to export.'),
            backgroundColor: AppTheme.primaryGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      return;
    }
    final scannerIds = <String, String>{};
    for (final tx in txs) {
      if (tx.verifiedBy != null) {
        scannerIds[tx.verifiedBy!] = tx.verifiedBy!;
      }
    }
    final users = await ref.read(usersListProvider.future);
    for (final u in users) {
      if (scannerIds.containsKey(u.id)) {
        scannerIds[u.id] = u.fullName ?? u.email;
      }
    }
    await ReceiptPdfExport.exportAllReceipts(
      transactions: txs,
      scannerIdToName: scannerIds,
    );
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(transactionFiltersProvider);
    final txAsync = ref.watch(transactionsProvider);
    final notifier = ref.read(transactionFiltersProvider.notifier);
    final isAdmin = ref.watch(isAdminProvider);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;

    final bg = isDark ? AppTheme.bgDark : AppTheme.lightBg;
    final card = isDark ? AppTheme.bgCard : AppTheme.lightCard;
    final borderColor = isDark ? AppTheme.borderSubtle : AppTheme.lightBorderSubtle;
    final textPrimary = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;
    final textTertiary = isDark ? AppTheme.textTertiary : AppTheme.lightTextTertiary;
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Audit trail & payment summary', style: GoogleFonts.inter(fontSize: 14, color: textSecondary)),
                  ),
                  GestureDetector(
                    onTap: () => _exportPdf(ref),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.picture_as_pdf_rounded, color: AppTheme.primaryGreen, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.inter(fontSize: 14, color: textPrimary),
                onChanged: (v) { notifier.state = notifier.state.copyWith(search: v); },
                decoration: InputDecoration(
                  hintText: 'Search by name, code, or bank...',
                  prefixIcon: Icon(Icons.search_rounded, color: textTertiary, size: 20),
                  suffixIcon: filters.search.isNotEmpty
                      ? IconButton(
                          onPressed: () { _searchController.clear(); notifier.state = notifier.state.copyWith(search: ''); },
                          icon: Icon(Icons.clear_rounded, color: textTertiary, size: 18),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  ..._bankFilters.map((f) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _FilterChip(label: f, isSelected: filters.bank == f, color: AppTheme.pending, isDark: isDark, onTap: () => notifier.state = notifier.state.copyWith(bank: f)),
                      )),
                  const SizedBox(width: 4),
                  Container(width: 1, height: 24, color: borderColor, margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8)),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FilterChip(
                      label: filters.hasDateRange
                          ? '${filters.dateRangeStart!.month}/${filters.dateRangeStart!.day} - ${filters.dateRangeEnd!.month}/${filters.dateRangeEnd!.day}'
                          : 'Date Range',
                      isSelected: filters.hasDateRange,
                      color: AppTheme.success,
                      isDark: isDark,
                      onTap: _pickDateRange,
                    ),
                  ),
                  if (filters.hasDateRange) Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FilterChip(
                      label: 'Clear Dates',
                      isSelected: false,
                      color: AppTheme.error,
                      isDark: isDark,
                      onTap: () => notifier.state = notifier.state.copyWith(clearDates: true),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Amount range row
            if (filters.hasAmountRange)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.monetization_on_outlined, size: 16, color: AppTheme.primaryGreen),
                      const SizedBox(width: 8),
                      Text(
                        'Amount: ${filters.amountMin?.toStringAsFixed(0) ?? '0'} - ${filters.amountMax?.toStringAsFixed(0) ?? '∞'} ETB',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryGreen),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => notifier.state = notifier.state.copyWith(clearAmounts: true),
                        child: Icon(Icons.close_rounded, size: 18, color: AppTheme.primaryGreen),
                      ),
                    ],
                  ),
                ),
              ),

            Expanded(
              child: RefreshIndicator(
                color: AppTheme.primaryGreen,
                backgroundColor: card,
                onRefresh: () async => ref.invalidate(transactionsProvider),
                child: txAsync.when(
                  skipLoadingOnReload: true,
                  data: (txs) => txs.isEmpty
                      ? ListView(children: [
                          const SizedBox(height: 80),
                          Center(child: Column(children: [
                            Icon(Icons.search_off_rounded, size: 56, color: textTertiary.withOpacity(0.4)),
                            const SizedBox(height: 12),
                            Text('No transactions found', style: GoogleFonts.outfit(fontSize: 16, color: textSecondary)),
                          ])),
                        ])
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                          itemCount: txs.length,
                          itemBuilder: (ctx, i) {
                            final tx = txs[i];
                            // Resolve waiter name for admin view
                            String? waiterName;
                            if (isAdmin && tx.verifiedBy != null) {
                              final users = ref.watch(usersListProvider).valueOrNull ?? [];
                              final match = users.where((u) => u.id == tx.verifiedBy).firstOrNull;
                              waiterName = match?.displayName ?? tx.verifiedBy!.substring(0, 8);
                            }
                            final tile = TransactionListItem(
                              transaction: tx,
                              verifiedByName: waiterName,
                              onDelete: isAdmin
                                  ? () => _confirmDeleteTransaction(context, ref, txs[i])
                                  : null,
                            );
                            if (!isAdmin) return tile;
                            return Dismissible(
                              key: ValueKey(tx.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: AppTheme.error.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(Icons.delete_outline_rounded, color: AppTheme.error, size: 22),
                              ),
                              confirmDismiss: (_) async {
                                return await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: card,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    title: Text('Delete transaction?', style: GoogleFonts.outfit(color: textPrimary)),
                                    content: Text('Remove ${tx.referenceCode}?', style: GoogleFonts.inter(color: textSecondary)),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: GoogleFonts.inter(color: textSecondary))),
                                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Delete', style: GoogleFonts.inter(color: AppTheme.error, fontWeight: FontWeight.w600))),
                                    ],
                                  ),
                                );
                              },
                              onDismissed: (_) async {
                                try {
                                  await ref.read(deleteTransactionProvider)(tx.id);
                                  ref.invalidate(transactionsProvider);
                                } catch (_) {}
                              },
                              child: tile,
                            );
                          },
                        ),
                  loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
                  error: (e, _) => Center(child: Text('Error: $e', style: GoogleFonts.inter(color: textSecondary))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteTransaction(
    BuildContext context,
    WidgetRef ref,
    TransactionEntity tx,
  ) async {
    final isDark = ref.read(themeProvider) == ThemeMode.dark;
    final card = isDark ? AppTheme.bgCard : AppTheme.lightCard;
    final textPrimary = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: card,
        title: Text('Delete Transaction?', style: GoogleFonts.outfit(color: textPrimary)),
        content: Text(
          'Remove ${tx.referenceCode} (${AppFormatters.formatETB(tx.amount)})? This cannot be undone.',
          style: GoogleFonts.inter(color: textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            child: Text('Delete', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(transactionRepositoryProvider).deleteTransaction(tx.id);
      ref.invalidate(transactionsProvider);
      ref.invalidate(dashboardMetricsProvider);
      ref.invalidate(recentTransactionsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transaction ${tx.referenceCode} deleted'),
            backgroundColor: AppTheme.primaryGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: $e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  static const _bankFilters = [
    'All Banks',
    'CBE',
    'BOA',
    'Telebirr',
    'Awash',
  ];
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.color,
    required this.isDark,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final unselectedBg = isDark ? AppTheme.bgCard : AppTheme.lightCard;
    final unselectedBorder = isDark ? AppTheme.borderSubtle : AppTheme.lightBorderSubtle;
    final unselectedText = isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : unselectedBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color.withOpacity(0.5) : unselectedBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? color : unselectedText,
          ),
        ),
      ),
    );
  }
}
