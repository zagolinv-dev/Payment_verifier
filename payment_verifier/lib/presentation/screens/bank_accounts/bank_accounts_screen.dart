import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:payment_verifier/core/constants/app_constants.dart';
import 'package:payment_verifier/core/theme/app_theme.dart';
import 'package:payment_verifier/domain/entities/bank_account_entity.dart';
import 'package:payment_verifier/presentation/providers/bank_account_provider.dart';
import 'package:payment_verifier/presentation/widgets/custom_text_field.dart';
import 'package:payment_verifier/presentation/widgets/gradient_button.dart';

class BankAccountsScreen extends ConsumerWidget {
  const BankAccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(bankAccountsProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bank Accounts',
                          style: GoogleFonts.outfit(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Settlement wallets & collection accounts',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Add button
                  GestureDetector(
                    onTap: () => _showAddModal(context, ref),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryGreen.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.add_rounded,
                          color: AppTheme.textOnPrimary, size: 24),
                    ),
                  ),
                ],
              ),
            ),

            // List
            Expanded(
              child: RefreshIndicator(
                color: AppTheme.primaryGreen,
                backgroundColor: AppTheme.bgCard,
                onRefresh: () async => ref.invalidate(bankAccountsProvider),
                child: accountsAsync.when(
                  data: (accounts) => accounts.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 80),
                            Center(
                              child: Column(
                                children: [
                                  Icon(Icons.account_balance_outlined,
                                      size: 60,
                                      color: AppTheme.textTertiary
                                          .withOpacity(0.4)),
                                  const SizedBox(height: 16),
                                  Text('No accounts added',
                                      style: GoogleFonts.outfit(
                                          fontSize: 16,
                                          color: AppTheme.textSecondary)),
                                  const SizedBox(height: 8),
                                  Text('Tap + to add a bank account',
                                      style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: AppTheme.textTertiary)),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                          itemCount: accounts.length,
                          itemBuilder: (ctx, i) => _BankAccountCard(
                            account: accounts[i],
                            onToggle: (val) async {
                              await ref
                                  .read(bankAccountNotifierProvider.notifier)
                                  .toggleActive(accounts[i].id, val);
                              ref.invalidate(bankAccountsProvider);
                            },
                            onDelete: () async {
                              await ref
                                  .read(bankAccountNotifierProvider.notifier)
                                  .deleteAccount(accounts[i].id);
                              ref.invalidate(bankAccountsProvider);
                            },
                          ),
                        ),
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.primaryGreen),
                  ),
                  error: (e, _) => Center(
                    child: Text('Error loading accounts',
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

  void _showAddModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddBankAccountModal(
        onSubmit: (data) async {
          final success = await ref
              .read(bankAccountNotifierProvider.notifier)
              .createAccount(
                holderName: data['holderName']!,
                bankName: data['bankName']!,
                accountNumber: data['accountNumber']!,
                phone: data['phone'],
                notes: data['notes'],
              );
          if (success) {
            ref.invalidate(bankAccountsProvider);
          }
        },
      ),
    );
  }
}

// ── Bank Account Card ─────────────────────────────────────────────────────────

class _BankAccountCard extends StatelessWidget {
  const _BankAccountCard({
    required this.account,
    required this.onToggle,
    required this.onDelete,
  });

  final BankAccountEntity account;
  final void Function(bool) onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: account.isActive
              ? AppTheme.primaryGreen.withOpacity(0.2)
              : AppTheme.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Bank initial
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreenDark,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    account.bankName.isNotEmpty ? account.bankName[0] : 'B',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
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
                    Text(
                      account.holderName,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      account.bankName,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Active toggle
              Switch(
                value: account.isActive,
                onChanged: onToggle,
                activeColor: AppTheme.primaryGreen,
                inactiveThumbColor: AppTheme.textTertiary,
                inactiveTrackColor: AppTheme.borderSubtle,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppTheme.borderSubtle, height: 1),
          const SizedBox(height: 12),
          // Account number
          Row(
            children: [
              Icon(Icons.credit_card_rounded,
                  size: 15, color: AppTheme.textTertiary),
              const SizedBox(width: 6),
              Text(
                _maskAccount(account.accountNumber),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              if (account.phone != null) ...[
                Icon(Icons.phone_outlined, size: 13, color: AppTheme.textTertiary),
                const SizedBox(width: 4),
                Text(
                  account.phone!,
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ],
          ),
          if (account.notes != null && account.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              account.notes!,
              style: GoogleFonts.inter(
                  fontSize: 12, color: AppTheme.textTertiary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),
          // Status + delete
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: account.isActive
                      ? AppTheme.success.withOpacity(0.12)
                      : AppTheme.borderSubtle,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  account.isActive ? 'Active' : 'Inactive',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: account.isActive
                        ? AppTheme.success
                        : AppTheme.textTertiary,
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _confirmDelete(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.delete_outline_rounded,
                      color: AppTheme.error, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _maskAccount(String acc) {
    if (acc.length <= 4) return acc;
    return '${'•' * (acc.length - 4)}${acc.substring(acc.length - 4)}';
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: Text('Delete Account?',
            style: GoogleFonts.outfit(color: AppTheme.textPrimary)),
        content: Text('This action cannot be undone.',
            style: GoogleFonts.inter(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onDelete();
            },
            child: Text('Delete',
                style: GoogleFonts.inter(
                    color: AppTheme.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Add Bank Account Modal ────────────────────────────────────────────────────

class _AddBankAccountModal extends StatefulWidget {
  const _AddBankAccountModal({required this.onSubmit});
  final Future<void> Function(Map<String, String?>) onSubmit;

  @override
  State<_AddBankAccountModal> createState() => _AddBankAccountModalState();
}

class _AddBankAccountModalState extends State<_AddBankAccountModal> {
  final _formKey = GlobalKey<FormState>();
  final _holderController = TextEditingController();
  final _accountController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();
  String? _selectedBank;
  bool _isLoading = false;

  @override
  void dispose() {
    _holderController.dispose();
    _accountController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedBank == null) return;
    setState(() => _isLoading = true);
    await widget.onSubmit({
      'holderName': _holderController.text.trim(),
      'bankName': _selectedBank!,
      'accountNumber': _accountController.text.trim(),
      'phone': _phoneController.text.trim().isNotEmpty
          ? _phoneController.text.trim()
          : null,
      'notes': _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
    });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + bottom),
      decoration: const BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.borderMedium,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Add Bank Account',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              AppTextField(
                label: 'Account Holder Name',
                hint: 'Full legal name',
                controller: _holderController,
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              // Bank dropdown
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bank / Wallet',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.bgInput,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedBank,
                        hint: Text('Select bank',
                            style: GoogleFonts.inter(
                                color: AppTheme.textTertiary, fontSize: 14)),
                        isExpanded: true,
                        dropdownColor: AppTheme.bgCard,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded,
                            color: AppTheme.textSecondary),
                        items: BankName.values
                            .map((b) => DropdownMenuItem(
                                  value: b.displayName,
                                  child: Text(b.displayName,
                                      style: GoogleFonts.inter(
                                          color: AppTheme.textPrimary,
                                          fontSize: 14)),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedBank = v),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Account Number',
                hint: '1234567890',
                controller: _accountController,
                keyboardType: TextInputType.number,
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Phone Number (optional)',
                hint: '+251 9XX XXX XXX',
                controller: _phoneController,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Notes (optional)',
                hint: 'Internal notes about this account...',
                controller: _notesController,
                maxLines: 3,
              ),
              const SizedBox(height: 28),
              GradientButton(
                label: 'Add Account',
                icon: Icons.add_rounded,
                isLoading: _isLoading,
                onPressed: _isLoading ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
