import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:payment_verifier/core/constants/app_constants.dart';
import 'package:payment_verifier/core/theme/app_theme.dart';
import 'package:payment_verifier/core/utils/formatters.dart';
import 'package:payment_verifier/data/services/ocr_service.dart';
import 'package:payment_verifier/data/services/verification_service.dart';
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
  final _receiverAcctController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _ocrService = OcrService();
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
    _receiverAcctController.dispose();
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
      final result = await _ocrService.processImage(inputImage);
      debugPrint('[OCR] result: $result');
      debugPrint('[OCR] customerName=${result.customerName} receiverName=${result.receiverName}');
      debugPrint('[OCR] rawText (${result.rawText.length} chars):\n${result.rawText}');

      // ── Resolve amount ──────────────────────────────────────────────
      if (result.hasAmount && _amountController.text.isEmpty) {
        _amountController.text = result.amount!;
        ref.read(verifyProvider.notifier).setAmount(double.parse(result.amount!));
      }

      final notifier = ref.read(verifyProvider.notifier);
      notifier.setOcrRawText(result.rawText);
      notifier.setOcrCompleted();

      // ── Resolve reference (normalise OCR letter↔digit swaps) ────────
      if (result.hasReference) {
        notifier.setCode(normalizeFTReference(result.reference!));
      }

      final bank = _mapPaymentMethodToBank(result.paymentMethod);
      if (bank != null) {
        debugPrint('[OCR] mapped bank: $bank');
        notifier.setBank(bank);
        notifier.setOcrDetectedBank(bank);
      }

      // ── Resolve receiver account ───────────────────────────────────
      if (result.receiverAccount != null && result.receiverAccount!.isNotEmpty) {
        _receiverAcctController.text = result.receiverAccount!;
        notifier.setReceiverAccount(result.receiverAccount!);
      }

      // ── Resolve customer name ───────────────────────────────────────
      String? resolvedCustomer = result.customerName;
      if (resolvedCustomer == null && result.rawText.isNotEmpty) {
        resolvedCustomer = extractCustomerName(
          result.rawText.replaceAll('\n', ' '),
          geom: {},
        );
      }
      if (resolvedCustomer != null && resolvedCustomer.isNotEmpty) {
        if (_buyerController.text.isEmpty) {
          _buyerController.text = resolvedCustomer;
        }
        notifier.setBuyerName(resolvedCustomer);
      }

      if (result.receiverName != null && result.receiverName!.isNotEmpty) {
        notifier.setReceiverName(result.receiverName!);
      }

      // ── Resolve date ────────────────────────────────────────────────
      if (result.date != null && result.date!.isNotEmpty) {
        notifier.setTransactionDate(result.date!);
      }

      setState(() {
        _ocrStatus = 'OCR complete — ${result.rawText.length} chars';
        _isOcrRunning = false;
      });

      // ── Run verification via VerificationService ──────────────────
      final st = ref.read(verifyProvider);
      final accounts = ref.read(bankAccountsProvider).valueOrNull ?? [];
      final businessAccounts = accounts.map((a) => a.accountNumber).toList();
      // ignore: invalid_use_of_internal_member
      final txRepo = ref.read(transactionRepositoryProvider);
      final service = VerificationService(
        config: VerifyConfig(
          expectedAmount: st.orderTotal > 0 ? st.orderTotal : null,
          businessAccounts: businessAccounts,
          businessName: null,
          freshnessWindow: const Duration(hours: 24),
        ),
        fetch: null,
        isDuplicate: (code) async {
          try {
            final existingTxs = await txRepo.getTransactions();
            final normalized = normalizeFTReference(code);
            final dup = existingTxs.where((t) =>
                normalizeFTReference(t.referenceCode) == normalized).toList();
            if (dup.isNotEmpty) return dup.last.createdAt;
          } catch (_) {}
          return null;
        },
      );
      final verifyResult = await service.verify(result, qrData: null);
      notifier.setVerifyResult(verifyResult);
      debugPrint('[Verify] verdict="${verifyResult.verdict.label}" '
          '${verifyResult.steps.where((s) => s.passed).length}/${verifyResult.steps.length} passed');

      // Save reference when verdict is looksGenuine or verified.
      if (verifyResult.verdict == Verdict.looksGenuine || verifyResult.verdict == Verdict.verified) {
        try {
          await notifier.saveTransaction();
          debugPrint('[Verify] transaction saved on verdict=${verifyResult.verdict.label}');
        } catch (e) {
          debugPrint('[Verify] saveTransaction error: $e');
        }
      }
    } catch (e) {
      debugPrint('[OCR] failed: $e');
      setState(() {
        _ocrStatus = 'OCR failed: $e';
        _isOcrRunning = false;
      });
    }
  }

  String? _mapPaymentMethodToBank(String? method) {
    switch (method) {
      case 'cbe':
        return BankName.cbe.displayName;
      case 'boa':
        return BankName.boa.displayName;
      case 'zemen':
        return BankName.zemen.displayName;
      case 'dashen':
        return BankName.dashen.displayName;
      case 'awash':
        return BankName.awash.displayName;
      case 'telebirr':
      case 'mpesa':
        return BankName.telebirr.displayName;
      case 'cbe_birr':
        return BankName.cbeBirr.displayName;
      default:
        return null;
    }
  }

  String _monthAbbr(int m) => [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ][m - 1];

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final isDark = ref.read(themeProvider) == ThemeMode.dark;
    final sheetBg = isDark ? AppTheme.bgCard : AppTheme.lightSurface;
    final sheetText = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: sheetBg,
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
                  style: GoogleFonts.inter(color: sheetText)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined,
                  color: AppTheme.accentGold),
              title: Text('Choose from Gallery',
                  style: GoogleFonts.inter(color: sheetText)),
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
        final now = DateTime.now();
        final h = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
        final ampm = now.hour >= 12 ? 'PM' : 'AM';
        final dateStr = '${_monthAbbr(now.month)} ${now.day}, ${now.year} $h:${now.minute.toString().padLeft(2, '0')} $ampm';
        ref.read(verifyProvider.notifier).setTransactionDate(dateStr);
        _processOcr(file.path);
      }
    }
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(verifyProvider.notifier);
    try {
      final tx = await notifier.saveTransaction();
      final st = ref.read(verifyProvider);
      if (st.result != null) {
        _resultAnim.forward(from: 0);
      }
    } catch (e) {
      debugPrint('[Verify] save failed: $e');
    }
  }

  void _reset() {
    ref.read(verifyProvider.notifier).reset();
    _orderTotalController.clear();
    _buyerController.clear();
    _amountController.clear();
    _receiverAcctController.clear();
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
                    onChanged: notifier.setBank,
                    isDark: isDark,
                    activeBanks: bankAccountsAsync.when(
                      data: (a) => a.where((x) => x.isActive).map((x) => x.bankName).toSet(),
                      loading: () => <String>{},
                      error: (_, __) => <String>{},
                    )),
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
                  onChanged: (v) => notifier.setOrderTotal(double.tryParse(v) ?? 0),
                  validator: (v) {
                    if (v == null || v.isEmpty) return null;
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
                  textTertiary: isDark ? AppTheme.textTertiary : AppTheme.lightTextTertiary,
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

                if (state.ocrCompleted) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => _showDetailsDialog(context, state),
                      icon: Icon(Icons.info_outline_rounded, size: 18, color: AppTheme.primaryGreen),
                      label: Text('View Details',
                          style: GoogleFonts.inter(
                              fontSize: 13, fontWeight: FontWeight.w600,
                              color: AppTheme.primaryGreen)),
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
                  label: 'Receiver Account',
                  hint: 'Account paid to',
                  controller: _receiverAcctController,
                  prefixIcon: Icon(Icons.credit_card_rounded,
                      color: isDark
                          ? AppTheme.textTertiary
                          : AppTheme.lightTextTertiary,
                      size: 20),
                  onChanged: notifier.setReceiverAccount,
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
                  onChanged: (v) => notifier.setAmount(double.tryParse(v) ?? 0),
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

  void _showDetailsDialog(BuildContext context, VerifyState st) {
    final steps = _VerificationResult(
      state: st,
      textPrimary: Colors.white,
      textSecondary: Colors.white70,
      card: const Color(0xFF1E1E2C),
      borderColor: const Color(0xFF2A2A3C),
    )._buildSteps();

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Details',
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, anim1, anim2) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                constraints: const BoxConstraints(maxHeight: 600),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.document_scanner_rounded,
                                color: AppTheme.primaryGreen, size: 22),
                            const SizedBox(width: 10),
                            Text('Verification Details',
                                style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.close_rounded,
                                  color: Colors.white54, size: 22),
                              onPressed: () => Navigator.of(ctx).pop(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('${steps.where((s) => s.passed).length}/${steps.length} passed',
                            style: GoogleFonts.inter(
                                fontSize: 12, color: Colors.white54)),
                        const SizedBox(height: 16),
                        ...steps.asMap().entries.map((e) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: _StepRow(
                                  step: e.value,
                                  textSecondary: Colors.white54,
                                  isLast: e.key == steps.length - 1),
                            )),

                        ...[
                          const Divider(color: Colors.white12, height: 24),
                          Text('Extracted Data',
                              style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                          const SizedBox(height: 8),
                          _ExtractedField(label: 'Customer Name',
                              value: st.buyerName.isNotEmpty ? st.buyerName : 'Not found',
                              textSecondary: Colors.white54),
                          _ExtractedField(label: 'Amount',
                              value: st.amount > 0 ? '${st.amount.toStringAsFixed(2)} ETB' : 'Not found',
                              textSecondary: Colors.white54),
                          _ExtractedField(label: 'Reference',
                              value: st.referenceCode.isNotEmpty ? st.referenceCode : 'Not found',
                              textSecondary: Colors.white54),
                          _ExtractedField(label: 'Bank (OCR)',
                              value: st.ocrDetectedBank ?? 'Not detected',
                              textSecondary: Colors.white54),
                          _ExtractedField(label: 'Bank (Selected)',
                              value: st.selectedBank ?? 'None',
                              textSecondary: Colors.white54),
                          _ExtractedField(label: 'Receiver Account',
                              value: st.receiverAccount.isNotEmpty ? st.receiverAccount : 'Not found',
                              textSecondary: Colors.white54),
                          _ExtractedField(label: 'Transaction Date',
                              value: st.transactionDate.isNotEmpty ? st.transactionDate : 'Not found',
                              textSecondary: Colors.white54),
                          _ExtractedField(label: 'Order Total',
                              value: st.orderTotal > 0 ? '${st.orderTotal.toStringAsFixed(2)} ETB' : 'Not set',
                              textSecondary: Colors.white54),
                        ],
                        if (st.ocrRawText.isNotEmpty) ...[
                          const Divider(color: Colors.white12, height: 24),
                          Text('Full OCR Text',
                              style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: SelectableText(st.ocrRawText,
                                style: GoogleFonts.jetBrainsMono(
                                    fontSize: 11,
                                    color: Colors.white70,
                                    height: 1.5)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
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
      required this.textSecondary,
      required this.textTertiary});
  final XFile? selectedImage;
  final VoidCallback onTap;
  final Color card, borderColor, textSecondary, textTertiary;

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
                          fontSize: 12, color: textTertiary)),
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
    final result = state.verifyResult;
    if (result == null) return [];

    final converter = _VStepConverter();
    final steps = result.steps.map(converter.convert).toList();
    steps.add(_StepData(
      icon: Icons.gavel_rounded,
      label: 'Verdict',
      value: result.verdict.label,
      state: result.verdict == Verdict.rejected
          ? VStepState.fail
          : result.verdict == Verdict.review
              ? VStepState.review
              : VStepState.pass,
      percent: result.verdict == Verdict.rejected ? 0.0 : 100.0,
    ));
    return steps;
  }
}

class _ExtractedField extends StatelessWidget {
  const _ExtractedField({
    required this.label,
    required this.value,
    required this.textSecondary,
  });
  final String label, value;
  final Color textSecondary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 144,
            child: Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12, color: textSecondary, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(value,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: value == 'Not found' || value == 'Not set' || value == 'None'
                        ? Colors.white38
                        : Colors.white),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

/// Maps a [VStep] from [VerificationService] to a UI [_StepData].
class _VStepConverter {
  IconData _iconFor(String name) {
    final n = name.toLowerCase();
    if (n.contains('payment') || n.contains('method')) return Icons.account_balance_rounded;
    if (n.contains('qr')) return Icons.qr_code_rounded;
    if (n.contains('customer') || n.contains('name')) return Icons.person_outline_rounded;
    if (n.contains('amount') && n.contains('match')) return Icons.compare_arrows_rounded;
    if (n.contains('amount')) return Icons.monetization_on_rounded;
    if (n.contains('receiver') && (n.contains('match') || n.contains('name'))) return Icons.compare_arrows_rounded;
    if (n.contains('receiver') || n.contains('account')) return Icons.credit_card_rounded;
    if (n.contains('duplicate')) return Icons.verified_user_rounded;
    if (n.contains('fresh') || n.contains('date')) return Icons.access_time_rounded;
    if (n.contains('status') || n.contains('bank')) return Icons.account_balance_rounded;
    if (n.contains('fetch') || n.contains('confirm')) return Icons.cloud_download_rounded;
    return Icons.circle_rounded;
  }

  _StepData convert(VStep step) {
    return _StepData(
      icon: _iconFor(step.name),
      label: step.name,
      value: step.value,
      state: step.state,
      percent: step.passed ? 100.0 : 0.0,
    );
  }
}

class _StepData {
  final IconData icon;
  final String label, value;
  final VStepState state;
  final double percent;
  bool get passed => state == VStepState.pass;
  const _StepData({
    required this.icon,
    required this.label,
    required this.value,
    this.state = VStepState.fail,
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
    Color colorFor(VStepState s) {
      switch (s) {
        case VStepState.pass: return AppTheme.success;
        case VStepState.fail: return AppTheme.error;
        case VStepState.review: return AppTheme.warning;
      }
    }
    IconData iconFor(VStepState s) {
      switch (s) {
        case VStepState.pass: return Icons.check_circle_rounded;
        case VStepState.fail: return Icons.cancel_rounded;
        case VStepState.review: return Icons.warning_amber_rounded;
      }
    }
    final color = colorFor(step.state);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 18,
              child: Icon(iconFor(step.state), color: color, size: 16),
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
                      fontSize: 12, fontWeight: FontWeight.w600, color: color),
                  overflow: TextOverflow.ellipsis),
            ),
            if (step.percent > 0)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('${step.percent.toStringAsFixed(0)}%',
                    style: GoogleFonts.inter(
                        fontSize: 10, fontWeight: FontWeight.w700, color: color)),
              ),
          ],
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
  const _BankDropdown({
    this.value,
    required this.onChanged,
    required this.isDark,
    this.activeBanks = const {},
  });
  final String? value;
  final void Function(String) onChanged;
  final bool isDark;
  final Set<String> activeBanks;

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

    final items = BankName.values.where((b) {
      if (activeBanks.isEmpty) return true;
      return activeBanks.any((ab) =>
          ab.toLowerCase().contains(b.displayName.toLowerCase()) ||
          b.displayName.toLowerCase().contains(ab.toLowerCase()) ||
          b.shortName.toLowerCase().contains(ab.toLowerCase()));
    }).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
          color: inputBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.any((b) => b.displayName == value) ? value : null,
          hint: Text('Select bank or wallet',
              style: GoogleFonts.inter(color: hintColor, fontSize: 14)),
          isExpanded: true,
          dropdownColor: dropdownBg,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: iconColor),
          items: items
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
