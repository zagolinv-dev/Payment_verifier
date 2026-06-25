import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:payment_verifier/core/constants/app_constants.dart';
import 'package:payment_verifier/core/theme/app_theme.dart';
import 'package:payment_verifier/core/utils/formatters.dart';
import 'package:payment_verifier/presentation/providers/auth_provider.dart';
import 'package:payment_verifier/presentation/providers/theme_provider.dart';
import 'package:payment_verifier/presentation/providers/transaction_provider.dart';
import 'package:payment_verifier/presentation/widgets/custom_text_field.dart';
import 'package:payment_verifier/presentation/widgets/gradient_button.dart';

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

  final _orderTotalController = TextEditingController();
  final _buyerController = TextEditingController();
  final _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  XFile? _selectedImage;

  String _ocrStatus = '';
  bool _isOcrRunning = false;

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
  }

  @override
  void dispose() {
    _orderTotalController.dispose();
    _buyerController.dispose();
    _amountController.dispose();
    _resultAnim.dispose();
    super.dispose();
  }

  Future<void> _processOcr(String imagePath) async {
    setState(() {
      _isOcrRunning = true;
      _ocrStatus = 'Running OCR...';
    });

    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final recognisedText = await recognizer.processImage(inputImage);
      recognizer.close();

      final text = recognisedText.text;
      if (text.isEmpty) {
        setState(() => _ocrStatus = 'No text found in image');
        return;
      }

      final amountMatch = RegExp(r'(?:ETB|Birr|Br)\s*[:\-]?\s*(\d{1,6}(?:\.\d{1,2})?)',
          caseSensitive: false).firstMatch(text);
      if (amountMatch != null && _amountController.text.isEmpty) {
        _amountController.text = amountMatch.group(1)!;
        ref.read(verifyProvider.notifier).setAmount(double.parse(amountMatch.group(1)!));
      }

      final refMatch = RegExp(
        r'(?:TXN|TRX|REF|TRANS|CBE|AW|CBB)\d{6,12}',
        caseSensitive: false,
      ).firstMatch(text);
      if (refMatch != null) {
        ref.read(verifyProvider.notifier).setCode(refMatch.group(0)!);
      }

      final lines = text.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.length > 3 && trimmed.length < 40 &&
            !trimmed.contains(RegExp(r'\d')) &&
            !trimmed.contains(RegExp(r'(?:receipt|payment|transfer|date|time|total|amount|ETB|Birr)',
                caseSensitive: false))) {
          if (_buyerController.text.isEmpty) {
            _buyerController.text = trimmed;
            ref.read(verifyProvider.notifier).setBuyerName(trimmed);
          }
          break;
        }
      }

      setState(() {
        _ocrStatus = 'OCR complete — ${recognisedText.text.length} chars';
        _isOcrRunning = false;
      });
    } catch (e) {
      setState(() {
        _ocrStatus = 'OCR failed: $e';
        _isOcrRunning = false;
      });
    }
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
              leading: const Icon(Icons.camera_alt_outlined,
                  color: AppTheme.primaryGreen),
              title: Text('Take Photo (Camera)',
                  style: GoogleFonts.inter(color: AppTheme.textPrimary)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined,
                  color: AppTheme.accentGold),
              title: Text('Choose from Gallery',
                  style: GoogleFonts.inter(color: AppTheme.textPrimary)),
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
        ref.read(verifyProvider.notifier).setReceiptImage(file.path);
        _processOcr(file.path);
        _runVerificationCheck();
      }
    }
  }

  void _runVerificationCheck() {
    final st = ref.read(verifyProvider);
    if (st.selectedBank != null && st.amount > 0 && _selectedImage != null) {
      ref.read(verifyProvider.notifier).simulateVerification();
    }
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(currentUserProvider);
    await ref.read(verifyProvider.notifier).verify(waiterName: user?.id);
    final st = ref.read(verifyProvider);
    if (st.result != null || st.error != null) {
      _resultAnim.forward(from: 0);
    }
  }

  void _reset() {
    ref.read(verifyProvider.notifier).reset();
    _orderTotalController.clear();
    _buyerController.clear();
    _amountController.clear();
    setState(() => _selectedImage = null);
    _resultAnim.reset();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(verifyProvider);
    final notifier = ref.read(verifyProvider.notifier);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;

    final bg = isDark ? AppTheme.bgDark : AppTheme.lightBg;
    final card = isDark ? AppTheme.bgCard : AppTheme.lightCard;
    final borderColor =
        isDark ? AppTheme.borderSubtle : AppTheme.lightBorderSubtle;
    final textPrimary =
        isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
    final textSecondary =
        isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;

    if (state.result != null || state.error != null) {
      return Scaffold(
        backgroundColor: bg,
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
                  orderTotal: state.orderTotal,
                  bank: state.selectedBank ?? '',
                  reference: state.referenceCode,
                  receiptImage: state.receiptImage,
                  riskScore: state.result?.riskScore ?? 0,
                  riskFlags: state.result?.riskFlags ?? [],
                  error: state.error,
                  onDone: _reset,
                  isDark: isDark,
                  card: card,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  'Scan and verify a customer payment receipt',
                  style: GoogleFonts.inter(fontSize: 14, color: textSecondary),
                ),
                const SizedBox(height: 24),

                Text('Bank / Wallet',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: textSecondary)),
                const SizedBox(height: 8),
                _BankDropdown(
                    value: state.selectedBank,
                    onChanged: (b) {
                      notifier.setBank(b);
                      _runVerificationCheck();
                    },
                    isDark: isDark),
                const SizedBox(height: 20),

                AppTextField(
                  label: 'Order Total (ETB)',
                  hint: 'What the customer must pay for service',
                  controller: _orderTotalController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  prefixIcon: Icon(Icons.receipt_outlined,
                      color: isDark
                          ? AppTheme.textTertiary
                          : AppTheme.lightTextTertiary,
                      size: 20),
                  onChanged: (v) {
                    notifier.setOrderTotal(double.tryParse(v) ?? 0);
                    _runVerificationCheck();
                  },
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    final d = double.tryParse(v);
                    if (d == null || d <= 0) return 'Invalid amount';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                _ImageUploadZone(
                  selectedImage: _selectedImage,
                  onTap: _pickImage,
                  card: card,
                  borderColor: borderColor,
                  textSecondary: textSecondary,
                ),

                if (_isOcrRunning || _ocrStatus.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: (_isOcrRunning ? AppTheme.pending : AppTheme.primaryGreen).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: (_isOcrRunning ? AppTheme.pending : AppTheme.primaryGreen).withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isOcrRunning ? Icons.hourglass_top_rounded : Icons.document_scanner_rounded,
                          size: 16,
                          color: _isOcrRunning ? AppTheme.pending : AppTheme.primaryGreen,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _ocrStatus,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: _isOcrRunning ? AppTheme.pending : AppTheme.primaryGreen,
                            ),
                          ),
                        ),
                        if (_isOcrRunning)
                          SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.pending),
                          ),
                      ],
                    ),
                  ),
                ],

                if (state.verification != null && !state.isVerifying) ...[
                  const SizedBox(height: 20),
                  _VerificationChecks(
                    verification: state.verification!,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    card: card,
                    borderColor: borderColor,
                  ),
                ],

                const SizedBox(height: 20),
                AppTextField(
                  label: 'Customer Name',
                  hint: 'Full name of payer',
                  controller: _buyerController,
                  prefixIcon: Icon(Icons.person_outline_rounded,
                      color: isDark
                          ? AppTheme.textTertiary
                          : AppTheme.lightTextTertiary,
                      size: 20),
                  onChanged: notifier.setBuyerName,
                ),
                const SizedBox(height: 20),

                AppTextField(
                  label: 'Amount Paid (ETB)',
                  hint: '0.00',
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  prefixIcon: Icon(Icons.attach_money_rounded,
                      color: isDark
                          ? AppTheme.textTertiary
                          : AppTheme.lightTextTertiary,
                      size: 20),
                  onChanged: (v) {
                    notifier.setAmount(double.tryParse(v) ?? 0);
                    _runVerificationCheck();
                  },
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    final d = double.tryParse(v);
                    if (d == null || d < 0) return 'Invalid amount';
                    return null;
                  },
                ),

                if (state.orderTotal > 0 &&
                    state.amount >= state.orderTotal) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGold.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppTheme.accentGold.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.volunteer_activism_rounded,
                            color: AppTheme.accentGold, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Tip: ${AppFormatters.formatETB(state.tip)} (${AppFormatters.formatETB(state.amount)} paid - ${AppFormatters.formatETB(state.orderTotal)} order)',
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppTheme.accentGold,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 28),

                GradientButton(
                  label: 'Verify Payment',
                  icon: Icons.verified_rounded,
                  isLoading: state.isLoading,
                  onPressed: state.isLoading || !state.canVerify ? null : _verify,
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

class _ImageUploadZone extends StatelessWidget {
  const _ImageUploadZone(
      {this.selectedImage,
      required this.onTap,
      required this.card,
      required this.borderColor,
      required this.textSecondary});
  final XFile? selectedImage;
  final VoidCallback onTap;
  final Color card, borderColor, textSecondary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selectedImage != null
                  ? AppTheme.primaryGreen
                  : borderColor,
              width: selectedImage != null ? 1.5 : 1),
        ),
        child: selectedImage != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(19),
                child: Stack(fit: StackFit.expand, children: [
                  Image.file(File(selectedImage!.path), fit: BoxFit.cover),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                          color: card.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text('Tap to change',
                          style: GoogleFonts.inter(
                              fontSize: 11, color: AppTheme.primaryGreen)),
                    ),
                  ),
                ]),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16)),
                      child: const Icon(Icons.upload_file_rounded,
                          color: AppTheme.primaryGreen, size: 28)),
                  const SizedBox(height: 12),
                  Text('Tap to scan receipt image',
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: textSecondary)),
                  const SizedBox(height: 4),
                  Text('PNG, JPEG supported',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppTheme.textTertiary)),
                ],
              ),
      ),
    );
  }
}

class _VerificationChecks extends StatelessWidget {
  const _VerificationChecks({
    required this.verification,
    required this.textPrimary,
    required this.textSecondary,
    required this.card,
    required this.borderColor,
  });

  final ReceiptVerification verification;
  final Color textPrimary, textSecondary, card, borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.fact_check_rounded,
                  color: verification.allPassed
                      ? AppTheme.success
                      : AppTheme.pending,
                  size: 18),
              const SizedBox(width: 8),
              Text('Receipt Verification',
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textPrimary)),
              const Spacer(),
              Text('${verification.passedCount}/4',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: verification.allPassed
                          ? AppTheme.success
                          : AppTheme.pending)),
            ],
          ),
          const SizedBox(height: 12),
          _CheckItem(
            label: 'Owner: ${verification.ownerName}',
            passed: verification.ownerNameMatch,
            textSecondary: textSecondary,
          ),
          const SizedBox(height: 6),
          _CheckItem(
            label: 'Payment amount valid',
            passed: verification.amountValid,
            textSecondary: textSecondary,
          ),
          const SizedBox(height: 6),
          _CheckItem(
            label: 'Reference code format',
            passed: verification.referenceFormatValid,
            textSecondary: textSecondary,
          ),
          const SizedBox(height: 6),
          _CheckItem(
            label: 'Receipt image integrity',
            passed: verification.imageIntegrity,
            textSecondary: textSecondary,
          ),
        ],
      ),
    );
  }
}

class _CheckItem extends StatelessWidget {
  const _CheckItem({
    required this.label,
    required this.passed,
    required this.textSecondary,
  });
  final String label;
  final bool passed;
  final Color textSecondary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          passed ? Icons.check_circle_rounded : Icons.hourglass_empty_rounded,
          color: passed ? AppTheme.success : AppTheme.pending,
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: passed ? AppTheme.success : textSecondary,
          ),
        ),
      ],
    );
  }
}

class _BankDropdown extends StatelessWidget {
  const _BankDropdown(
      {this.value, required this.onChanged, required this.isDark});
  final String? value;
  final void Function(String) onChanged;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final inputBg = isDark ? AppTheme.bgInput : AppTheme.lightInput;
    final borderColor =
        isDark ? AppTheme.borderSubtle : AppTheme.lightBorderSubtle;
    final hintColor =
        isDark ? AppTheme.textTertiary : AppTheme.lightTextTertiary;
    final iconColor =
        isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;
    final dropdownBg = isDark ? AppTheme.bgCard : AppTheme.lightCard;
    final textColor =
        isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
          color: inputBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text('Select bank or wallet',
              style: GoogleFonts.inter(color: hintColor, fontSize: 14)),
          isExpanded: true,
          dropdownColor: dropdownBg,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: iconColor),
          items: BankName.values
              .map((b) => DropdownMenuItem(
                  value: b.displayName,
                  child: Text(b.displayName,
                      style:
                          GoogleFonts.inter(color: textColor, fontSize: 14))))
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
    required this.orderTotal,
    required this.bank,
    required this.reference,
    this.receiptImage,
    this.riskScore = 0.0,
    this.riskFlags = const [],
    this.error,
    required this.onDone,
    required this.isDark,
    required this.card,
    required this.textPrimary,
    required this.textSecondary,
  });

  final bool success, isDark;
  final double amount, tip, orderTotal;
  final String bank, reference;
  final String? receiptImage;
  final double riskScore;
  final List<String> riskFlags;
  final String? error;
  final VoidCallback onDone;
  final Color card, textPrimary, textSecondary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
              color: (success ? AppTheme.success : AppTheme.error)
                  .withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
                color: (success ? AppTheme.success : AppTheme.error)
                    .withOpacity(0.15),
                blurRadius: 40,
                offset: const Offset(0, 16))
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                  color: (success ? AppTheme.success : AppTheme.error)
                      .withOpacity(0.12),
                  shape: BoxShape.circle),
              child: Icon(
                  success
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  color: success ? AppTheme.success : AppTheme.error,
                  size: 52),
            ),
            const SizedBox(height: 24),
            Text(
                success
                    ? 'Payment Verified!'
                    : 'Verification Failed',
                style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: textPrimary)),
            const SizedBox(height: 8),
            if (success) ...[
              Text(AppFormatters.formatETB(amount),
                  style: GoogleFonts.outfit(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.success)),
              if (orderTotal > 0)
                Text('Order: ${AppFormatters.formatETB(orderTotal)}',
                    style: GoogleFonts.inter(
                        fontSize: 14, color: textSecondary)),
              if (tip > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                      '+ ${AppFormatters.formatETB(tip)} tip',
                      style: GoogleFonts.inter(
                          fontSize: 16, color: AppTheme.accentGold)),
                ),
              const SizedBox(height: 16),
              _InfoRow(
                  label: 'Bank',
                  value: bank,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary),
              const SizedBox(height: 8),
              _InfoRow(
                  label: 'Reference',
                  value: reference,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary),
              if (receiptImage != null) ...[
                const SizedBox(height: 8),
                _InfoRow(
                    label: 'Receipt',
                    value: 'Attached',
                    textPrimary: textPrimary,
                    textSecondary: textSecondary),
              ],
              if (riskScore > 0) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      riskScore >= 0.7 ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
                      size: 14,
                      color: riskScore >= 0.7 ? AppTheme.error : AppTheme.warning,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Risk Score: ${(riskScore * 100).toStringAsFixed(0)}%',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: riskScore >= 0.7 ? AppTheme.error : AppTheme.warning,
                      ),
                    ),
                  ],
                ),
                if (riskFlags.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  ...riskFlags.take(2).map((f) => Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      f,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 10, color: textSecondary),
                    ),
                  )),
                ],
              ],
            ] else ...[
              const SizedBox(height: 8),
              Text(error ?? 'Unable to verify this payment',
                  style: GoogleFonts.inter(
                      fontSize: 14, color: textSecondary),
                  textAlign: TextAlign.center),
            ],
            const SizedBox(height: 28),
            GradientButton(
              label: 'Verify Another',
              icon: Icons.refresh_rounded,
              onPressed: onDone,
              gradient: success
                  ? AppTheme.primaryGradient
                  : LinearGradient(colors: [
                      AppTheme.error,
                      AppTheme.error.withOpacity(0.8)
                    ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(
      {required this.label,
      required this.value,
      required this.textPrimary,
      required this.textSecondary});
  final String label, value;
  final Color textPrimary, textSecondary;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('$label: ',
            style: GoogleFonts.inter(
                fontSize: 13, color: textSecondary)),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textPrimary)),
      ],
    );
  }
}
