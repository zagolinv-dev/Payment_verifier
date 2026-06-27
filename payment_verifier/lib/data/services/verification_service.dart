import 'ocr_service.dart';

enum VStepState { pass, fail, review }

/// looksGenuine = all local checks passed but NOT bank-confirmed (no Ethiopia
/// backend). The cashier should still confirm the money landed.
/// verified = bank-confirmed (only when a real fetch is wired in future).
enum Verdict { verified, looksGenuine, review, rejected }

extension VerdictLabel on Verdict {
  String get label {
    switch (this) {
      case Verdict.verified:
        return 'VERIFIED';
      case Verdict.looksGenuine:
        return 'LOOKS GENUINE — confirm receipt';
      case Verdict.review:
        return 'NEEDS REVIEW';
      case Verdict.rejected:
        return 'REJECTED';
    }
  }
}

class VStep {
  final String name;
  final String value;
  final VStepState state;
  const VStep(this.name, this.value, this.state);
  bool get passed => state == VStepState.pass;
  @override
  String toString() => 'step "$name" value="$value" state=$state';
}

class VerifyConfig {
  final double? expectedAmount; // café bill total
  final List<String> businessAccounts; // café's own account number(s), full
  final String? businessName; // optional receiver-name match
  final Duration freshnessWindow; // default 24h
  final double amountTolerance; // default 5%
  const VerifyConfig({
    this.expectedAmount,
    this.businessAccounts = const [],
    this.businessName,
    this.freshnessWindow = const Duration(hours: 24),
    this.amountTolerance = 0.05,
  });
}

/// Authoritative bank lookup (future, needs Ethiopia hosting). Optional.
class FetchResult {
  final bool found;
  final double? amount;
  final String? receiverAccount;
  final String? receiverName;
  final String? error;
  const FetchResult({this.found = false, this.amount, this.receiverAccount, this.receiverName, this.error});
}

typedef FetchReceipt = Future<FetchResult> Function(OcrResult ocr);
typedef IsDuplicate = Future<DateTime?> Function(String reference);

class VerifyResult {
  final List<VStep> steps;
  final Verdict verdict;
  final OcrResult ocr;
  VerifyResult(this.steps, this.verdict, this.ocr);
  int get passedCount => steps.where((s) => s.passed).length;
}

class VerificationService {
  final VerifyConfig config;
  final FetchReceipt? fetch; // optional; leave null until you have Ethiopia hosting
  final IsDuplicate? isDuplicate;

  VerificationService({required this.config, this.fetch, this.isDuplicate});

  /// [qrData] = text decoded from the receipt's QR (use mobile_scanner). Null if none.
  Future<VerifyResult> verify(OcrResult ocr, {String? qrData}) async {
    final steps = <VStep>[];
    bool hardReject = false;
    bool review = false;
    void reject() => hardReject = true;
    void needReview() => review = true;

    final String? ref = ocr.reference == null ? null : normalizeFTReference(ocr.reference!);

    // 1) Payment method
    steps.add(ocr.paymentMethod != null
        ? VStep('Detect payment method', ocr.bankName ?? ocr.paymentMethod!, VStepState.pass)
        : _failR('Detect payment method', 'Unknown', needReview));

    // 2) Status
    if (ocr.status == 'success') {
      steps.add(const VStep('Status', 'Success', VStepState.pass));
    } else if (ocr.status == 'failed') {
      steps.add(const VStep('Status', 'Failed/declined', VStepState.fail));
      reject();
    } else {
      steps.add(VStep('Status', ocr.status ?? 'unknown', VStepState.review));
      needReview();
    }

    // 3) Customer name
    steps.add(ocr.customerName != null
        ? VStep('Customer name', ocr.customerName!, VStepState.pass)
        : _failR('Customer name', 'Not found', needReview));

    // 4) QR consistency (in-app; no network). Strong fake signal if it mismatches.
    final qr = _checkQr(ocr.paymentMethod, qrData, ref);
    switch (qr) {
      case _Qr.ok:
        steps.add(const VStep('QR check', 'QR matches receipt ✓', VStepState.pass));
        break;
      case _Qr.mismatch:
        steps.add(const VStep('QR check', 'QR does not match / not official', VStepState.fail));
        reject(); // QR present but wrong = likely fake
        break;
      case _Qr.none:
        steps.add(const VStep('QR check', 'No QR to check', VStepState.review));
        break; // neutral: does not block looksGenuine
    }

    // 5) Optional authoritative fetch (only if wired + hosted in Ethiopia)
    FetchResult fr = const FetchResult(found: false, error: 'no backend');
    if (fetch != null && ref != null) {
      try {
        fr = await fetch!(ocr).timeout(const Duration(seconds: 10),
            onTimeout: () => const FetchResult(found: false, error: 'timeout'));
      } catch (e) {
        fr = FetchResult(found: false, error: e.toString());
      }
      steps.add(fr.found
          ? VStep('Bank confirmation', 'Confirmed: $ref', VStepState.pass)
          : VStep('Bank confirmation', 'Not confirmed (${fr.error ?? "n/a"})', VStepState.review));
    }
    final bool authoritative = fr.found;

    final double? amount = fr.amount ?? ocr.amountValue;
    final String? receiverAcct = fr.receiverAccount ?? ocr.receiverAccount;
    final String? receiverName = fr.receiverName ?? ocr.receiverName;

    // 6) Extract amount
    steps.add(amount != null
        ? VStep('Extract amount', '${amount.toStringAsFixed(2)} ETB', VStepState.pass)
        : _failR('Extract amount', 'Not found', needReview));

    // 7) Amount match
    if (config.expectedAmount == null) {
      steps.add(const VStep('Amount match', 'No expected amount set', VStepState.review));
      needReview();
    } else if (amount == null) {
      steps.add(const VStep('Amount match', 'No amount to compare', VStepState.fail));
      needReview();
    } else {
      final diff = (amount - config.expectedAmount!).abs() / config.expectedAmount!;
      if (diff <= config.amountTolerance) {
        steps.add(VStep('Amount match', '${(diff * 100).toStringAsFixed(1)}% diff', VStepState.pass));
      } else {
        steps.add(VStep('Amount match',
            '${(diff * 100).toStringAsFixed(1)}% diff (got ${amount.toStringAsFixed(2)}, expected ${config.expectedAmount})',
            VStepState.fail));
        needReview();
      }
    }

    // 8) Extract receiver account
    steps.add(receiverAcct != null
        ? VStep('Extract receiver account', receiverAcct, VStepState.pass)
        : _failR('Extract receiver account', 'Not found', needReview));

    // 9) Receiver account match (to café account)
    if (config.businessAccounts.isEmpty) {
      steps.add(const VStep('Receiver account match', 'Business account not set', VStepState.fail));
      needReview();
    } else if (receiverAcct == null) {
      steps.add(const VStep('Receiver account match', 'No receiver account', VStepState.fail));
      needReview();
    } else if (_suffixMatch(receiverAcct, config.businessAccounts)) {
      steps.add(VStep('Receiver account match', '$receiverAcct ✓', VStepState.pass));
    } else {
      steps.add(VStep('Receiver account match', '$receiverAcct — NOT your account', VStepState.fail));
      reject(); // paid to someone else
    }

    // 9b) Receiver name match (optional)
    if (config.businessName != null && receiverName != null) {
      final ok = _nameMatch(receiverName, config.businessName!);
      steps.add(VStep('Receiver name match', ok ? '$receiverName ✓' : '$receiverName ≠ ${config.businessName}',
          ok ? VStepState.pass : VStepState.review));
      if (!ok) needReview();
    }

    // 10) Transaction date
    final dt = parseReceiptDate(ocr.date);
    steps.add(dt != null
        ? VStep('Transaction date', ocr.date!, VStepState.pass)
        : _failR('Transaction date', ocr.date ?? 'Not found', needReview));

    // 11) Date freshness
    if (dt == null) {
      steps.add(const VStep('Date freshness', 'Unreadable date', VStepState.review));
      needReview();
    } else {
      final now = DateTime.now();
      if (dt.isAfter(now.add(const Duration(minutes: 2)))) {
        steps.add(const VStep('Date freshness', 'Future-dated', VStepState.fail));
        reject();
      } else if (now.difference(dt) > config.freshnessWindow) {
        steps.add(VStep('Date freshness',
            'Too old (${now.difference(dt).inHours}h ago, max ${config.freshnessWindow.inHours}h)',
            VStepState.fail));
        needReview();
      } else {
        steps.add(const VStep('Date freshness', 'Fresh', VStepState.pass));
      }
    }

    // 12) Duplicate check (uses normalized ref)
    if (ref == null) {
      steps.add(const VStep('Duplicate check', 'No reference', VStepState.fail));
      needReview();
    } else if (isDuplicate == null) {
      steps.add(const VStep('Duplicate check', 'Not checked', VStepState.review));
      needReview();
    } else {
      final usedOn = await isDuplicate!(ref);
      if (usedOn != null) {
        steps.add(VStep('Duplicate check', 'Already used on ${_d(usedOn)}', VStepState.fail));
        reject();
      } else {
        steps.add(const VStep('Duplicate check', 'No duplicate', VStepState.pass));
      }
    }

    // Verdict
    Verdict verdict;
    if (hardReject) {
      verdict = Verdict.rejected;
    } else if (review) {
      verdict = Verdict.review;
    } else if (authoritative) {
      verdict = Verdict.verified; // bank-confirmed
    } else {
      verdict = Verdict.looksGenuine; // all local checks passed, confirm receipt
    }
    steps.add(VStep('Verdict', verdict.label,
        verdict == Verdict.rejected
            ? VStepState.fail
            : verdict == Verdict.review
                ? VStepState.review
                : VStepState.pass));

    // ignore: avoid_print
    print('[Verify] $verdict (${steps.where((s) => s.passed).length}/${steps.length} passed)');
    return VerifyResult(steps, verdict, ocr);
  }

  // --- QR consistency (no network) -------------------------------------------
  _Qr _checkQr(String? bank, String? qrData, String? ref) {
    if (qrData == null || qrData.trim().isEmpty) return _Qr.none;
    final q = qrData.toLowerCase();
    final domain = _qrDomain(bank);
    if (domain != null && !q.contains(domain)) return _Qr.mismatch; // not official
    if (ref != null && q.toUpperCase().contains(ref)) return _Qr.ok; // ref embedded in QR
    return _Qr.none; // official-looking but ref not embedded -> can't confirm
  }

  String? _qrDomain(String? bank) {
    switch (bank) {
      case 'cbe':
        return 'cbe.com.et';
      case 'boa':
        return 'abyssinia';
      case 'telebirr':
        return 'ethiotelecom';
      case 'awash':
        return 'awash';
      default:
        return null;
    }
  }

  // --- matching helpers -------------------------------------------------------
  VStep _failR(String name, String value, void Function() onReview) {
    onReview();
    return VStep(name, value, VStepState.fail);
  }

  bool _suffixMatch(String masked, List<String> fulls) {
    final tail = RegExp(r'(\d{2,})\D*$').firstMatch(masked)?.group(1);
    final head = RegExp(r'^(\d+)').firstMatch(masked)?.group(1);
    if (tail == null) return false;
    for (final f in fulls) {
      final digits = f.replaceAll(RegExp(r'\D'), '');
      if (digits.endsWith(tail) && (head == null || digits.startsWith(head))) return true;
    }
    return false;
  }

  bool _nameMatch(String a, String b) {
    String norm(String s) => s.toUpperCase().replaceAll(RegExp(r'[^A-Z ]'), '').trim();
    final na = norm(a), nb = norm(b);
    return na.contains(nb) || nb.contains(na);
  }

  String _d(DateTime d) => '${d.year}-${_2(d.month)}-${_2(d.day)}';
  String _2(int n) => n.toString().padLeft(2, '0');
}

enum _Qr { ok, mismatch, none }

/// Parse the receipt date formats into a DateTime.
DateTime? parseReceiptDate(String? raw) {
  if (raw == null) return null;
  final s = raw.trim();

  final mn = RegExp(
    r'([A-Za-z]{3,9})\s+(\d{1,2}),?\s+(\d{4})(?:[ ,]+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([APap][Mm])?)?',
  ).firstMatch(s);
  if (mn != null) {
    const months = {
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
      'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
    };
    final mo = months[mn.group(1)!.toLowerCase().substring(0, 3)];
    if (mo != null) {
      int h = int.tryParse(mn.group(4) ?? '0') ?? 0;
      final ap = mn.group(7)?.toLowerCase();
      if (ap == 'pm' && h < 12) h += 12;
      if (ap == 'am' && h == 12) h = 0;
      return DateTime(int.parse(mn.group(3)!), mo, int.parse(mn.group(2)!), h,
          int.tryParse(mn.group(5) ?? '0') ?? 0, int.tryParse(mn.group(6) ?? '0') ?? 0);
    }
  }

  final nm = RegExp(
    r'(\d{2,4})[/\-](\d{1,2})[/\-](\d{2,4})(?:[ ,]+(\d{1,2}):(\d{2})(?::(\d{2}))?)?',
  ).firstMatch(s);
  if (nm != null) {
    int a = int.parse(nm.group(1)!), b = int.parse(nm.group(2)!), c = int.parse(nm.group(3)!);
    int year, month, day;
    if (a > 31) { year = a; month = b; day = c; }
    else { day = a; month = b; year = c; }
    if (year < 100) year += 2000;
    return DateTime(year, month, day, int.tryParse(nm.group(4) ?? '0') ?? 0,
        int.tryParse(nm.group(5) ?? '0') ?? 0, int.tryParse(nm.group(6) ?? '0') ?? 0);
  }
  return null;
}