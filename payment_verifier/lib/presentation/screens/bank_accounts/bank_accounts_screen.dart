import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:payment_verifier/core/constants/app_constants.dart';
import 'package:payment_verifier/core/theme/app_theme.dart';
import 'package:payment_verifier/domain/entities/bank_account_entity.dart';
import 'package:payment_verifier/presentation/providers/bank_account_provider.dart';
import 'package:payment_verifier/presentation/providers/theme_provider.dart';
import 'package:payment_verifier/presentation/widgets/custom_text_field.dart';
import 'package:payment_verifier/presentation/widgets/gradient_button.dart';
import 'package:payment_verifier/presentation/widgets/blur_overlay.dart';

class BankAccountsScreen extends ConsumerStatefulWidget {
  const BankAccountsScreen({super.key});

  @override
  ConsumerState<BankAccountsScreen> createState() => _BankAccountsScreenState();
}

class _BankAccountsScreenState extends ConsumerState<BankAccountsScreen> {
  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(bankAccountsProvider);
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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bank Accounts', style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.w700, color: textPrimary)),
                        const SizedBox(height: 4),
                        Text('Settlement wallets & collection accounts', style: GoogleFonts.inter(fontSize: 13, color: textSecondary)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showAddModal(context),
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: AppTheme.primaryGreen.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                      child: const Icon(Icons.add_rounded, color: AppTheme.textOnPrimary, size: 24),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: RefreshIndicator(
                color: AppTheme.primaryGreen,
                backgroundColor: card,
                onRefresh: () => ref.read(bankAccountNotifierProvider.notifier).reload(),
                child: accountsAsync.when(
                  skipLoadingOnReload: true,
                  data: (accounts) => accounts.isEmpty
                      ? ListView(children: [
                          const SizedBox(height: 80),
                          Center(child: Column(children: [
                            Icon(Icons.account_balance_outlined, size: 60, color: textTertiary.withOpacity(0.4)),
                            const SizedBox(height: 16),
                            Text('No accounts added', style: GoogleFonts.outfit(fontSize: 16, color: textSecondary)),
                            const SizedBox(height: 8),
                            Text('Tap + to add a bank account', style: GoogleFonts.inter(fontSize: 13, color: textTertiary)),
                          ])),
                        ])
                      : ListView.builder(
                          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).padding.bottom + 100),
                          itemCount: accounts.length,
                          itemBuilder: (ctx, i) => _BankAccountCard(
                            account: accounts[i],
                            isDark: isDark,
                            card: card,
                            borderColor: borderColor,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            textTertiary: textTertiary,
                            onToggle: (val) => ref.read(bankAccountNotifierProvider.notifier).toggleActive(accounts[i].id, val),
                            onEdit: () => _showEditModal(context, accounts[i]),
                            onDelete: () => ref.read(bankAccountNotifierProvider.notifier).deleteAccount(accounts[i].id),
                          ),
                        ),
                  loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
                  error: (e, _) => ListView(children: [
                    const SizedBox(height: 80),
                    Center(child: Column(children: [
                      Icon(Icons.cloud_off_rounded, size: 56, color: textTertiary.withOpacity(0.4)),
                      const SizedBox(height: 16),
                      Text('Could not load accounts', style: GoogleFonts.outfit(fontSize: 16, color: textSecondary)),
                      const SizedBox(height: 8),
                      Text('Check your connection and try again', style: GoogleFonts.inter(fontSize: 13, color: textTertiary)),
                      const SizedBox(height: 20),
                      TextButton.icon(
                        onPressed: () => ref.read(bankAccountNotifierProvider.notifier).reload(),
                        icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryGreen),
                        label: Text('Retry', style: GoogleFonts.inter(color: AppTheme.primaryGreen, fontWeight: FontWeight.w600)),
                      ),
                    ])),
                  ]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddModal(BuildContext context) {
    showBlurredBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => _AddBankAccountModal(
          scrollController: scrollController,
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
      ),
    );
  }

  void _showEditModal(BuildContext context, BankAccountEntity account) {
    showBlurredBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => _AddBankAccountModal(
          scrollController: scrollController,
          initial: account,
          onSubmit: (data) async {
            final success = await ref
                .read(bankAccountNotifierProvider.notifier)
                .updateAccount(
                  id: account.id,
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
      ),
    );
  }
}

// ── Bank Account Card ─────────────────────────────────────────────────────────

class _BankAccountCard extends StatelessWidget {
  const _BankAccountCard({
    required this.account,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.isDark,
    required this.card,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
  });

  final BankAccountEntity account;
  final void Function(bool) onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool isDark;
  final Color card, borderColor, textPrimary, textSecondary, textTertiary;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: account.isActive ? AppTheme.primaryGreen.withOpacity(0.2) : borderColor),
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
                    Text(account.holderName, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary)),
                    const SizedBox(height: 2),
                    Text(account.bankName, style: GoogleFonts.inter(fontSize: 12, color: textSecondary)),
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
          Row(
            children: [
              Icon(Icons.credit_card_rounded, size: 15, color: textTertiary),
              const SizedBox(width: 6),
              Text(_maskAccount(account.accountNumber), style: GoogleFonts.inter(fontSize: 13, color: textSecondary, letterSpacing: 1)),
              const Spacer(),
              if (account.phone != null) ...[
                Icon(Icons.phone_outlined, size: 13, color: textTertiary),
                const SizedBox(width: 4),
                Text(account.phone!, style: GoogleFonts.inter(fontSize: 12, color: textSecondary)),
              ],
            ],
          ),
          if (account.notes != null && account.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(account.notes!, style: GoogleFonts.inter(fontSize: 12, color: textTertiary), maxLines: 2, overflow: TextOverflow.ellipsis),
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
                onTap: onEdit,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.edit_outlined,
                      color: AppTheme.primaryGreen, size: 18),
                ),
              ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? AppTheme.bgCard : AppTheme.lightCard;
    final textPrimary = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;

    showBlurredDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Account?',
            style: GoogleFonts.outfit(color: textPrimary)),
        content: Text('This action cannot be undone.',
            style: GoogleFonts.inter(color: textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
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
  const _AddBankAccountModal({
    required this.onSubmit,
    this.initial,
    this.scrollController,
  });
  final BankAccountEntity? initial;
  final ScrollController? scrollController;
  final Future<void> Function(Map<String, String?>) onSubmit;

  @override
  State<_AddBankAccountModal> createState() => _AddBankAccountModalState();
}

class _AddBankAccountModalState extends State<_AddBankAccountModal> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _holderController;
  late final TextEditingController _accountController;
  late final TextEditingController _phoneController;
  late final TextEditingController _notesController;
  String? _selectedBank;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    String? mappedBank;
    if (initial?.bankName != null) {
      final match = BankName.addAccountOptions.firstWhere(
        (b) => b.displayName == initial!.bankName || b.shortName == initial.bankName,
        orElse: () => BankName.addAccountOptions.first,
      );
      mappedBank = match.shortName;
    }
    final isTelebirr = mappedBank == 'Telebirr' || mappedBank == 'CBE Birr';
    _holderController = TextEditingController(text: initial?.holderName ?? '');
    _accountController = TextEditingController(
      text: isTelebirr ? '' : (initial?.accountNumber ?? ''),
    );
    _phoneController = TextEditingController(
      text: initial?.phone?.isNotEmpty == true
          ? initial!.phone!
          : (isTelebirr ? (initial?.accountNumber ?? '') : ''),
    );
    _notesController = TextEditingController(text: initial?.notes ?? '');
    _selectedBank = mappedBank;
  }

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
    final isTelebirr = _selectedBank == 'Telebirr' || _selectedBank == 'CBE Birr';
    final payload = {
      'holderName': _holderController.text.trim(),
      'bankName': _selectedBank!,
      'accountNumber': isTelebirr ? _phoneController.text.trim() : _accountController.text.trim(),
      'phone': _phoneController.text.trim().isNotEmpty
          ? _phoneController.text.trim()
          : null,
      'notes': _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
    };
    await widget.onSubmit(payload);
    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.bgSurface : AppTheme.lightSurface;
    final textPrimary = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;
    final textTertiary = isDark ? AppTheme.textTertiary : AppTheme.lightTextTertiary;
    final inputBg = isDark ? AppTheme.bgInput : AppTheme.lightInput;
    final border = isDark ? AppTheme.borderSubtle : AppTheme.lightBorderSubtle;
    final dropdownBg = isDark ? AppTheme.bgCard : AppTheme.lightCard;

    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + bottom + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        controller: widget.scrollController,
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
                    color: border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                widget.initial != null ? 'Edit Bank Account' : 'Add Bank Account',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bank / Wallet',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: textSecondary)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: inputBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedBank,
                        hint: Text('Select bank',
                            style: GoogleFonts.inter(
                                color: textTertiary, fontSize: 14)),
                        isExpanded: true,
                        dropdownColor: dropdownBg,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded,
                            color: AppTheme.textSecondary),
                        items: BankName.addAccountOptions
                            .map((b) => DropdownMenuItem(
                                  value: b.shortName,
                                  child: Text(b.shortName,
                                      style: GoogleFonts.inter(
                                          color: textPrimary,
                                          fontSize: 14)),
                                ))
                            .toList(),
                        onChanged: (v) {
                          setState(() {
                            _selectedBank = v;
                            if (v == 'Telebirr' || v == 'CBE Birr') {
                              _accountController.clear();
                            }
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: (_selectedBank == 'Telebirr' || _selectedBank == 'CBE Birr') ? 'Account Number (Managed by Phone)' : 'Account Number',
                hint: (_selectedBank == 'Telebirr' || _selectedBank == 'CBE Birr') ? 'N/A (Managed by Phone Number)' : '1234567890',
                controller: _accountController,
                keyboardType: TextInputType.number,
                enabled: _selectedBank != 'Telebirr' && _selectedBank != 'CBE Birr',
                validator: (v) => (_selectedBank == 'Telebirr' || _selectedBank == 'CBE Birr') ? null : (v?.isEmpty == true ? 'Required' : null),
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: (_selectedBank == 'Telebirr' || _selectedBank == 'CBE Birr') ? 'Phone Number (Required)' : 'Phone Number (optional)',
                hint: '+251 9XX XXX XXX',
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                validator: (v) => (_selectedBank == 'Telebirr' || _selectedBank == 'CBE Birr') && (v == null || v.trim().isEmpty) ? 'Required' : null,
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
                label: widget.initial != null ? 'Save Changes' : 'Add Account',
                icon: widget.initial != null ? Icons.save_rounded : Icons.add_rounded,
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