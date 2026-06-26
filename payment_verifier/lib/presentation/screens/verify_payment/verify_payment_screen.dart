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
import 'package:payment_verifier/domain/entities/bank_account_entity.dart';
import 'package:payment_verifier/presentation/providers/bank_account_provider.dart';
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
      debugPrint('[OCR] raw text (${text.length} chars): ${text.length > 500 ? "${text.substring(0, 500)}..." : text}');
      if (text.isEmpty) {
        setState(() => _ocrStatus = 'No text found in image');
        return;
      }

      final amountMatch = RegExp(r'(?:ETB|Birr|Br)\s*[:\-]?\s*(\d{1,6}(?:\.\d{1,2})?)',
          caseSensitive: false).firstMatch(text);
      if (amountMatch != null && _amountController.text.isEmpty) {
        debugPrint('[OCR] found amount: ${amountMatch.group(1)}');
        _amountController.text = amountMatch.group(1)!;
        ref.read(verifyProvider.notifier).setAmount(double.parse(amountMatch.group(1)!));
      } else {
        debugPrint('[OCR] amount not found or already set');
      }

      final refMatch = RegExp(
        r'(?:TXN|TRX|REF|TRANS|CBE|AW|CBB)\d{6,12}',
        caseSensitive: false,
      ).firstMatch(text);
      if (refMatch != null) {
        debugPrint('[OCR] found ref: ${refMatch.group(0)}');
        ref.read(verifyProvider.notifier).setCode(refMatch.group(0)!);
      } else {
        debugPrint('[OCR] ref not found');
      }

      final accountMatch = RegExp(
        r'(?:Account|A/C|Acct)[\s#:]*(\*{1,6}\s*\d{3,6})',
        caseSensitive: false,
      ).firstMatch(text);
      if (accountMatch != null) {
        debugPrint('[OCR] found account: ${accountMatch.group(1)}');
        ref.read(verifyProvider.notifier).setReceiverAccount(accountMatch.group(1)!);
      } else {
        debugPrint('[OCR] account not found');
      }

      final dateMatch = RegExp(
        r'(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})[\s,]*(\d{1,2}:\d{2}(?::\d{2})?\s*(?:AM|PM)?)',
        caseSensitive: false,
      ).firstMatch(text);
      if (dateMatch != null) {
        debugPrint('[OCR] found date: ${dateMatch.group(0)}');
        ref.read(verifyProvider.notifier).setTransactionDate(dateMatch.group(0)!);
      } else {
        debugPrint('[OCR] date not found');
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

      final bankName = _detectBankFromText(text);
      if (bankName != null) {
        debugPrint('[OCR] detected bank: $bankName');
        ref.read(verifyProvider.notifier).setBank(bankName);
      } else {
        debugPrint('[OCR] bank not detected in receipt text');
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
    debugPrint('[Verify] runLiveCheck: bank="${st.selectedBank}" amount=${st.amount} ref="${st.referenceCode}" orderTotal=${st.orderTotal}');
    if (st.selectedBank != null && st.amount > 0 && _selectedImage != null) {
      ref.read(verifyProvider.notifier).runLiveCheck();
    }
  }

  String? _detectBankFromText(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('commercial bank of ethiopia') || lower.contains(RegExp(r'\bcbe\b', caseSensitive: false))) {
      return BankName.cbe.displayName;
    }
    if (lower.contains('cbe birr')) {
      return BankName.cbeBirr.displayName;
    }
    if (lower.contains('telebirr')) {
      return BankName.telebirr.displayName;
    }
    if (lower.contains('awash')) {
      return BankName.awash.displayName;
    }
    return null;
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
    final bankAccountsAsync = ref.watch(bankAccountsProvider);
    debugPrint('[Verify] BUILD: bank="${state.selectedBank}" ref="${state.referenceCode}" amount=${state.amount} receiver="${state.receiverAccount}" date="${state.transactionDate}" result=${state.result != null}');

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

                if (state.selectedBank != null || state.referenceCode.isNotEmpty || state.amount > 0) ...[
                  const SizedBox(height: 20),
                  bankAccountsAsync.when(
                    data: (accounts) => _VerificationResult(
                      state: state,
                      bankAccounts: accounts,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      card: card,
                      borderColor: borderColor,
                    ),
                    loading: () => _VerificationResult(
                      state: state,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      card: card,
                      borderColor: borderColor,
                    ),
                    error: (_, __) => _VerificationResult(
                      state: state,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      card: card,
                      borderColor: borderColor,
                    ),
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

class _VerificationResult extends StatelessWidget {
  const _VerificationResult({
    required this.state,
    this.bankAccounts = const [],
    required this.textPrimary,
    required this.textSecondary,
    required this.card,
    required this.borderColor,
  });

  final VerifyState state;
  final List<BankAccountEntity> bankAccounts;
  final Color textPrimary, textSecondary, card, borderColor;

  @override
  Widget build(BuildContext context) {
    final steps = _buildSteps();
    final passedCount = steps.where((s) => s.passed).length;
    debugPrint('[Verify] steps built: ${steps.length} total, $passedCount passed');
    for (final s in steps) {
      debugPrint('[Verify]  step: "${s.label}" value="${s.value}" passed=${s.passed} percent=${s.percent}');
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: passedCount == steps.length
              ? AppTheme.success.withOpacity(0.3)
              : borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.document_scanner_rounded,
                  color: AppTheme.primaryGreen, size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Text('Verification Steps',
                  style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textPrimary)),
              const Spacer(),
              Text('$passedCount/${steps.length}',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textSecondary)),
            ],
          ),
          const SizedBox(height: 14),
          ...steps.asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _StepRow(
              step: e.value,
              textSecondary: textSecondary,
              isLast: e.key == steps.length - 1,
            ),
          )),
        ],
      ),
    );
  }

  List<_StepData> _buildSteps() {
    final st = state;
    final isVerified = st.result != null;
    final isDuplicate = st.result?.riskFlags.any(
      (f) => f.toLowerCase().contains('duplicate') || f.toLowerCase().contains('already used'),
    ) ?? false;

    String accMatchValue = 'Pending';
    bool accMatchPassed = false;
    double accMatchPercent = 0;
    if (st.receiverAccount.isNotEmpty) {
      final trailingDigits = st.receiverAccount.replaceAll(RegExp(r'^[\s*\d]*\*+'), '').replaceAll(RegExp(r'[^\d]'), '');
      debugPrint('[Verify] receiverAccount="${st.receiverAccount}" → trailingDigits="$trailingDigits"');
      debugPrint('[Verify] bankAccounts count=${bankAccounts.length}');
      String? matched;
      double bestMatch = 0;
      for (final acct in bankAccounts) {
        final stored = acct.accountNumber.replaceAll(RegExp(r'[\s-]+'), '');
        debugPrint('[Verify] checking acct: bank="${acct.bankName}" stored="$stored" selectedBank="${st.selectedBank}"');
        if (st.selectedBank != null && !acct.bankName.contains(RegExp(RegExp.escape(st.selectedBank!), caseSensitive: false))) {
          debugPrint('[Verify]  → skipped (bank mismatch)');
          continue;
        }
        if (trailingDigits.isNotEmpty && stored.endsWith(trailingDigits)) {
          final pct = trailingDigits.length / stored.length * 100;
          debugPrint('[Verify]  → MATCH! pct=$pct');
          if (pct > bestMatch) {
            bestMatch = pct;
            matched = acct.accountNumber;
          }
        } else {
          debugPrint('[Verify]  → no match');
        }
      }
      if (matched != null) {
        accMatchPercent = bestMatch.clamp(0.0, 100.0);
        accMatchPassed = bestMatch >= 30;
        accMatchValue = '${st.receiverAccount} vs $matched';
        debugPrint('[Verify] account match FOUND: $accMatchValue (${accMatchPercent.toStringAsFixed(0)}%)');
      } else {
        final expected = bankAccounts.isNotEmpty ? bankAccounts.first.accountNumber : '—';
        accMatchValue = '${st.receiverAccount} vs $expected';
        debugPrint('[Verify] account match NOT FOUND. bankAccounts count=${bankAccounts.length}, first=$expected');
      }
    } else {
      debugPrint('[Verify] receiverAccount is empty, skipping account match');
    }

    return [
      _StepData(
        icon: Icons.account_balance_rounded,
        label: 'Detect payment method',
        value: st.selectedBank ?? 'Pending',
        passed: st.selectedBank != null,
        percent: 100,
      ),
      _StepData(
        icon: Icons.receipt_rounded,
        label: 'Fetch receipt page',
        value: st.referenceCode.isNotEmpty ? 'TX: ${st.referenceCode}' : 'Pending',
        passed: st.referenceCode.isNotEmpty,
        percent: st.referenceCode.isNotEmpty ? 100 : 0,
      ),
      _StepData(
        icon: Icons.monetization_on_rounded,
        label: 'Extract amount',
        value: st.amount > 0
            ? '${st.amount.toStringAsFixed(0)} ETB${st.expectedAmount > 0 ? ' (expected: ${st.expectedAmount.toStringAsFixed(0)} ETB)' : ''}'
            : 'Pending',
        passed: st.amount > 0,
        percent: st.amount > 0 ? 100 : 0,
      ),
      _StepData(
        icon: Icons.compare_arrows_rounded,
        label: 'Amount match (5% tolerance)',
        value: st.amount > 0 && st.expectedAmount > 0
            ? '${st.tolerancePercent.toStringAsFixed(1)}% difference'
            : 'Pending',
        passed: st.tolerancePassed,
        percent: st.amount > 0 ? ((1 - st.tolerancePercent / 100) * 100).clamp(0.0, 100.0).roundToDouble() : 0,
      ),
      _StepData(
        icon: Icons.credit_card_rounded,
        label: 'Extract receiver account',
        value: st.receiverAccount.isNotEmpty ? st.receiverAccount : 'Pending',
        passed: st.receiverAccount.isNotEmpty,
        percent: st.receiverAccount.isNotEmpty ? 100 : 0,
      ),
      _StepData(
        icon: Icons.compare_arrows_rounded,
        label: 'Receiver account match',
        value: accMatchValue,
        detail: accMatchPercent > 0 ? 'Match: ${accMatchPercent.toStringAsFixed(0)}%' : null,
        passed: accMatchPassed,
        percent: accMatchPercent,
      ),
      _StepData(
        icon: Icons.calendar_today_rounded,
        label: 'Transaction date',
        value: st.transactionDate.isNotEmpty ? st.transactionDate : 'Pending',
        passed: st.transactionDate.isNotEmpty,
        percent: st.transactionDate.isNotEmpty ? 100 : 0,
      ),
      _StepData(
        icon: Icons.verified_user_rounded,
        label: 'Duplicate check',
        value: isVerified
            ? (isDuplicate ? 'Duplicate found' : 'No duplicates \u2014 validity confirmed')
            : 'Pending verification',
        passed: isVerified && !isDuplicate,
        percent: isVerified ? (isDuplicate ? 0 : 100) : 0,
      ),
    ];
  }
}

class _StepData {
  final IconData icon;
  final String label, value;
  final bool passed;
  final String? detail;
  final double percent;
  const _StepData({
    required this.icon,
    required this.label,
    required this.value,
    this.passed = false,
    this.detail,
    this.percent = 0,
  });
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.step,
    required this.textSecondary,
    this.isLast = false,
  });
  final _StepData step;
  final Color textSecondary;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 18,
              child: Icon(
                step.passed ? Icons.check_circle_rounded : Icons.hourglass_empty_rounded,
                color: step.passed ? AppTheme.success : AppTheme.pending,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 144,
              child: Text(step.label,
                  style: GoogleFonts.inter(
                      fontSize: 12, color: textSecondary, fontWeight: FontWeight.w500)),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(step.value,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: step.passed ? AppTheme.success : AppTheme.pending),
                  overflow: TextOverflow.ellipsis),
            ),
            if (step.percent > 0)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (step.percent >= 100 ? AppTheme.success : AppTheme.pending).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('${step.percent.toStringAsFixed(0)}%',
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: step.percent >= 100 ? AppTheme.success : AppTheme.pending)),
              ),
          ],
        ),
        if (step.detail != null)
          Padding(
            padding: const EdgeInsets.only(left: 26, top: 2),
            child: Text(step.detail!,
                style: GoogleFonts.inter(
                    fontSize: 11, color: textSecondary, fontStyle: FontStyle.italic)),
          ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 4),
            child: Container(width: 1, height: 10, color: textSecondary.withOpacity(0.15)),
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
