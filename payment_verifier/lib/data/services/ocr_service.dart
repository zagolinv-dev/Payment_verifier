import 'dart:ui' show Rect;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Structured data extracted from an Ethiopian payment-receipt image.
class OcrResult {
  final String rawText;
  final String? amount; // real transfer amount, e.g. "3000.00"
  final String currency;
  final String? reference; // transaction id, e.g. "FT26175YR1GQ"
  final String? paymentMethod; // cbe | boa | awash | zemen | telebirr | cbe_birr | mpesa
  final String? bankName;
  final String? status; // success | pending | failed | unknown
  final String? senderName;
  final String? senderAccount;
  final String? receiverName;
  final String? receiverAccount; // masked is fine: "1****888"
  final String? date; // raw date string from the receipt
  final String? transactionType;
  final double confidence;

  const OcrResult({
    required this.rawText,
    this.amount,
    this.currency = 'ETB',
    this.reference,
    this.paymentMethod,
    this.bankName,
    this.status,
    this.senderName,
    this.senderAccount,
    this.receiverName,
    this.receiverAccount,
    this.date,
    this.transactionType,
    this.confidence = 0.0,
  });

  bool get hasAmount => amount != null;
  bool get hasReference => reference != null;
  bool get isSuccess => status == 'success';
  double? get amountValue => amount == null ? null : double.tryParse(amount!);

  @override
  String toString() =>
      'OcrResult(method: $paymentMethod, status: $status, amount: $amount '
      '$currency, ref: $reference, receiverAcct: $receiverAccount, '
      'receiverName: $receiverName, date: $date, conf: '
      '${confidence.toStringAsFixed(2)})';
}

class OcrService {
  final TextRecognizer _recognizer;
  OcrService()
      : _recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  void dispose() => _recognizer.close();

  /// Full pipeline: OCR the image, then parse. Uses block geometry so that
  /// two-column table receipts (BOA, Awash) pair labels with the value on
  /// their right correctly.
  Future<OcrResult> processImage(InputImage inputImage) async {
    final recognised = await _recognizer.processImage(inputImage);
    final text = recognised.text;
    print('[OCR] RAWTEXT (${text.length} chars) >>>${text}<<<');
    final geom = _extractByGeometry(recognised);
    final result = parseText(text, geom: geom);
    final ref = result.reference;
    print('[OCR] RAWTEXT >>>${text}<<<');
    print('[OCR] chosen ref = $ref');
    return result;
  }

  /// Parse already-recognised text. `geom` is an optional label->value map
  /// from coordinate pairing. Exposed for unit testing without an image.
  OcrResult parseText(String text, {Map<String, String> geom = const {}}) {
    final method = _paymentMethod(text);
    return OcrResult(
      rawText: text,
      amount: _amount(text, geom),
      reference: _reference(text, geom),
      paymentMethod: method,
      bankName: _bankName(text),
      status: _status(text),
      senderName: _firstNonEmpty([
        geom['Sender Name'],
        geom['Source Account Name'],
        _inlineSenderName(text),
      ]),
      senderAccount: _firstNonEmpty([
        geom['Sender Account'],
        geom['Source Account'],
        _inlineAccount(text, _senderLabels),
      ]),
      receiverName: _firstNonEmpty([
        geom['Receiver Name'],
        geom['Transaction To'],
        geom['Beneficiary'],
        _inlineReceiverName(text),
      ]),
      receiverAccount: _firstNonEmpty([
        geom['Receiver Account'],
        _inlineAccount(text, _receiverLabels),
      ]),
      date: _date(text, geom),
      transactionType: geom['Transaction Type'],
      confidence: _confidence(text, geom),
    );
  }

  // ---------------------------------------------------------------------------
  // GEOMETRY PAIRING  (label on the left  ->  value on the right, same row)
  // ---------------------------------------------------------------------------
  static const List<String> _tableLabels = [
    'Amount', 'Receiver Account', 'Receiver Name', 'Source Account',
    'Source Account Name', 'Sender Account', 'Sender Name',
    'Transaction Date', 'Transaction Time', 'Transaction Reference',
    'Transaction ID', 'Transaction Number', 'Transaction To',
    'Transaction Type', 'Beneficiary', 'Reason', 'Note',
  ];

  Map<String, String> _extractByGeometry(RecognizedText rt) {
    final lines = <_Line>[];
    for (final block in rt.blocks) {
      for (final line in block.lines) {
        lines.add(_Line(line.text.trim(), line.boundingBox));
      }
    }
    final fields = <String, String>{};
    for (final label in _tableLabels) {
      final lc = label.toLowerCase();
      _Line? labelLine;
      for (final l in lines) {
        final t = l.text.toLowerCase().replaceAll(':', '').trim();
        if (t == lc || t.startsWith(lc)) {
          labelLine = l;
          break;
        }
      }
      if (labelLine?.rect == null) continue;
      final lr = labelLine!.rect!;
      final ly = lr.center.dy;
      _Line? best;
      double bestDx = double.infinity;
      for (final l in lines) {
        if (identical(l, labelLine) || l.rect == null) continue;
        final dy = (l.rect!.center.dy - ly).abs();
        if (dy > lr.height * 0.8) continue; // must be on the same row
        if (l.rect!.left < lr.right - 2) continue; // must be to the right
        final dx = l.rect!.left - lr.right;
        if (dx < bestDx) {
          bestDx = dx;
          best = l;
        }
      }
      if (best != null && best.text.isNotEmpty) fields[label] = best.text.trim();
    }
    return fields;
  }

  // ---------------------------------------------------------------------------
  // AMOUNT  (principal only — never Charge / VAT / Disaster / Total Debited)
  // ---------------------------------------------------------------------------
  String? _amount(String text, Map<String, String> geom) {
    // 1) "transferred 3000 ETB" (CBE narrative)
    final transferred = RegExp(
      r'transferred\s+(?:ETB\s*)?([\d,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    ).firstMatch(text);
    if (transferred != null) return _money(transferred.group(1));

    // 2) geometry "Amount" cell (BOA: "ETB 100.69", Awash: "500 ETB")
    if (geom['Amount'] != null) {
      final v = _firstNumber(geom['Amount']!);
      if (v != null) return v;
    }

    // 3) "Amount" label inline
    final amtLabel = _afterLabel(text, ['Amount']);
    if (amtLabel != null) {
      final v = _firstNumber(amtLabel);
      if (v != null) return v;
    }

    // 4) big standalone "-152.00 (ETB)" (Zemen)
    final parens = RegExp(
      r'[-]?\s*([\d,]+\.\d{2})\s*\(?\s*ETB\s*\)?',
      caseSensitive: false,
    ).firstMatch(text);
    if (parens != null) return _money(parens.group(1));

    // 5) fallback: largest amount, skipping fee/total lines
    final skip = RegExp(
      r'service\s*charge|charge|vat|disaster|total\s*amount\s*debited|fee|stamp',
      caseSensitive: false,
    );
    final re = RegExp(
      r'([\d,]+\.\d{2}|\d{1,3}(?:,\d{3})+|\d{3,7})\s*(?:ETB|Birr|Br)'
      r'|(?:ETB|Birr|Br)\s*[:\-]?\s*([\d,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    );
    double? best;
    for (final line in text.split('\n')) {
      if (skip.hasMatch(line)) continue;
      for (final m in re.allMatches(line)) {
        final raw = (m.group(1) ?? m.group(2))?.replaceAll(',', '');
        final val = double.tryParse(raw ?? '');
        if (val != null && val > 0 && (best == null || val > best!)) best = val;
      }
    }
    return best?.toStringAsFixed(2);
  }

  // ---------------------------------------------------------------------------
  // REFERENCE / TRANSACTION ID
  // ---------------------------------------------------------------------------
  String? _reference(String text, Map<String, String> geom) {
    // 1) Geometry — value was paired from a table receipt cell
    for (final k in ['Transaction Reference', 'Transaction ID',
        'Transaction Number']) {
      if (geom[k] != null && _isValidRef(geom[k]!)) {
        return _toUpperRef(geom[k]!);
      }
    }
    // 2) Shared extractor on full text handles label + fallback patterns
    final ref = extractReference(text);
    if (ref != null) {
      print('[OCR] extractReference found ref=$ref');
    }
    return ref;
  }

  /// Quick validation: must contain at least one digit, 6+ total chars.
  bool _isValidRef(String s) =>
      RegExp(r'^(?=[A-Z0-9]*\d)[A-Z0-9]{6,}$', caseSensitive: false).hasMatch(s.trim());

  String _toUpperRef(String s) => s.trim().toUpperCase();

  // ---------------------------------------------------------------------------
  // ACCOUNTS  (masked values like 1****888 or 01347******0700 are fine)
  // ---------------------------------------------------------------------------
  static const _receiverLabels = ['account number', 'credited to', 'to account'];
  static const _senderLabels = ['from your account', 'from account', 'debited from'];

  String? _inlineAccount(String text, List<String> labels) {
    final lbl = labels.map(RegExp.escape).join('|');
    final m = RegExp(
      '(?:$lbl)\\s*[:\\-]?\\s*([0-9][0-9*xX.\\u2022/]{2,}[0-9])',
      caseSensitive: false,
    ).firstMatch(text);
    return m?.group(1);
  }

  String? _inlineReceiverName(String text) {
    final m = RegExp(
      r'\bfor\s+([A-Z][A-Za-z .]{2,40}?)\s+with\b',
      caseSensitive: false,
    ).firstMatch(text);
    return m?.group(1)?.trim();
  }

  String? _inlineSenderName(String text) {
    final m = RegExp(
      r'from\s*(?:your\s*)?account\s+[0-9*xX.\u2022/]+\s+([A-Z][A-Za-z .]{2,40}?)\s+(?:for|with)\b',
      caseSensitive: false,
    ).firstMatch(text);
    return m?.group(1)?.trim();
  }

  // ---------------------------------------------------------------------------
  // DATE
  // ---------------------------------------------------------------------------
  String? _date(String text, Map<String, String> geom) {
    final fromLabel = geom['Transaction Date'] ??
        geom['Transaction Time'] ??
        _afterLabel(text, ['Transaction Date', 'Transaction Time', 'Date']);
    final search = fromLabel ?? text;

    final monthName = RegExp(
      r'\b([A-Z][a-z]{2,8}\s+\d{1,2},?\s+\d{4}(?:[ ,]+\d{1,2}:\d{2}(?::\d{2})?\s*[APap]?\.?[Mm]?\.?)?)',
    ).firstMatch(search);
    if (monthName != null) return monthName.group(1)?.trim();

    final numeric = RegExp(
      r'\b(\d{2,4}[/\-]\d{1,2}[/\-]\d{1,4}(?:[ ,]+\d{1,2}:\d{2}(?::\d{2})?\s*[APap]?[Mm]?)?)',
    ).firstMatch(search);
    return numeric?.group(1)?.trim();
  }

  // ---------------------------------------------------------------------------
  // STATUS / METHOD / BANK
  // ---------------------------------------------------------------------------
  String _status(String text) {
    final t = text.toLowerCase();
    if (t.contains('fail') || t.contains('declined') || t.contains('unsuccess')) {
      return 'failed';
    }
    if (t.contains('pending') || t.contains('processing')) return 'pending';
    if (t.contains('success') || t.contains('successful') ||
        t.contains('completed') || t.contains('transfer successful')) {
      return 'success';
    }
    return 'unknown';
  }

  String? _paymentMethod(String text) {
    final t = text.toLowerCase();
    if (t.contains('telebirr') || t.contains('tele birr')) return 'telebirr';
    if (t.contains('m-pesa') || t.contains('mpesa')) return 'mpesa';
    if (t.contains('cbe birr')) return 'cbe_birr';
    if (t.contains('awash')) return 'awash';
    if (t.contains('zemen')) return 'zemen';
    if (t.contains('dashen')) return 'dashen';
    if (t.contains('source account') || t.contains('the choice for all')) {
      return 'boa';
    }
    if (t.contains('transferred') &&
        (t.contains('commercial bank of ethiopia') || t.contains('rely on'))) {
      return 'cbe';
    }
    if (t.contains('commercial bank of ethiopia')) return 'cbe';
    if (t.contains('abyssinia')) return 'boa';
    return null;
  }

  static const List<String> _banks = [
    'Commercial Bank of Ethiopia', 'CBE Birr', 'CBE', 'Telebirr', 'Tele Birr',
    'Awash Bank', 'Awash', 'Dashen Bank', 'Bank of Abyssinia', 'Abyssinia',
    'Zemen Bank', 'Zemen', 'Hibret Bank', 'Wegagen Bank',
    'Nib International Bank', 'M-Pesa', 'Mpesa',
  ];

  String? _bankName(String text) {
    for (final b in _banks) {
      if (RegExp(RegExp.escape(b), caseSensitive: false).hasMatch(text)) return b;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // CONFIDENCE
  // ---------------------------------------------------------------------------
  double _confidence(String text, Map<String, String> geom) {
    double s = 0.0;
    if (text.length > 30) s += 0.15;
    if (_amount(text, geom) != null) s += 0.30;
    if (_reference(text, geom) != null) s += 0.30;
    if (_firstNonEmpty([geom['Receiver Account'],
            _inlineAccount(text, _receiverLabels)]) != null) {
      s += 0.10;
    }
    if (_date(text, geom) != null) s += 0.10;
    if (_status(text) == 'success') s += 0.05;
    return s.clamp(0.0, 1.0);
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------
  String? _afterLabel(String text, List<String> labels) {
    final lines = text.split('\n');
    final lbl = labels.map(RegExp.escape).join('|');
    final re = RegExp('^\\s*(?:$lbl)\\s*[:\\-]?\\s*(.*)\$', caseSensitive: false);
    for (int i = 0; i < lines.length; i++) {
      final m = re.firstMatch(lines[i]);
      if (m != null) {
        var v = (m.group(1) ?? '').trim();
        if (v.isEmpty && i + 1 < lines.length) v = lines[i + 1].trim();
        if (v.isNotEmpty) return v;
      }
    }
    return null;
  }

  String? _firstNumber(String s) {
    final m = RegExp(r'([\d,]+(?:\.\d{1,2})?)').firstMatch(s);
    return _money(m?.group(1));
  }

  String? _money(String? raw) {
    if (raw == null) return null;
    final v = double.tryParse(raw.replaceAll(',', ''));
    return v?.toStringAsFixed(2);
  }

  String? _firstNonEmpty(List<String?> xs) {
    for (final x in xs) {
      if (x != null && x.trim().isNotEmpty) return x.trim();
    }
    return null;
  }
}

/// ---------------------------------------------------------------------------
/// Standalone shared reference extractor.
/// Use this from anywhere — OcrService calls it, screens can too.
/// Returns null when no valid reference is found.
/// ---------------------------------------------------------------------------
String? extractReference(String text) {
  // 1) Labelled value (Transaction ID / Transaction Reference / Ref: ...)
  //    Must capture a group-1 that contains a digit.
  final labelled = RegExp(
    r'(?:Transaction\s*(?:ID|Reference|Number)|Reference|Ref)\s*[:\-#]?\s*((?=[A-Z0-9]*\d)[A-Z0-9]{6,})',
    caseSensitive: false,
  ).firstMatch(text);
  if (labelled != null) return labelled.group(1)!.toUpperCase();

  // 2) FT-prefixed ID (CBE / BOA)
  final ft = RegExp(r'\bFT[A-Z0-9]{6,}\b', caseSensitive: false)
      .firstMatch(text);
  if (ft != null) return ft.group(0)!.toUpperCase();

  // 3) Long all-digit ID (Awash 12-18 digits)
  final longDigits = RegExp(r'\b\d{12,18}\b')
      .firstMatch(text);
  if (longDigits != null) return longDigits.group(0)!;

  // 4) Generic alphanumeric, 8-18 chars, must contain a digit
  final generic = RegExp(r'\b(?=[A-Z0-9]*\d)[A-Z0-9]{8,18}\b', caseSensitive: false)
      .firstMatch(text);
  if (generic != null) return generic.group(0)!.toUpperCase();

  return null;
}

class _Line {
  final String text;
  final Rect? rect;
  _Line(this.text, this.rect);
}

/* ---------------------------------------------------------------------------
QUICK TESTS (paste into a file with main(); no images needed).
These use the text path; real images additionally use geometry pairing.

void main() {
  final ocr = OcrService();

  const cbe = '''
You have sucessfully transferred 3000 ETB from your account 1********2693 Arsema
Tewodros Mulugeta for ARSEMA TEWODROS MULUGETA with Bank of Abyssinia account
number 1*****127 . on Jun 24, 2026 01:11 PM with Transaction ID: FT26175YR1GQ.
Total Amount Debited: 3073.80 ETB with Service Charge of ETB62.00, VAT (15%) of
ETB9.30 and Disaster Recovery (5%) of ETB2.50. Commercial Bank of Ethiopia
''';

  const boa = '''
Bank of Abyssinia
Source Account: 1****127
Source Account Name: ARSEMA TEWODROS MULUGETA
Amount: ETB 100.69
Receiver Account: 1****888
Receiver Name: GEDION KIFLE
Transaction Date: 19/06/2026, 21:10:59
Transaction Reference: FT26171F1WV3
Transaction Type: Other Bank Transfer
Scan the QR to Verify  The Choice For All!
''';

  const zemen = '''
Successful
-152.00 (ETB)
Transaction Time: 2026/05/28 18:24:51
Transaction Type: Transfer Money
Transaction To: Petros
Transaction Number: DES7F4Z4N1
ZemenGebeya
''';

  const awash = '''
AwashBank  Transfer successful
Transaction Date: 2026-05-04 16:24:49
Transaction Type: Send To Bank
Amount: 500 ETB
Charge: 1.00 ETB
VAT: 0.15 ETB
Sender Account: 01320******200/BANK
Receiver Account: 01347******0700
Transaction ID: 260504162425282
Thank you for using AwashBirr Pro
''';

  for (final s in [cbe, boa, zemen, awash]) {
    print(ocr.parseText(s));
  }
  // Expect:
  // cbe   -> amount 3000.00, ref FT26175YR1GQ, receiverAcct 1*****127, method cbe
  // boa   -> amount 100.69,  ref FT26171F1WV3, receiverAcct 1****888, method boa
  // zemen -> amount 152.00,  ref DES7F4Z4N1,  receiverName Petros,   method zemen
  // awash -> amount 500.00,  ref 260504162425282, receiverAcct 01347******0700
}
--------------------------------------------------------------------------- */