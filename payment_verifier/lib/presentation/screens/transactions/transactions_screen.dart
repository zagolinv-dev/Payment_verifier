import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:payment_verifier/core/constants/app_constants.dart';
import 'package:payment_verifier/core/theme/app_theme.dart';
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

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(transactionFiltersProvider);
    final txAsync = ref.watch(transactionsProvider);
    final notifier = ref.read(transactionFiltersProvider.notifier);

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Transactions',
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Audit trail & payment ledger',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Search Bar ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.inter(
                    fontSize: 14, color: AppTheme.textPrimary),
                onChanged: (v) {
                  notifier.state = notifier.state.copyWith(search: v);
                },
                decoration: InputDecoration(
                  hintText: 'Search by name, code, or bank...',
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: AppTheme.textTertiary, size: 20),
                  suffixIcon: filters.search.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _searchController.clear();
                            notifier.state =
                                notifier.state.copyWith(search: '');
                          },
                          icon: const Icon(Icons.clear_rounded,
                              color: AppTheme.textTertiary, size: 18),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Filter Chips ───────────────────────────────────────────────
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  // Status filters
                  ..._statusFilters.map((f) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _FilterChip(
                          label: f,
                          isSelected: filters.status == f,
                          color: _statusColor(f),
                          onTap: () => notifier.state =
                              notifier.state.copyWith(status: f),
                        ),
                      )),
                  const SizedBox(width: 4),
                  Container(
                    width: 1,
                    height: 24,
                    color: AppTheme.borderSubtle,
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  ),
                  const SizedBox(width: 4),
                  // Bank filters
                  ..._bankFilters.map((f) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _FilterChip(
                          label: f,
                          isSelected: filters.bank == f,
                          color: AppTheme.pending,
                          onTap: () => notifier.state =
                              notifier.state.copyWith(bank: f),
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Transaction List ───────────────────────────────────────────
            Expanded(
              child: RefreshIndicator(
                color: AppTheme.primaryGreen,
                backgroundColor: AppTheme.bgCard,
                onRefresh: () async => ref.invalidate(transactionsProvider),
                child: txAsync.when(
                  data: (txs) => txs.isEmpty
                      ? ListView(
                          children: [
                            SizedBox(height: 80),
                            Center(
                              child: Column(
                                children: [
                                  Icon(Icons.search_off_rounded,
                                      size: 56,
                                      color: AppTheme.textTertiary
                                          .withOpacity(0.4)),
                                  const SizedBox(height: 12),
                                  Text('No transactions found',
                                      style: GoogleFonts.outfit(
                                          fontSize: 16,
                                          color: AppTheme.textSecondary)),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                          itemCount: txs.length,
                          itemBuilder: (ctx, i) =>
                              TransactionListItem(transaction: txs[i]),
                        ),
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.primaryGreen),
                  ),
                  error: (e, _) => Center(
                    child: Text('Error: $e',
                        style: GoogleFonts.inter(
                            color: AppTheme.textSecondary)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _statusFilters = ['All Status', 'VERIFIED', 'FAILED'];
  static const _bankFilters = [
    'All Banks',
    'Commercial Bank of Ethiopia',
    'Telebirr',
    'CBE Birr',
    'Awash Bank',
  ];

  Color _statusColor(String filter) {
    switch (filter) {
      case 'VERIFIED':
        return AppTheme.success;
      case 'FAILED':
        return AppTheme.error;
      default:
        return AppTheme.textSecondary;
    }
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.color,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : AppTheme.bgCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color.withOpacity(0.5) : AppTheme.borderSubtle,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? color : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
