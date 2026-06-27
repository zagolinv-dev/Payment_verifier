import 'dart:ui' show Rect;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Structured data extracted from an Ethiopian payment-receipt image.
/// Supports CBE (old "transferred" + new "debited from" formats), Bank of
/// Abyssinia, Awash, and Telebirr.
class OcrResult {
  final String rawText;
  final String? amount;
  final String currency;
  final String? reference;
  final String? paymentMethod; // cbe | boa | awash | telebirr | zemen | cbe_birr | mpesa
  final String? bankName;
  final String? status; // success | pending | failed | unknown
  final String? customerName;
  final String? senderAccount;
  final String? receiverName;
  final String? receiverAccount;
  final String? date;
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
      'customer:$customerName receiver:$receiverName receiverAcct:$receiverAccount '
      'date:$date conf:${confidence.toStringAsFixed(2)})';
}

class OcrService {
  final TextRecognizer _recognizer;
  OcrService()
      : _recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  void dispose() => _recognizer.close();

  Future<OcrResult> processImage(InputImage inputImage) async {
    final recognised = await _recognizer.processImage(inputImage);
    final geom = _extractByGeometry(recognised);
    final result = parseText(recognised.text, geom: geom);
    // ignore: avoid_print
    print('[OCR] $result');
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
      customerName: _firstNonEmpty([
        _cleanName(geom['Sender Name']),
        _cleanName(geom['Source Account Name']),
        _cleanName(geom['Customer Name']),
        extractCustomerName(text, geom: geom),
      ]),
      senderAccount: _firstNonEmpty([
        geom['Sender Account'],
        geom['Source Account'],
        _cbeSenderAccount(text),
        _inlineAccount(text, _senderLabels),
      ]),
      receiverName: _firstNonEmpty([
        geom['Receiver Name'],
        geom['Transaction To'],
        geom['Beneficiary'],
        _cbeReceiverName(text),
        _inlineReceiverName(text),
      ]),
      receiverAccount: _firstNonEmpty([
        geom['Receiver Account'],
        _cbeReceiverAccount(text),
        _inlineAccount(text, _receiverLabels),
      ]),
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
      if (best != null && best.text.isNotEmpty) {
        var value = best.text.trim();
        if (best.rect != null) {
          final br = best.rect!;
          final idx = lines.indexOf(best);
          for (int i = idx + 1; i < lines.length; i++) {
            final l = lines[i];
            if (l.rect == null) break;
            if (l.rect!.top > br.bottom + br.height * 1.8) break;
            if ((l.rect!.left - br.left).abs() > br.width * 0.25) break;
            value += ' ${l.text.trim()}';
          }
        }
        fields[label] = value;
        continue;
      }
      final sameLine = labelLine.text.replaceFirst(RegExp(lc, caseSensitive: false), '').trim();
      if (sameLine.isNotEmpty) {
        var value = sameLine.replaceAll(RegExp(r'^[:,\-]+\s*'), '').trim();
        if (labelLine.rect != null) {
          final lr = labelLine.rect!;
          final idx = lines.indexOf(labelLine);
          for (int i = idx + 1; i < lines.length; i++) {
            final l = lines[i];
            if (l.rect == null) break;
            if (l.rect!.top > lr.bottom + lr.height * 1.8) break;
            if (l.rect!.left < lr.center.dx) break;
            value += ' ${l.text.trim()}';
          }
        }
        fields[label] = value;
      }
    }
    return fields;
  }

  // --- amount (principal only) -----------------------------------------------
  String? _amount(String text, Map<String, String> geom) {
    // CBE new format: "ETB 145.0 has been debited"
    final debited = RegExp(r'ETB\s*([\d,]+(?:\.\d{1,2})?)\s+has\s+been\s+debited',
            caseSensitive: false)
        .firstMatch(text);
    if (debited != null) return _money(debited.group(1));

    // CBE old format: "transferred 3000 ETB"
    final transferred = RegExp(r'transferred\s+(?:ETB\s*)?([\d,]+(?:\.\d{1,2})?)',
            caseSensitive: false)
        .firstMatch(text);
    if (transferred != null) return _money(transferred.group(1));

    // Table "Amount" cell (BOA "ETB 100.69", Awash "500 ETB")
    if (geom['Amount'] != null) {
      final v = _firstNumber(geom['Amount']!);
      if (v != null) return v;
    }
    final amtLabel = _afterLabel(text, ['Amount']);
    if (amtLabel != null) {
      final v = _firstNumber(amtLabel);
      if (v != null) return v;
    }

    // Standalone "-152.00 (ETB)" (Zemen/Telebirr style)
    final parens = RegExp(r'[-]?\s*([\d,]+\.\d{2})\s*\(?\s*ETB\s*\)?', caseSensitive: false)
        .firstMatch(text);
    if (parens != null) return _money(parens.group(1));

    // Fallback: largest amount, skipping fee/total lines
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

  // --- CBE-specific (ETB-#### account suffixes, "debited from"/"for") --------
  String? _cbeReceiverName(String text) {
    final m = RegExp(r'\bfor\s+([A-Za-z][A-Za-z .]{2,40}?)\s+ETB-?\d', caseSensitive: false)
        .firstMatch(text);
    return _cleanName(m?.group(1));
  }

  String? _cbeReceiverAccount(String text) {
    final m = RegExp(r'\bfor\s+[A-Za-z .]+?\s+ETB-?(\d{3,})', caseSensitive: false)
        .firstMatch(text);
    return m?.group(1);
  }

  String? _cbeSenderAccount(String text) {
    final m = RegExp(r'debited\s+from\s+[A-Za-z .]+?\s+ETB-?(\d{3,})', caseSensitive: false)
        .firstMatch(text);
    return m?.group(1);
  }

  // --- accounts (label-based) -------------------------------------------------
  static const _receiverLabels = ['account number', 'credited to', 'to account', 'receiver account'];
  static const _senderLabels = ['from your account', 'from account', 'debited from', 'sender account', 'source account'];

  String? _inlineAccount(String text, List<String> labels) {
    final lbl = labels.map((l) => l.split(' ').map(RegExp.escape).join(r'\s+')).join('|');
    final m = RegExp(
      '(?:$lbl)\\s*[:\\-]?\\s*([0-9][0-9*xX.\\u2022\\u25CF\\u25AA/ ]{2,}?[0-9])',
      caseSensitive: false,
    ).firstMatch(text);
    return m?.group(1)?.replaceAll(RegExp(r'\s'), '');
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
    if (t.contains('success') || t.contains('completed') ||
        t.contains('transfer successful') ||
        t.contains('scan the qr') || t.contains('the choice for all')) return 'success';
    return 'unknown';
  }

  String? _paymentMethod(String text) {
    final t = text.toLowerCase();
    if (t.contains('telebirr') || t.contains('tele birr') || t.contains('ethiotelecom')) return 'telebirr';
    if (t.contains('m-pesa') || t.contains('mpesa')) return 'mpesa';
    if (t.contains('cbe birr')) return 'cbe_birr';
    if (t.contains('awashbank') || t.contains('awash bank') || t.contains('awashbirr')) return 'awash';
    // Zemen Gebeya is the telebirr-powered marketplace
    if (t.contains('zemen') && (t.contains('gebeya') || t.contains('transaction to') || t.contains('transaction number'))) return 'telebirr';
    if (t.contains('zemen')) return 'zemen';
    if (t.contains('dashen')) return 'dashen';
    if (t.contains('bank of abyssinia') || t.contains('source account') || t.contains('the choice for all')) return 'boa';
    if (t.contains('commercial bank of ethiopia') || t.contains('rely on') ||
        (t.contains('debited') && RegExp(r'\bFT', caseSensitive: false).hasMatch(text))) return 'cbe';
    if (t.contains('abyssinia')) return 'boa';
    if (t.contains('awash')) return 'awash';
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
    if (_firstNonEmpty([geom['Receiver Account'], _cbeReceiverAccount(text),
            _inlineAccount(text, _receiverLabels)]) != null) s += 0.10;
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
    if (RegExp(r'\b(?:ETB|Birr|Amount|Debited|Total|Charge|VAT|Account|Transaction|Bank)\b',
            caseSensitive: false)
        .hasMatch(n)) return null;
    if (n.split(' ').length > 4) return null;
    return n;
  }
}

// =============================================================================
// SHARED EXTRACTORS (single source of truth)
// =============================================================================

/// FT references get I->1, O->0, S->5, B->8 OCR swaps. Fix FT-prefixed codes.
String normalizeFTReference(String ref) {
  if (ref.length >= 2 && ref.substring(0, 2).toUpperCase() == 'FT') {
    return 'FT' +
        ref.substring(2)
            .replaceAll(RegExp(r'[Il]'), '1')
            .replaceAll(RegExp(r'O', caseSensitive: false), '0')
            .replaceAll(RegExp(r'S', caseSensitive: false), '5')
            .replaceAll(RegExp(r'B', caseSensitive: false), '8')
            .toUpperCase();
  }
  return ref.toUpperCase();
}

/// Try common OCR swaps on the trailing portion of an FT reference for retry.
String alternateFTReference(String ref) {
  if (ref.length >= 2 && ref.substring(0, 2).toUpperCase() == 'FT') {
    final tail = ref.substring(2);
    return 'FT' + tail
        .replaceAll('1', 'I')
        .replaceAll('0', 'O')
        .replaceAll('5', 'S')
        .replaceAll('8', 'B')
        .toUpperCase();
  }
  return ref;
}

/// Transaction reference. Must contain a digit; full word boundary; normalized.
String? extractReference(String text, {Map<String, String> geom = const {}}) {
  bool valid(String s) =>
      RegExp(r'^(?=[A-Z0-9]*\d)[A-Z0-9]{6,}$', caseSensitive: false).hasMatch(s.trim());

  for (final k in ['Transaction Reference', 'Transaction ID', 'Transaction Number']) {
    final v = geom[k]?.trim();
    if (v != null) {
      final tok = RegExp(r'(?=[A-Z0-9]*\d)[A-Z0-9]{6,}', caseSensitive: false).firstMatch(v)?.group(0);
      if (tok != null && valid(tok)) return normalizeFTReference(tok);
    }
  }
  final labelled = RegExp(
    r'(?:Transaction\s*(?:ID|Reference|Number)|Reference|Ref)\s*[:\-#]?\s*((?=[A-Z0-9]*\d)[A-Z0-9]{6,})',
    caseSensitive: false,
  ).firstMatch(text);
  if (labelled != null) return normalizeFTReference(labelled.group(1)!);

  final ft = RegExp(r'\bFT[A-Z0-9]{6,}\b', caseSensitive: false).firstMatch(text);
  if (ft != null) return normalizeFTReference(ft.group(0)!);

  final digits = RegExp(r'\b\d{12,18}\b').firstMatch(text);
  if (digits != null) return digits.group(0);

  final generic = RegExp(r'\b(?=[A-Z0-9]*\d)[A-Z0-9]{8,18}\b', caseSensitive: false).firstMatch(text);
  return generic != null ? normalizeFTReference(generic.group(0)!) : null;
}

/// Customer/sender name across CBE (both formats), BOA, Awash, Telebirr.
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
  // CBE new format: "debited from NAME ETB-####"
  final dbt = RegExp(r'debited\s+from\s+([A-Za-z][A-Za-z .]{2,40}?)\s+ETB', caseSensitive: false)
      .firstMatch(text);
  if (dbt != null && looksLikeName(dbt.group(1)!)) {
    return dbt.group(1)!.replaceAll(RegExp(r'\s+'), ' ').trim().toUpperCase();
  }
  // CBE old format: "account <masked> NAME for/to"
  final acc = RegExp(
    r'account\b\s+[\d*xX.\u2022\u25CF\u25AA/]+\s+([A-Za-z][A-Za-z. ]{2,40}?)\s+(?:for|to)\b',
    caseSensitive: false,
  ).firstMatch(text);
  if (acc != null && looksLikeName(acc.group(1)!)) {
    return acc.group(1)!.replaceAll(RegExp(r'\s+'), ' ').trim().toUpperCase();
  }
  // Label same-line
  final lbl = RegExp(
    r'(?:Sender\s*Name|Source\s*Account\s*Name|Customer\s*Name|Payer)\s*[:\-]?\s*([A-Za-z][A-Za-z .]{2,40})',
    caseSensitive: false,
  ).firstMatch(text);
  if (lbl != null && looksLikeName(lbl.group(1)!)) {
    return lbl.group(1)!.replaceAll(RegExp(r'\s+'), ' ').trim().toUpperCase();
  }
  // Label/value on separate lines (table receipts)
  final lines = text.split('\n');
  final labelRe = RegExp(
    r'^(?:Sender\s*Name|Source\s*Account\s*Name|Customer\s*Name|Payer)\s*:?\s*$',
    caseSensitive: false,
  );
  for (int i = 0; i < lines.length - 1; i++) {
    if (labelRe.hasMatch(lines[i].trim()) && looksLikeName(lines[i + 1].trim())) {
      return lines[i + 1].trim().replaceAll(RegExp(r'\s+'), ' ').toUpperCase();
    }
  }
  return null;
}

class _Line {
  final String text;
  final Rect? rect;
  _Line(this.text, this.rect);
}