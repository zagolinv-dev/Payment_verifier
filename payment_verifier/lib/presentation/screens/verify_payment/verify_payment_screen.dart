import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:payment_verifier/core/constants/app_constants.dart';
import 'package:payment_verifier/core/theme/app_theme.dart';
import 'package:payment_verifier/core/utils/formatters.dart';
import 'package:payment_verifier/presentation/providers/auth_provider.dart';
import 'package:payment_verifier/presentation/providers/transaction_provider.dart';
import 'package:payment_verifier/presentation/widgets/custom_text_field.dart';
import 'package:payment_verifier/presentation/widgets/gradient_button.dart';
import 'dart:io';

class VerifyPaymentScreen extends ConsumerStatefulWidget {
  const VerifyPaymentScreen({super.key});

  @override
  ConsumerState<VerifyPaymentScreen> createState() =>
      _VerifyPaymentScreenState();
}

class _VerifyPaymentScreenState extends ConsumerState<VerifyPaymentScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _resultAnim;
  late final Animation<double> _resultScale;
  late final Animation<double> _resultFade;

  final _refController = TextEditingController();
  final _buyerController = TextEditingController();
  final _amountController = TextEditingController();
  final _tipController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  XFile? _selectedImage;

  void _onAmountChanged() {
    final amt = double.tryParse(_amountController.text) ?? 0.0;
    if (amt > 0) {
      final tip = amt * 0.10;
      final currentTip = double.tryParse(_tipController.text) ?? 0.0;
      if ((tip - currentTip).abs() > 0.001) {
        _tipController.text = tip.toStringAsFixed(2);
        ref.read(verifyProvider.notifier).setTip(tip);
      }
    } else {
      _tipController.clear();
      ref.read(verifyProvider.notifier).setTip(0.0);
    }
  }

  @override
  void initState() {
    super.initState();
    _resultAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _resultScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _resultAnim, curve: Curves.elasticOut),
    );
    _resultFade = CurvedAnimation(parent: _resultAnim, curve: Curves.easeOut);
    _amountController.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _refController.dispose();
    _buyerController.dispose();
    _amountController.dispose();
    _tipController.dispose();
    _resultAnim.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppTheme.primaryGreen),
              title: Text('Take Photo (Camera)', style: GoogleFonts.inter(color: AppTheme.textPrimary)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined, color: AppTheme.accentGold),
              title: Text('Choose from Gallery', style: GoogleFonts.inter(color: AppTheme.textPrimary)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      final file = await picker.pickImage(source: source);
      if (file != null && mounted) {
        setState(() => _selectedImage = file);
      }
    }
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(currentUserProvider);
    await ref.read(verifyProvider.notifier).verify(waiterName: user?.displayName);
    final state = ref.read(verifyProvider);
    if (state.result != null || state.error != null) {
      _resultAnim.forward(from: 0);
    }
  }

  void _reset() {
    ref.read(verifyProvider.notifier).reset();
    _refController.clear();
    _buyerController.clear();
    _amountController.clear();
    _tipController.clear();
    setState(() => _selectedImage = null);
    _resultAnim.reset();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(verifyProvider);
    final notifier = ref.read(verifyProvider.notifier);

    // Show result overlay when we have a result
    if (state.result != null || state.error != null) {
      return Scaffold(
        backgroundColor: AppTheme.bgDark,
        body: SafeArea(
          child: Center(
            child: FadeTransition(
              opacity: _resultFade,
              child: ScaleTransition(
                scale: _resultScale,
                child: _ResultOverlay(
                  success: state.result != null,
                  amount: state.result?.amount ?? 0,
                  tip: state.result?.tip ?? 0,
                  bank: state.selectedBank ?? '',
                  reference: state.referenceCode,
                  error: state.error,
                  onDone: _reset,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  'Verify Payment',
                  style: GoogleFonts.outfit(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Confirm a customer payment via scan or code',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),

                // ── Mode Toggle ────────────────────────────────────────────
                _ModeToggle(
                  mode: state.mode,
                  onChanged: notifier.setMode,
                ),
                const SizedBox(height: 24),

                // ── Scan Mode ──────────────────────────────────────────────
                if (state.mode == VerifyMode.scan) ...[
                  _ImageUploadZone(
                    selectedImage: _selectedImage,
                    onTap: _pickImage,
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Bank Selector ──────────────────────────────────────────
                _SectionLabel(label: 'Bank / Wallet'),
                const SizedBox(height: 8),
                _BankDropdown(
                  value: state.selectedBank,
                  onChanged: notifier.setBank,
                ),
                const SizedBox(height: 20),

                // ── Reference Code ─────────────────────────────────────────
                if (state.mode == VerifyMode.code) ...[
                  AppTextField(
                    label: 'Payment Reference Code',
                    hint: state.selectedBank != null
                        ? PaymentValidators.hintForBank(
                            BankName.values.firstWhere(
                              (b) => b.displayName == state.selectedBank,
                              orElse: () => BankName.cbe,
                            ),
                          )
                        : 'e.g. FT123456789012',
                    controller: _refController,
                    prefixIcon: const Icon(Icons.tag_rounded,
                        color: AppTheme.textTertiary, size: 20),
                    onChanged: notifier.setCode,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Reference is required';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Buyer Name ─────────────────────────────────────────────
                AppTextField(
                  label: 'Customer Name',
                  hint: 'Full name of payer',
                  controller: _buyerController,
                  prefixIcon: const Icon(Icons.person_outline_rounded,
                      color: AppTheme.textTertiary, size: 20),
                  onChanged: notifier.setBuyerName,
                ),
                const SizedBox(height: 20),

                // ── Amount & Tip ───────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: 'Amount (ETB)',
                        hint: '0.00',
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        prefixIcon: const Icon(Icons.attach_money_rounded,
                            color: AppTheme.textTertiary, size: 20),
                        onChanged: (v) =>
                            notifier.setAmount(double.tryParse(v) ?? 0),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          final d = double.tryParse(v);
                          if (d == null || d < 0) return 'Invalid amount';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: AppTextField(
                        label: 'Tip (ETB)',
                        hint: '0.00',
                        controller: _tipController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        prefixIcon: const Icon(Icons.volunteer_activism_rounded,
                            color: AppTheme.textTertiary, size: 20),
                        onChanged: (v) =>
                            notifier.setTip(double.tryParse(v) ?? 0),
                      ),
                    ),
                  ],
                ),
                if (state.amount > 0) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppTheme.bgCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.borderSubtle, width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Calculation Summary',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Order Subtotal',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            Text(
                              AppFormatters.formatETB(state.amount),
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Service Tip (10%)',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            Text(
                              AppFormatters.formatETB(state.tip),
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppTheme.accentGold,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20, color: AppTheme.borderSubtle),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Amount',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              AppFormatters.formatETB(state.amount + state.tip),
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 28),

                // ── Verify Button ──────────────────────────────────────────
                GradientButton(
                  label: 'Verify Payment',
                  icon: Icons.verified_rounded,
                  isLoading: state.isLoading,
                  onPressed: state.isLoading ? null : _verify,
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Sub-Widgets ───────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppTheme.textSecondary,
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.mode, required this.onChanged});
  final VerifyMode mode;
  final void Function(VerifyMode) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        children: [
          _ToggleOption(
            label: 'Scan Receipt',
            icon: Icons.document_scanner_outlined,
            isSelected: mode == VerifyMode.scan,
            onTap: () => onChanged(VerifyMode.scan),
          ),
          _ToggleOption(
            label: 'Enter Code',
            icon: Icons.keyboard_outlined,
            isSelected: mode == VerifyMode.code,
            onTap: () => onChanged(VerifyMode.code),
          ),
        ],
      ),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  const _ToggleOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: isSelected ? AppTheme.primaryGradient : null,
            color: isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? AppTheme.textOnPrimary : AppTheme.textTertiary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? AppTheme.textOnPrimary : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageUploadZone extends StatelessWidget {
  const _ImageUploadZone({this.selectedImage, required this.onTap});
  final XFile? selectedImage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selectedImage != null
                ? AppTheme.primaryGreen
                : AppTheme.borderMedium,
            width: selectedImage != null ? 1.5 : 1,
          ),
        ),
        child: selectedImage != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(19),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(File(selectedImage!.path), fit: BoxFit.cover),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.bgCard.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Tap to change',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.upload_file_rounded,
                      color: AppTheme.primaryGreen,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tap to upload receipt image',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'PNG, JPEG supported',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _BankDropdown extends StatelessWidget {
  const _BankDropdown({this.value, required this.onChanged});
  final String? value;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.bgInput,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(
            'Select bank or wallet',
            style: GoogleFonts.inter(
                color: AppTheme.textTertiary, fontSize: 14),
          ),
          isExpanded: true,
          dropdownColor: AppTheme.bgCard,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: AppTheme.textSecondary),
          items: BankName.values
              .map((b) => DropdownMenuItem(
                    value: b.displayName,
                    child: Text(
                      b.displayName,
                      style: GoogleFonts.inter(
                          color: AppTheme.textPrimary, fontSize: 14),
                    ),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

class _ResultOverlay extends StatelessWidget {
  const _ResultOverlay({
    required this.success,
    required this.amount,
    required this.tip,
    required this.bank,
    required this.reference,
    this.error,
    required this.onDone,
  });

  final bool success;
  final double amount;
  final double tip;
  final String bank;
  final String reference;
  final String? error;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: success
                ? AppTheme.success.withOpacity(0.3)
                : AppTheme.error.withOpacity(0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: (success ? AppTheme.success : AppTheme.error)
                  .withOpacity(0.15),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: (success ? AppTheme.success : AppTheme.error)
                    .withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                success
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                color: success ? AppTheme.success : AppTheme.error,
                size: 52,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              success ? 'Payment Verified!' : 'Verification Failed',
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            if (success) ...[
              Text(
                AppFormatters.formatETB(amount),
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.success,
                ),
              ),
              if (tip > 0)
                Text(
                  '+ ${AppFormatters.formatETB(tip)} tip',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: AppTheme.accentGold,
                  ),
                ),
              const SizedBox(height: 16),
              _InfoRow(label: 'Bank', value: bank),
              const SizedBox(height: 8),
              _InfoRow(label: 'Reference', value: reference),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                error ?? 'Unable to verify this payment',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 28),
            GradientButton(
              label: 'Verify Another',
              icon: Icons.refresh_rounded,
              onPressed: onDone,
              gradient: success ? AppTheme.primaryGradient : LinearGradient(
                colors: [AppTheme.error, AppTheme.error.withOpacity(0.8)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '$label: ',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppTheme.textSecondary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
