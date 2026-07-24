import 'dart:io';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';
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
import 'package:payment_verifier/presentation/providers/connectivity_provider.dart';
import 'package:payment_verifier/presentation/providers/theme_provider.dart';
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

class _VerifyPaymentScreenState extends ConsumerState<VerifyPaymentScreen> {
  final _orderTotalController = TextEditingController();
  final _buyerController = TextEditingController();
  final _amountController = TextEditingController();
  final _receiverAcctController = TextEditingController();
  final _referenceController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _ocrService = OcrService();
  XFile? _selectedImage;

  String _ocrStatus = '';
  bool _isOcrRunning = false;

  @override
  void dispose() {
    _orderTotalController.dispose();
    _buyerController.dispose();
    _amountController.dispose();
    _receiverAcctController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _processOcr(String imagePath) async {
    if (!mounted) return;
    setState(() {
      _isOcrRunning = true;
      _ocrStatus = 'Running OCR...';
    });

    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final result = await _ocrService.processImage(inputImage);

      if (!mounted) return;

      if (result.hasAmount && _amountController.text.isEmpty) {
        _amountController.text = result.amount!;
        ref.read(verifyProvider.notifier).setAmount(double.parse(result.amount!));
      }

      final notifier = ref.read(verifyProvider.notifier);
      notifier.setOcrRawText(result.rawText);
      notifier.setOcrCompleted();

      if (result.hasReference) {
        final ref = normalizeFTReference(result.reference!);
        notifier.setCode(ref);
        _referenceController.text = ref;
      }

      final bank = _mapPaymentMethodToBank(result.paymentMethod);
      if (bank != null) {
        notifier.setBank(bank);
        notifier.setOcrDetectedBank(bank);
      }

      if (result.receiverAccount != null && result.receiverAccount!.isNotEmpty) {
        _receiverAcctController.text = result.receiverAccount!;
        notifier.setReceiverAccount(result.receiverAccount!);
      }

      String? resolvedCustomer = result.customerName;
      if (resolvedCustomer == null && result.rawText.isNotEmpty) {
        resolvedCustomer = extractCustomerName(
          result.rawText,
          geom: {},
        );
      }
      if (resolvedCustomer != null && resolvedCustomer.isNotEmpty) {
        notifier.setOcrExtractedCustomerName(resolvedCustomer);
        if (_buyerController.text.isEmpty) {
          _buyerController.text = resolvedCustomer;
          notifier.setBuyerName(resolvedCustomer);
        }
      }

      if (result.receiverName != null && result.receiverName!.isNotEmpty) {
        notifier.setOcrExtractedReceiverName(result.receiverName!);
        notifier.setReceiverName(result.receiverName!);
      }

      if (result.date != null && result.date!.isNotEmpty) {
        notifier.setTransactionDate(result.date!);
      }

      if (!mounted) return;
      setState(() {
        _ocrStatus = 'OCR complete';
        _isOcrRunning = false;
      });
    } catch (e) {
      debugPrint('[OCR] failed: $e');
      if (!mounted) return;
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
      debugPrint('[PickImage] source selected: $source');
      try {
        final file = await picker.pickImage(source: source);
        debugPrint('[PickImage] pickImage returned: ${file?.path}');
        if (file != null && mounted) {
        final dir = await getApplicationDocumentsDirectory();
        debugPrint('[PickImage] persistent dir: ${dir.path}');
        final localPath = '${dir.path}/receipt_${DateTime.now().millisecondsSinceEpoch}.jpg';
        debugPrint('[PickImage] copying ${file.path} -> $localPath');
        await File(file.path).copy(localPath);
        final exists = await File(localPath).exists();
        debugPrint('[PickImage] local file exists: $exists, size: ${await File(localPath).length()}');
        final localFile = XFile(localPath);
        setState(() => _selectedImage = localFile);
        debugPrint('[PickImage] state updated, path on XFile: ${_selectedImage?.path}');

        // Always set local path immediately so canVerify isn't blocked by upload
        ref.read(verifyProvider.notifier).setReceiptImage(localPath);

        // Upload to Supabase Storage for cross-device access (best-effort)
        final ds = ref.read(transactionDatasourceProvider);
        final receiptUrl = await ds.uploadReceiptImage(localPath);
        if (receiptUrl != null) {
          debugPrint('[PickImage] uploaded to storage: $receiptUrl');
          ref.read(verifyProvider.notifier).setReceiptImage(receiptUrl);
        } else {
          debugPrint('[PickImage] upload failed, using local path');
        }
        // Do NOT pre-set the date here — let OCR extract the actual receipt date.
        // The scan time is passed separately at verify() time via DateTime.now().
        _processOcr(localPath);
      } else {
        debugPrint('[PickImage] file was null or not mounted (mounted=$mounted)');
      }
      } catch (e, st) {
        debugPrint('[PickImage] ERROR: $e\n$st');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not pick image: $e'), backgroundColor: AppTheme.error),
          );
        }
      }
    }
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(verifyProvider.notifier);
    final st = ref.read(verifyProvider);

    final accounts = ref.read(bankAccountsProvider).valueOrNull ?? [];
    final businessAccounts = accounts.map((a) => a.accountNumber).toList();
    final txRepo = ref.read(transactionRepositoryProvider);

    // Determine expected receiver name from the bank account holder that matches selectedBank
    final selectedBankName = st.selectedBank;
    String? expectedReceiverName;
    if (selectedBankName != null) {
      final matchingAccount = accounts.where((a) =>
        a.bankName.toLowerCase() == selectedBankName.toLowerCase() && a.isActive).firstOrNull;
      expectedReceiverName = matchingAccount?.holderName;
    }

    final ocr = OcrResult(
      rawText: st.ocrRawText,
      amount: st.amount > 0 ? st.amount.toStringAsFixed(2) : null,
      reference: st.referenceCode.isNotEmpty ? st.referenceCode : null,
      paymentMethod: st.ocrDetectedBank,
      customerName: st.ocrExtractedCustomerName.isNotEmpty ? st.ocrExtractedCustomerName : null,
      receiverAccount: st.receiverAccount.isNotEmpty ? st.receiverAccount : null,
      receiverName: st.ocrExtractedReceiverName.isNotEmpty ? st.ocrExtractedReceiverName : null,
      date: st.transactionDate.isNotEmpty ? st.transactionDate : null,
    );

    final service = VerificationService(
      config: VerifyConfig(
        expectedAmount: st.orderTotal > 0 ? st.orderTotal : null,
        businessAccounts: businessAccounts,
        selectedBank: st.selectedBank,
        ocrDetectedBank: st.ocrDetectedBank,
        expectedCustomerName: st.buyerName.isNotEmpty ? st.buyerName : null,
        expectedReceiverName: expectedReceiverName,
      ),
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

    final verifyResult = await service.verify(ocr, scanTime: DateTime.now());
    notifier.setVerifyResult(verifyResult);

    if (verifyResult.verdict == Verdict.verified) {
      try {
        await notifier.saveTransaction();
        debugPrint('[Verify] transaction saved');
      } catch (e) {
        debugPrint('[Verify] saveTransaction error: $e');
      }
    }

    if (!mounted) return;
    _showResultPopup(verifyResult);
  }

  void _showResultPopup(VerifyResult result) {
    final isDark = ref.read(themeProvider) == ThemeMode.dark;
    final bg = isDark ? AppTheme.bgCard : AppTheme.lightCard;
    final textPrimary = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;

    showGeneralDialog(
      context: context,
      barrierDismissible: result.verdict == Verdict.verified,
      barrierLabel: 'Verification Result',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                constraints: const BoxConstraints(maxHeight: 620),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Center(
                          child: Column(
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: result.verdict == Verdict.verified
                                      ? AppTheme.success.withOpacity(0.12)
                                      : AppTheme.error.withOpacity(0.12),
                                ),
                                child: Icon(
                                  result.verdict == Verdict.verified
                                      ? Icons.check_circle_rounded
                                      : Icons.cancel_rounded,
                                  color: result.verdict == Verdict.verified
                                      ? AppTheme.success
                                      : AppTheme.error,
                                  size: 44,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                result.verdict.label,
                                style: GoogleFonts.outfit(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: result.verdict == Verdict.verified
                                      ? AppTheme.success
                                      : result.verdict == Verdict.tryAgain
                                          ? AppTheme.warning
                                          : AppTheme.error,
                                ),
                              ),

                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Divider(color: Colors.white12),
                        const SizedBox(height: 12),
                        Text('Verification Checks',
                            style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: textPrimary)),
                        const SizedBox(height: 10),

                        // Steps
                        ...result.steps.map((step) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                step.passed
                                    ? Icons.check_circle_rounded
                                    : Icons.cancel_rounded,
                                color: step.passed
                                    ? AppTheme.success
                                    : AppTheme.error,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 132,
                                child: Text(step.name,
                                    style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: textSecondary,
                                        fontWeight: FontWeight.w500)),
                              ),
                              Expanded(
                                child: Text(step.value,
                                    style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: step.passed
                                            ? AppTheme.success
                                            : AppTheme.error),
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        )),

                        const SizedBox(height: 24),

                        // Action button
                        SizedBox(
                          width: double.infinity,
                          child: GradientButton(
                            label: result.verdict == Verdict.verified
                                ? 'Done'
                                : result.verdict == Verdict.tryAgain
                                    ? 'Try Again'
                                    : 'Close',
                            icon: result.verdict == Verdict.verified
                                ? Icons.check_rounded
                                : result.verdict == Verdict.tryAgain
                                    ? Icons.refresh_rounded
                                    : Icons.close_rounded,
                            gradient: result.verdict == Verdict.verified
                                ? AppTheme.primaryGradient
                                : result.verdict == Verdict.tryAgain
                                    ? const LinearGradient(colors: [AppTheme.warning, Color(0xFFE67E22)])
                                    : const LinearGradient(colors: [AppTheme.error, Color(0xFFC0392B)]),
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              if (result.verdict == Verdict.verified ||
                                  result.verdict == Verdict.failed) {
                                _reset();
                              }
                            },
                          ),
                        ),
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

  void _reset() {
    ref.read(verifyProvider.notifier).reset();
    _orderTotalController.clear();
    _buyerController.clear();
    _amountController.clear();
    _receiverAcctController.clear();
    _referenceController.clear();
    setState(() => _selectedImage = null);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(verifyProvider);
    final notifier = ref.read(verifyProvider.notifier);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final bankAccountsAsync = ref.watch(bankAccountsProvider);
    final connectivity = ref.watch(connectivityProvider);
    // Show banner only when fully offline — slow connection doesn't block OCR
    final isOffline = connectivity.quality == ConnectionQuality.none;

    final bg = isDark ? AppTheme.bgDark : AppTheme.lightBg;
    final card = isDark ? AppTheme.bgCard : AppTheme.lightCard;
    final borderColor =
        isDark ? AppTheme.borderSubtle : AppTheme.lightBorderSubtle;
    final textSecondary =
        isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // Connectivity warning — only shown here, only when fully offline
            if (isOffline)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: AppTheme.error,
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No internet — receipt scanning requires a connection',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
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
                    hasError: state.selectedBank == null,
                    activeBanks: bankAccountsAsync.when(
                      data: (a) => a.where((x) => x.isActive).map((x) => x.bankName).toSet(),
                      loading: () => <String>{},
                      error: (_, __) => <String>{},
                    )),
                if (state.selectedBank == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 12),
                    child: Text('Please select a bank or wallet',
                        style: GoogleFonts.inter(fontSize: 11, color: AppTheme.error)),
                  ),
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

                const SizedBox(height: 20),

                // Hide customer name for Telebirr only — CBE Birr has sender name in receipt
                if (state.ocrDetectedBank != 'telebirr' &&
                    state.selectedBank != 'Telebirr') ...[
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
                ],

                // Hide receiver account when:
                // - Telebirr/CBE Birr (no account shown on these receipts)
                // - OR OCR completed and found no account on the receipt
                if (state.ocrDetectedBank != 'telebirr' && state.ocrDetectedBank != 'cbe_birr' &&
                    state.selectedBank != 'Telebirr' && state.selectedBank != 'CBE Birr' &&
                    !(state.ocrCompleted && state.receiverAccount.isEmpty)) ...[
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
                ],

                AppTextField(
                  label: 'Reference Code',
                  hint: 'Transaction ID from receipt',
                  controller: _referenceController,
                  prefixIcon: Icon(Icons.tag_rounded,
                      color: isDark ? AppTheme.textTertiary : AppTheme.lightTextTertiary,
                      size: 20),
                  onChanged: (v) => notifier.setCode(v),
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

                if (!state.ocrCompleted)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: AppTheme.warning, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Scan a receipt image first to auto-fill fields',
                              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.warning),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

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
            ), // Expanded
          ], // Column children
        ), // Column
      ), // SafeArea
    ); // Scaffold
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
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
                  Image.file(
                    File(selectedImage!.path),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      debugPrint('[ImageUploadZone] ERROR loading image: path=${selectedImage!.path}, error=$error');
                      return Container(
                        color: card,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.broken_image_rounded, color: AppTheme.error, size: 32),
                              const SizedBox(height: 6),
                              Text('Failed to load image', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.error)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
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

class _BankDropdown extends StatelessWidget {
  const _BankDropdown({
    this.value,
    required this.onChanged,
    required this.isDark,
    this.hasError = false,
    this.activeBanks = const {},
  });
  final String? value;
  final void Function(String) onChanged;
  final bool isDark;
  final bool hasError;
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
          border: Border.all(
            color: hasError ? AppTheme.error : borderColor,
            width: hasError ? 1.5 : 1,
          )),
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
