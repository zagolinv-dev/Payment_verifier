import 'dart:ui' show Rect;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Structured data extracted from an Ethiopian payment-receipt image.
class OcrResult {
  final String rawText;
  final String? amount; // principal transfer amount, e.g. "3000.00"
  final String currency;
  final String? reference; // transaction id, e.g. "FT26175YR1GQ"
  final String? paymentMethod; // cbe | boa | awash | zemen | telebirr | cbe_birr | mpesa
  final String? bankName;
  final String? status; // success | pending | failed | unknown
  final String? customerName; // sender / payer name
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
    this.customerName,
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
      'OcrResult(method:$paymentMethod status:$status amount:$amount ref:$reference '
      'customer:$customerName receiverAcct:$receiverAccount date:$date '
      'conf:${confidence.toStringAsFixed(2)})';
}

class OcrService {
  final TextRecognizer _recognizer;
  OcrService()
      : _recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  void dispose() => _recognizer.close();

  Future<OcrResult> processImage(InputImage inputImage) async {
    final recognised = await _recognizer.processImage(inputImage);
    final text = recognised.text;
    final geom = _extractByGeometry(recognised);
    final result = parseText(text, geom: geom);
    // ignore: avoid_print
    print('[OCR] ${result.toString()}');
    return result;
  }

  OcrResult parseText(String text, {Map<String, String> geom = const {}}) {
    return OcrResult(
      rawText: text,
      amount: _amount(text, geom),
      reference: extractReference(text, geom: geom),
      paymentMethod: _paymentMethod(text),
      bankName: _bankName(text),
      status: _status(text),
      // Geometry-based table layout (BOA, Awash). BOA labels the sender as
      // "Source Account Name". Try geometry first, then the regex fallback.
      customerName: _firstNonEmpty([
        _cleanName(geom['Sender Name']),
        _cleanName(geom['Source Account Name']),
        _cleanName(geom['Customer Name']),
        extractCustomerName(text.replaceAll('\n', ' '), geom: geom),
      ]),
      senderAccount: _firstNonEmpty(
          [geom['Sender Account'], geom['Source Account'], _inlineAccount(text, _senderLabels)]),
      receiverName: _firstNonEmpty([
        geom['Receiver Name'],
        geom['Transaction To'],
        geom['Beneficiary'],
        _inlineReceiverName(text),
      ]),
      receiverAccount: _firstNonEmpty([geom['Receiver Account'], _inlineAccount(text, _receiverLabels)]),
      date: _date(text, geom),
      transactionType: geom['Transaction Type'],
      confidence: _confidence(text, geom),
    );
  }

  // --- geometry pairing for two-column tables (BOA, Awash) -------------------
  static const List<String> _tableLabels = [
    'Amount', 'Receiver Account', 'Receiver Name', 'Source Account',
    'Source Account Name', 'Sender Account', 'Sender Name', 'Transaction Date',
    'Transaction Time', 'Transaction Reference', 'Transaction ID',
    'Transaction Number', 'Transaction To', 'Transaction Type', 'Beneficiary',
    'Reason', 'Note',
  ];

  Map<String, String> _extractByGeometry(RecognizedText rt) {
    final lines = <_Line>[];
    for (final b in rt.blocks) {
      for (final l in b.lines) {
        lines.add(_Line(l.text.trim(), l.boundingBox));
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
      _Line? best;
      double bestDx = double.infinity;
      for (final l in lines) {
        if (identical(l, labelLine) || l.rect == null) continue;
        if ((l.rect!.center.dy - lr.center.dy).abs() > lr.height * 0.8) continue;
        if (l.rect!.left < lr.right - 2) continue;
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

  // --- amount (principal only) -----------------------------------------------
  String? _amount(String text, Map<String, String> geom) {
    final transferred = RegExp(r'transferred\s+(?:ETB\s*)?([\d,]+(?:\.\d{1,2})?)',
            caseSensitive: false)
        .firstMatch(text);
    if (transferred != null) return _money(transferred.group(1));

    if (geom['Amount'] != null) {
      final v = _firstNumber(geom['Amount']!);
      if (v != null) return v;
    }
    final amtLabel = _afterLabel(text, ['Amount']);
    if (amtLabel != null) {
      final v = _firstNumber(amtLabel);
      if (v != null) return v;
    }
    final parens = RegExp(r'[-]?\s*([\d,]+\.\d{2})\s*\(?\s*ETB\s*\)?', caseSensitive: false)
        .firstMatch(text);
    if (parens != null) return _money(parens.group(1));

    final skip = RegExp(
        r'service\s*charge|charge|vat|disaster|total\s*amount\s*debited|fee|stamp',
        caseSensitive: false);
    final re = RegExp(
        r'([\d,]+\.\d{2}|\d{1,3}(?:,\d{3})+|\d{3,7})\s*(?:ETB|Birr|Br)'
        r'|(?:ETB|Birr|Br)\s*[:\-]?\s*([\d,]+(?:\.\d{1,2})?)',
        caseSensitive: false);
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

  // --- accounts (flexible whitespace; strips spaces inside the value) --------
  static const _receiverLabels = ['account number', 'credited to', 'to account', 'receiver account'];
  static const _senderLabels = ['from your account', 'from account', 'debited from', 'sender account', 'source account'];

  String? _inlineAccount(String text, List<String> labels) {
    final lbl = labels.map((l) => l.split(' ').map(RegExp.escape).join(r'\s+')).join('|');
    final m = RegExp(
      '(?:$lbl)\\s*[:\\-]?\\s*([0-9][0-9*xX.\\u2022\\u25CF\\u25AA/ ]{2,}?[0-9])',
      caseSensitive: false,
    ).firstMatch(text);
    final raw = m?.group(1);
    return raw?.replaceAll(RegExp(r'\s'), '');
  }

  String? _inlineReceiverName(String text) {
    final m = RegExp(r'\bfor\s+([A-Za-z][A-Za-z .]{2,40}?)\s+with\b', caseSensitive: false)
        .firstMatch(text);
    return _cleanName(m?.group(1));
  }

  // --- date -------------------------------------------------------------------
  String? _date(String text, Map<String, String> geom) {
    final search = geom['Transaction Date'] ??
        geom['Transaction Time'] ??
        _afterLabel(text, ['Transaction Date', 'Transaction Time', 'Date']) ??
        text;
    final mn = RegExp(
            r'\b([A-Z][a-z]{2,8}\s+\d{1,2},?\s+\d{4}(?:[ ,]+\d{1,2}:\d{2}(?::\d{2})?\s*[APap]?\.?[Mm]?\.?)?)')
        .firstMatch(search);
    if (mn != null) return mn.group(1)?.trim();
    final num = RegExp(
            r'\b(\d{2,4}[/\-]\d{1,2}[/\-]\d{1,4}(?:[ ,]+\d{1,2}:\d{2}(?::\d{2})?\s*[APap]?[Mm]?)?)')
        .firstMatch(search);
    return num?.group(1)?.trim();
  }

  // --- status / method / bank -------------------------------------------------
  String _status(String text) {
    final t = text.toLowerCase();
    if (t.contains('fail') || t.contains('declined') || t.contains('unsuccess')) return 'failed';
    if (t.contains('pending') || t.contains('processing')) return 'pending';
    if (t.contains('success') || t.contains('completed')) return 'success';
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
    if (t.contains('source account') || t.contains('the choice for all')) return 'boa';
    if (t.contains('transferred') &&
        (t.contains('commercial bank of ethiopia') || t.contains('rely on'))) return 'cbe';
    if (t.contains('commercial bank of ethiopia')) return 'cbe';
    if (t.contains('abyssinia')) return 'boa';
    return null;
  }

  static const List<String> _banks = [
    'Commercial Bank of Ethiopia', 'CBE Birr', 'CBE', 'Telebirr', 'Tele Birr',
    'Awash Bank', 'Awash', 'Dashen Bank', 'Bank of Abyssinia', 'Abyssinia',
    'Zemen Bank', 'Zemen', 'Hibret Bank', 'Wegagen Bank', 'Nib International Bank',
    'M-Pesa', 'Mpesa',
  ];

  String? _bankName(String text) {
    for (final b in _banks) {
      if (RegExp(RegExp.escape(b), caseSensitive: false).hasMatch(text)) return b;
    }
    return null;
  }

  double _confidence(String text, Map<String, String> geom) {
    double s = 0;
    if (text.length > 30) s += 0.15;
    if (_amount(text, geom) != null) s += 0.30;
    if (extractReference(text, geom: geom) != null) s += 0.30;
    if (_firstNonEmpty([geom['Receiver Account'], _inlineAccount(text, _receiverLabels)]) != null) s += 0.10;
    if (_date(text, geom) != null) s += 0.10;
    if (_status(text) == 'success') s += 0.05;
    return s.clamp(0.0, 1.0);
  }

  // --- helpers ----------------------------------------------------------------
  String? _afterLabel(String text, List<String> labels) {
    final lines = text.split('\n');
    final lbl = labels.map((l) => l.split(' ').map(RegExp.escape).join(r'\s+')).join('|');
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

  String? _firstNumber(String s) => _money(RegExp(r'([\d,]+(?:\.\d{1,2})?)').firstMatch(s)?.group(1));
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

  String? _cleanName(String? s) {
    if (s == null) return null;
    final n = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (n.length < 3 || n.length > 40) return null;
    if (RegExp(r'[\d:]').hasMatch(n)) return null;
    if (RegExp(r'\b(?:ETB|Birr|Amount|Debited|Total|Charge|VAT|Account|Transaction)\b',
            caseSensitive: false)
        .hasMatch(n)) return null;
    if (n.split(' ').length > 4) return null;
    return n;
  }
}

// =============================================================================
// SHARED EXTRACTORS  (call these from anywhere — single source of truth)
// =============================================================================

/// Transaction reference. Must contain a digit; captured to full word boundary.
String? extractReference(String text, {Map<String, String> geom = const {}}) {
  bool valid(String s) =>
      RegExp(r'^(?=[A-Z0-9]*\d)[A-Z0-9]{6,}$', caseSensitive: false).hasMatch(s.trim());

  for (final k in ['Transaction Reference', 'Transaction ID', 'Transaction Number']) {
    final v = geom[k]?.trim();
    if (v != null) {
      final tok = RegExp(r'(?=[A-Z0-9]*\d)[A-Z0-9]{6,}', caseSensitive: false).firstMatch(v)?.group(0);
      if (tok != null && valid(tok)) return tok.toUpperCase();
    }
  }
  final labelled = RegExp(
    r'(?:Transaction\s*(?:ID|Reference|Number)|Reference|Ref)\s*[:\-#]?\s*((?=[A-Z0-9]*\d)[A-Z0-9]{6,})',
    caseSensitive: false,
  ).firstMatch(text);
  if (labelled != null) return labelled.group(1)!.toUpperCase();

  final ft = RegExp(r'\bFT[A-Z0-9]{6,}\b', caseSensitive: false).firstMatch(text);
  if (ft != null) return ft.group(0)!.toUpperCase();

  final digits = RegExp(r'\b\d{12,18}\b').firstMatch(text);
  if (digits != null) return digits.group(0);

  final generic = RegExp(r'\b(?=[A-Z0-9]*\d)[A-Z0-9]{8,18}\b', caseSensitive: false).firstMatch(text);
  return generic?.group(0)?.toUpperCase();
}

/// Customer/sender name. Stops at "for"; rejects digits/keywords/long strings.
String? extractCustomerName(String text, {Map<String, String> geom = const {}}) {
  bool looksLikeName(String s) {
    final n = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (n.length < 3 || n.length > 40) return false;
    if (RegExp(r'[\d:]').hasMatch(n)) return false;
    if (RegExp(r'\b(?:ETB|Birr|Amount|Debited|Total|Charge|VAT|Account|Transaction|Bank)\b',
            caseSensitive: false)
        .hasMatch(n)) return false;
    if (n.split(' ').length > 4) return false;
    return true;
  }

  for (final k in ['Sender Name', 'Source Account Name']) {
    final v = geom[k];
    if (v != null && looksLikeName(v)) return v.replaceAll(RegExp(r'\s+'), ' ').trim().toUpperCase();
  }
  // CBE narrative: "...account <masked> NAME for ..."  (stop at "for")
  final m = RegExp(
    r'account\b[\s\d*xX.\u2022\u25CF\u25AA/]+\s+([A-Za-z][A-Za-z. ]{2,40}?)\s+for\b',
    caseSensitive: false,
  ).firstMatch(text);
  if (m != null && looksLikeName(m.group(1)!)) {
    return m.group(1)!.replaceAll(RegExp(r'\s+'), ' ').trim().toUpperCase();
  }
  final lbl = RegExp(
    r'(?:Sender\s*Name|Source\s*Account\s*Name|Customer\s*Name|Payer)\s*[:\-]?\s*([A-Za-z][A-Za-z .]{2,40})',
    caseSensitive: false,
  ).firstMatch(text);
  if (lbl != null && looksLikeName(lbl.group(1)!)) {
    return lbl.group(1)!.replaceAll(RegExp(r'\s+'), ' ').trim().toUpperCase();
  }
  return null;
}

class _Line {
  final String text;
  final Rect? rect;
  _Line(this.text, this.rect);
}
