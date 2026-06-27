import 'ocr_service.dart';

/// State of a single verification step.
enum VStepState { pass, fail, review }

/// Overall verdict.
enum Verdict { verified, review, rejected }

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
  final double? expectedAmount; // the café bill total
  final List<String> businessAccounts; // your café's own account number(s), full
  final String? businessName; // optional: café registered name for receiver-name match
  final Duration freshnessWindow; // default 24h
  final double amountTolerance; // default 0.05 (5%)
  const VerifyConfig({
    this.expectedAmount,
    this.businessAccounts = const [],
    this.businessName,
    this.freshnessWindow = const Duration(hours: 24),
    this.amountTolerance = 0.05,
  });
}

/// Authoritative result from the provider lookup (your backend fetch).
class FetchResult {
  final bool found;
  final double? amount;
  final String? receiverAccount;
  final String? receiverName;
  final String? error; // non-null => couldn't confirm (timeout/network/etc.)
  const FetchResult({
    this.found = false,
    this.amount,
    this.receiverAccount,
    this.receiverName,
    this.error,
  });
}

/// Inject your backend lookup. Return found:false with an error to mean
/// "couldn't confirm" (e.g. timeout / not hosted in Ethiopia yet).
typedef FetchReceipt = Future<FetchResult> Function(OcrResult ocr);

/// Inject your DB check. Return the date it was used, or null if unused.
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
  final FetchReceipt? fetch;
  final IsDuplicate? isDuplicate;

  VerificationService({required this.config, this.fetch, this.isDuplicate});

  Future<VerifyResult> verify(OcrResult ocr) async {
    final steps = <VStep>[];
    bool hardReject = false; // clear fraud/invalid -> Rejected
    bool review = false; // unconfirmed/soft issue -> Review
    void reject() => hardReject = true;
    void needReview() => review = true;

    // 1) Payment method
    steps.add(ocr.paymentMethod != null
        ? VStep('Detect payment method', ocr.bankName ?? ocr.paymentMethod!, VStepState.pass)
        : _failR('Detect payment method', 'Unknown', needReview));

    // 2) Status = success
    if (ocr.status == 'success') {
      steps.add(const VStep('Status', 'Success', VStepState.pass));
    } else if (ocr.status == 'failed') {
      steps.add(VStep('Status', 'Failed/declined', VStepState.fail));
      reject();
    } else {
      steps.add(VStep('Status', ocr.status ?? 'unknown', VStepState.review));
      needReview();
    }

    // 3) Customer name
    steps.add(ocr.customerName != null
        ? VStep('Customer name', ocr.customerName!, VStepState.pass)
        : _failR('Customer name', 'Not found', needReview));

    // 4) Fetch receipt page (authoritative). Wrap your call in a 10s timeout.
    FetchResult fr = const FetchResult(found: false, error: 'fetch not configured');
    if (ocr.reference == null) {
      steps.add(VStep('Fetch receipt page', 'No reference', VStepState.fail));
      needReview();
    } else if (fetch == null) {
      steps.add(VStep('Fetch receipt page', 'TX ${ocr.reference} (not confirmed)', VStepState.review));
      needReview();
    } else {
      try {
        fr = await fetch!(ocr).timeout(const Duration(seconds: 10),
            onTimeout: () => const FetchResult(found: false, error: 'timeout'));
      } catch (e) {
        fr = FetchResult(found: false, error: e.toString());
      }
      if (fr.found) {
        steps.add(VStep('Fetch receipt page', 'Confirmed: ${ocr.reference}', VStepState.pass));
      } else {
        steps.add(VStep('Fetch receipt page', 'Could not confirm (${fr.error ?? "not found"})', VStepState.review));
        needReview();
      }
    }
    final bool authoritative = fr.found;

    // Use authoritative values when available, else fall back to OCR.
    final double? amount = fr.amount ?? ocr.amountValue;
    final String? receiverAcct = fr.receiverAccount ?? ocr.receiverAccount;
    final String? receiverName = fr.receiverName ?? ocr.receiverName;

    // 5) Extract amount
    steps.add(amount != null
        ? VStep('Extract amount', '${amount.toStringAsFixed(2)} ETB', VStepState.pass)
        : _failR('Extract amount', 'Not found', needReview));

    // 6) Amount match (tolerance)
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
        needReview(); // wrong amount -> owner decides (not auto-reject)
      }
    }

    // 7) Extract receiver account
    steps.add(receiverAcct != null
        ? VStep('Extract receiver account', receiverAcct, VStepState.pass)
        : _failR('Extract receiver account', 'Not found', needReview));

    // 8) Receiver account match (to the café's own account)
    if (config.businessAccounts.isEmpty) {
      steps.add(const VStep('Receiver account match', 'Business account not set', VStepState.fail));
      needReview();
    } else if (receiverAcct == null) {
      steps.add(const VStep('Receiver account match', 'No receiver account', VStepState.fail));
      needReview();
    } else if (_suffixMatch(receiverAcct, config.businessAccounts)) {
      steps.add(VStep('Receiver account match', '$receiverAcct ✓', VStepState.pass));
    } else {
      steps.add(VStep('Receiver account match', '$receiverAcct vs café account — NO match', VStepState.fail));
      reject(); // paid to someone else -> reject
    }

    // 8b) Receiver name match (optional, if café name configured + name present)
    if (config.businessName != null && receiverName != null) {
      final ok = _nameMatch(receiverName, config.businessName!);
      steps.add(VStep('Receiver name match', ok ? '$receiverName ✓' : '$receiverName ≠ ${config.businessName}',
          ok ? VStepState.pass : VStepState.review));
      if (!ok) needReview();
    }

    // 9) Transaction date
    final dt = parseReceiptDate(ocr.date);
    steps.add(dt != null
        ? VStep('Transaction date', ocr.date!, VStepState.pass)
        : _failR('Transaction date', ocr.date ?? 'Not found', needReview));

    // 10) Date freshness
    if (dt == null) {
      steps.add(const VStep('Date freshness', 'Unreadable date', VStepState.review));
      needReview();
    } else {
      final now = DateTime.now();
      if (dt.isAfter(now.add(const Duration(minutes: 2)))) {
        steps.add(VStep('Date freshness', 'Future-dated', VStepState.fail));
        reject();
      } else if (now.difference(dt) > config.freshnessWindow) {
        final h = now.difference(dt).inHours;
        steps.add(VStep('Date freshness', 'Too old (${h}h ago, max ${config.freshnessWindow.inHours}h)', VStepState.fail));
        needReview(); // stale -> owner decides
      } else {
        steps.add(const VStep('Date freshness', 'Fresh', VStepState.pass));
      }
    }

    // 11) Duplicate check
    if (ocr.reference == null) {
      steps.add(const VStep('Duplicate check', 'No reference', VStepState.fail));
      needReview();
    } else if (isDuplicate == null) {
      steps.add(const VStep('Duplicate check', 'Not checked', VStepState.review));
      needReview();
    } else {
      final usedOn = await isDuplicate!(ocr.reference!);
      if (usedOn != null) {
        steps.add(VStep('Duplicate check', 'Already used on ${_d(usedOn)}', VStepState.fail));
        reject(); // reused -> reject
      } else {
        steps.add(const VStep('Duplicate check', 'No duplicate', VStepState.pass));
      }
    }

    // Verdict
    Verdict verdict;
    if (hardReject) {
      verdict = Verdict.rejected;
    } else if (review || !authoritative) {
      verdict = Verdict.review; // not authoritatively confirmed -> needs owner
    } else {
      verdict = Verdict.verified;
    }
    steps.add(VStep('Verdict', verdict.name.toUpperCase(),
        verdict == Verdict.verified ? VStepState.pass
            : verdict == Verdict.rejected ? VStepState.fail : VStepState.review));

    // ignore: avoid_print
    print('[Verify] verdict=$verdict passed=${steps.where((s) => s.passed).length}/${steps.length}');
    return VerifyResult(steps, verdict, ocr);
  }

  // --- helpers ---------------------------------------------------------------
  VStep _failR(String name, String value, void Function() onReview) {
    onReview();
    return VStep(name, value, VStepState.fail);
  }

  /// Suffix match for masked accounts: receipt "1*****127" matches a stored
  /// full account that ends in "127" (and starts with the visible head, if any).
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

/// Parse the four receipt date formats into a DateTime.
///  "Jun 24, 2026 01:11 PM" | "19/06/2026, 21:10:59" |
///  "2026/05/28 18:24:51"   | "2026-05-04 16:24:49"
DateTime? parseReceiptDate(String? raw) {
  if (raw == null) return null;
  final s = raw.trim();

  // Month-name: Jun 24, 2026 [01:11 PM]
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

  // Numeric: dd/MM/yyyy or yyyy/MM/dd (and '-')
  final nm = RegExp(
    r'(\d{2,4})[/\-](\d{1,2})[/\-](\d{2,4})(?:[ ,]+(\d{1,2}):(\d{2})(?::(\d{2}))?)?',
  ).firstMatch(s);
  if (nm != null) {
    int a = int.parse(nm.group(1)!), b = int.parse(nm.group(2)!), c = int.parse(nm.group(3)!);
    int year, month, day;
    if (a > 31) { year = a; month = b; day = c; } // yyyy/MM/dd
    else { day = a; month = b; year = c; }        // dd/MM/yyyy
    if (year < 100) year += 2000;
    return DateTime(year, month, day, int.tryParse(nm.group(4) ?? '0') ?? 0,
        int.tryParse(nm.group(5) ?? '0') ?? 0, int.tryParse(nm.group(6) ?? '0') ?? 0);
  }
  return null;
}
