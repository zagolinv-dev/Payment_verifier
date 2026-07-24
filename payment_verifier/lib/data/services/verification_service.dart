import 'ocr_service.dart';

enum StepState { pass, fail }

enum Verdict { verified, tryAgain, failed }

extension VerdictLabel on Verdict {
  String get label {
    switch (this) {
      case Verdict.verified:
        return 'VERIFIED';
      case Verdict.tryAgain:
        return 'TRY AGAIN';
      case Verdict.failed:
        return 'FAILED';
    }
  }
}

class VStep {
  final String name;
  final String value;
  final StepState state;
  const VStep(this.name, this.value, this.state);
  bool get passed => state == StepState.pass;
}

class VerifyConfig {
  final double? expectedAmount;
  final List<String> businessAccounts;
  final String? selectedBank;
  final int attemptCount;
  final int maxAttempts;
  final String? ocrDetectedBank;
  final int maxAgeDays;
  final int maxAgeMinutes;
  final String? expectedCustomerName;
  final String? expectedReceiverName;

  const VerifyConfig({
    this.expectedAmount,
    this.businessAccounts = const [],
    this.selectedBank,
    this.attemptCount = 0,
    this.maxAttempts = 3,
    this.ocrDetectedBank,
    this.maxAgeDays = 7,
    this.maxAgeMinutes = 15,
    this.expectedCustomerName,
    this.expectedReceiverName,
  });
}

typedef IsDuplicate = Future<DateTime?> Function(String reference);

class VerifyResult {
  final List<VStep> steps;
  final Verdict verdict;
  final OcrResult ocr;
  final String dateElapsed;
  VerifyResult(this.steps, this.verdict, this.ocr, this.dateElapsed);
  int get passedCount => steps.where((s) => s.passed).length;

  String get status {
    switch (verdict) {
      case Verdict.verified:
        return 'Verified';
      case Verdict.tryAgain:
        return 'Suspicious';
      case Verdict.failed:
        return 'Rejected';
    }
  }
}

class VerificationService {
  final VerifyConfig config;
  final IsDuplicate? isDuplicate;

  VerificationService({required this.config, this.isDuplicate});

  String _elapsed(DateTime receiptDt, DateTime scanDt) {
    final diff = scanDt.difference(receiptDt);
    if (diff.isNegative) return '${diff.inMinutes.abs()} min in the future';
    if (diff.inDays > 0) {
      return '${diff.inDays}d ${diff.inHours.remainder(24)}h ${diff.inMinutes.remainder(60)}m ago';
    }
    if (diff.inHours > 0) {
      return '${diff.inHours}h ${diff.inMinutes.remainder(60)}m ago';
    }
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }

  Future<VerifyResult> verify(OcrResult ocr, {DateTime? scanTime}) async {
    final steps = <VStep>[];
    final failures = <String>[];
    final now = scanTime ?? DateTime.now();

    final String? ref = ocr.reference == null ? null : normalizeFTReference(ocr.reference!);

    // 1) Payment method match (detected vs selected)
    final detected = ocr.paymentMethod;
    final selected = config.selectedBank;
    final resolvedBank = selected ?? detected;

    if (detected != null && selected != null) {
      final match = _methodMatches(detected, selected);
      if (match) {
        steps.add(VStep('Payment method', '$selected ✓', StepState.pass));
      } else {
        steps.add(VStep('Payment method', 'Detected: $detected, Selected: $selected', StepState.fail));
        failures.add('Payment method mismatch');
      }
    } else if (detected != null) {
      // No bank was manually selected; trust what OCR detected
      steps.add(VStep('Payment method', 'Detected: $detected ✓', StepState.pass));
    } else if (selected != null) {
      // OCR couldn't read a bank name, but the user explicitly selected one — trust the selection
      steps.add(VStep('Payment method', '$selected (user selected)', StepState.pass));
    } else {
      steps.add(const VStep('Payment method', 'Not detected', StepState.fail));
      failures.add('Payment method not detected');
    }

    // 2) Customer name / Receiver name match
    final isTelebirr = _isTelebirr(resolvedBank);
    if (isTelebirr) {
      final receiverName = ocr.receiverName;
      final expectedReceiver = config.expectedReceiverName;
      if (receiverName == null || receiverName.isEmpty) {
        // Telebirr table receipt may not expose payer/receiver name — skip
        steps.add(const VStep('Receiver name', 'N/A (not on receipt)', StepState.pass));
      } else if (expectedReceiver != null) {
        final match = _namesMatch(receiverName, expectedReceiver);
        if (match) {
          steps.add(VStep('Receiver name match', '$receiverName ✓', StepState.pass));
        } else {
          steps.add(VStep('Receiver name match', 'Extracted: $receiverName, Expected: $expectedReceiver', StepState.fail));
          failures.add('Receiver name mismatch');
        }
      } else {
        steps.add(VStep('Receiver name', receiverName, StepState.pass));
      }
    } else {
      final customerName = ocr.customerName;
      final expectedCustomer = config.expectedCustomerName;
      if (customerName != null && customerName.isNotEmpty) {
        if (expectedCustomer != null && expectedCustomer.isNotEmpty) {
          final match = _namesMatch(customerName, expectedCustomer);
          if (match) {
            steps.add(VStep('Customer name match', '$customerName ✓', StepState.pass));
          } else {
            steps.add(VStep('Customer name match', 'Extracted: $customerName, Expected: $expectedCustomer', StepState.fail));
            failures.add('Customer name mismatch');
          }
        } else {
          steps.add(VStep('Customer name', customerName, StepState.pass));
        }
      } else if (expectedCustomer != null && expectedCustomer.isNotEmpty) {
        // Expected but not found
        steps.add(const VStep('Customer name', 'Not found', StepState.fail));
        failures.add('Customer name not found');
      } else {
        // Neither extracted nor expected — skip rather than fail
        steps.add(const VStep('Customer name', 'Not provided', StepState.pass));
      }
    }

    // 3) Extract amount
    final amount = ocr.amountValue;
    if (amount != null) {
      steps.add(VStep('Extract amount', '${amount.toStringAsFixed(2)} ETB', StepState.pass));
    } else {
      steps.add(VStep('Extract amount', 'Not found', StepState.fail));
      failures.add('Amount not found');
    }

    // 4) Amount match (order total vs actual amount paid)
    if (config.expectedAmount == null) {
      steps.add(const VStep('Amount match', 'No order total entered', StepState.fail));
      failures.add('No order total');
    } else if (amount == null) {
      steps.add(const VStep('Amount match', 'No amount to compare', StepState.fail));
      failures.add('No receipt amount');
    } else if (amount < config.expectedAmount!) {
      steps.add(VStep('Amount match',
          'Paid ${amount.toStringAsFixed(2)} < Expected ${config.expectedAmount!.toStringAsFixed(2)}',
          StepState.fail));
      failures.add('Amount less than order total');
    } else {
      steps.add(VStep('Amount match',
          '${amount.toStringAsFixed(2)} ≥ ${config.expectedAmount!.toStringAsFixed(2)} ✓',
          StepState.pass));
    }

    // 5) Transaction ID / Reference
    if (ref != null && ref.isNotEmpty) {
      steps.add(VStep('Transaction ID', ref, StepState.pass));
    } else {
      steps.add(const VStep('Transaction ID', 'Not found', StepState.fail));
      failures.add('Transaction ID not found');
    }

    // 6) Extract receiver account
    final receiverAcct = ocr.receiverAccount;
    if (receiverAcct != null && receiverAcct.isNotEmpty) {
      steps.add(VStep('Extract receiver account', receiverAcct, StepState.pass));
    } else if (isTelebirr) {
      // Telebirr table receipts don't show an account number — skip
      steps.add(const VStep('Extract receiver account', 'N/A (Telebirr)', StepState.pass));
    } else {
      // For other banks (e.g. CBE) — skip rather than fail if no account visible on receipt
      steps.add(const VStep('Extract receiver account', 'N/A (not on receipt)', StepState.pass));
    }

    // 7) Receiver account match (compare with business accounts)
    if (receiverAcct == null || receiverAcct.isEmpty) {
      // No account extracted from receipt — skip match entirely
      steps.add(const VStep('Account match', 'Skipped (no account on receipt)', StepState.pass));
    } else if (isTelebirr) {
      if (config.businessAccounts.isEmpty) {
        steps.add(const VStep('Account match', 'No business accounts saved', StepState.fail));
        failures.add('Business accounts not set');
      } else if (_suffixMatch(receiverAcct, config.businessAccounts) ||
          _phoneMatch(receiverAcct, config.businessAccounts)) {
        steps.add(VStep('Account match', '$receiverAcct ✓', StepState.pass));
      } else {
        steps.add(VStep('Account match', '$receiverAcct ≠ your accounts', StepState.fail));
        failures.add('Account not yours');
      }
    } else if (config.businessAccounts.isEmpty) {
      steps.add(const VStep('Account match', 'No business accounts saved', StepState.fail));
      failures.add('Business accounts not set');
    } else if (_suffixMatch(receiverAcct, config.businessAccounts)) {
      steps.add(VStep('Account match', '$receiverAcct ✓', StepState.pass));
    } else {
      steps.add(VStep('Account match', '$receiverAcct ≠ your accounts', StepState.fail));
      failures.add('Account not yours');
    }

    // 8) Date & freshness check — receipt must be within 15 minutes
    String dateElapsed = 'Unknown';
    String freshness = '';
    final dt = parseReceiptDate(ocr.date);
    if (dt != null) {
      dateElapsed = _elapsed(dt, now);
      final diff = now.difference(dt);
      final ageMinutes = diff.inMinutes;
      if (diff.isNegative) {
        // Receipt timestamp is in the future — likely a forged/future-dated receipt
        final futureMins = diff.inMinutes.abs();
        freshness = 'Receipt is $futureMins min in the future';
        steps.add(VStep('Transaction date', 'Future date — $dateElapsed', StepState.fail));
        failures.add(freshness);
      } else if (ageMinutes > config.maxAgeMinutes) {
        freshness = 'Receipt is ${ageMinutes}m old (max ${config.maxAgeMinutes}m)';
        steps.add(VStep('Transaction date', 'Too old — $dateElapsed', StepState.fail));
        failures.add(freshness);
      } else {
        steps.add(VStep('Transaction date', '$dateElapsed ✓', StepState.pass));
      }
    } else {
      steps.add(VStep('Transaction date', ocr.date ?? 'Not found', StepState.fail));
      failures.add('Date not found');
    }

    // 9) Duplicate check
    if (ref == null) {
      steps.add(const VStep('Duplicate check', 'No reference', StepState.fail));
      failures.add('No reference');
    } else if (isDuplicate == null) {
      steps.add(const VStep('Duplicate check', 'Not checked', StepState.fail));
      failures.add('Duplicate check unavailable');
    } else {
      final usedOn = await isDuplicate!(ref);
      if (usedOn != null) {
        final elapsed = _elapsed(usedOn, now);
        steps.add(VStep('Duplicate check', 'Already used ($elapsed)', StepState.fail));
        failures.add('Duplicate reference');
      } else {
        steps.add(const VStep('Duplicate check', 'No duplicate ✓', StepState.pass));
      }
    }

    // Verdict
    Verdict verdict;
    if (failures.isEmpty) {
      verdict = Verdict.verified;
    } else {
      verdict = Verdict.failed;
    }

    return VerifyResult(steps, verdict, ocr, dateElapsed);
  }

  bool _namesMatch(String name1, String name2) {
    final n1 = name1.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), '').split(' ').where((w) => w.length > 1).toSet();
    final n2 = name2.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), '').split(' ').where((w) => w.length > 1).toSet();
    if (n1.isEmpty || n2.isEmpty) {
      final clean1 = name1.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      final clean2 = name2.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      return clean1 == clean2 || clean1.contains(clean2) || clean2.contains(clean1);
    }
    final intersection = n1.intersection(n2);
    if (intersection.isNotEmpty) return true;
    
    final clean1 = name1.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final clean2 = name2.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return clean1.contains(clean2) || clean2.contains(clean1);
  }

  String _canonicalBank(String name) {
    final n = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), '');
    if (n.contains('cbe') || n.contains('commercial') || n.contains('rely on') || n.contains('negid')) return 'cbe';
    if (n.contains('boa') || n.contains('abyssinia') || n.contains('abysinia') || n.contains('abysina') || n.contains('the choice for all') || n.contains('scan the qr')) {
      return 'boa';
    }
    if (n.contains('awash') || n.contains('awashbirr')) return 'awash';
    if (n.contains('telebirr') || n.contains('tellebirr') || n.contains('telebir') ||
        n.contains('tele birr') || n.contains('telle birr') ||
        n.contains('ethiotelecom') || n.contains('ethio telecom') ||
        n.contains('etelebirr') || n.contains('e telebirr') ||
        n.contains('zemen') || n.contains('ethiotelecom')) {
      return 'telebirr';
    }
    // Map "Commercial Bank of Ethiopia" display name
    if (n.contains('commercial bank of ethiopia')) return 'cbe';
    return n;
  }

  bool _methodMatches(String detected, String selected) {
    return _canonicalBank(detected) == _canonicalBank(selected);
  }

  bool _isTelebirr(String? bank) =>
      bank != null && _canonicalBank(bank) == 'telebirr';

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

  bool _phoneMatch(String extracted, List<String> businessAccounts) {
    // Normalize a phone number to its last 9 digits (Ethiopian numbers are 9 digits after country code)
    String norm(String raw) {
      var d = raw.replaceAll(RegExp(r'\D'), '');
      // Strip leading 251 (country code)
      if (d.startsWith('251') && d.length >= 12) d = d.substring(3);
      // Strip leading 0
      if (d.startsWith('0') && d.length == 10) d = d.substring(1);
      // Return last 9 digits
      return d.length >= 9 ? d.substring(d.length - 9) : d;
    }

    final exNorm = norm(extracted);
    if (exNorm.length < 7) return false;

    for (final acct in businessAccounts) {
      final acctNorm = norm(acct);
      if (acctNorm.isEmpty) continue;
      if (exNorm == acctNorm) return true;
      // Partial match — one contains the other
      if (exNorm.endsWith(acctNorm) || acctNorm.endsWith(exNorm)) return true;
    }
    return false;
  }
}

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