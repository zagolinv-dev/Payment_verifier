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
    // ignore: avoid_print
    print('[OCR RAW]\n${recognised.text}');
    // ignore: avoid_print
    print('[OCR GEOM] $geom');
    return result;
  }

  OcrResult parseText(String text, {Map<String, String> geom = const {}}) {
    final bank = _paymentMethod(text);

    // For BOA and CBE, prefer text-based name extraction over geometry
    // because geometry often mis-pairs columns in two-column receipt layouts.
    final String? customerName;
    if (bank == 'boa' || bank == 'cbe') {
      customerName = extractCustomerName(text, geom: geom, bank: bank);
    } else {
      customerName = _firstNonEmpty([
        _cleanName(geom['Sender Name']),
        _cleanName(geom['Source Account Name']),
        _cleanName(geom['Sender Account Name']),
        _cleanName(geom['Customer Name']),
        _cleanName(geom['Payer Name']),
        _cleanName(geom['Payer']),
        extractCustomerName(text, geom: geom, bank: bank),
        _telebirrPayerName(text, bank),
      ]);
    }

    return OcrResult(
      rawText: text,
      amount: _amount(text, geom),
      reference: extractReference(text, geom: geom),
      paymentMethod: bank,
      bankName: _bankName(text),
      status: _status(text),
      customerName: customerName,
      senderAccount: _firstNonEmpty([
        geom['Sender Account'],
        geom['Source Account'],
        geom['Payer Account'],
        geom['Debit Account'],
        geom['From Account'],
        _cbeSenderAccount(text),
        _inlineAccount(text, _senderLabels),
      ]),
      receiverName: _firstNonEmpty([
        _cleanName(geom['Receiver Name']),
        _cleanName(geom['Beneficiary Name']),
        _cleanName(geom['Transfer To Name']),
        _cleanName(geom['Transaction To']),
        _cleanName(geom['Beneficiary']),
        _cleanName(geom['Merchant Name']),
        _cleanName(geom['Credited Party Name']),
        _cleanName(geom['Credited To Name']),
        _boaReceiverName(text),
        _cbeReceiverName(text),
        _telebirrReceiverName(text),
        _inlineReceiverName(text),
      ]),
      receiverAccount: _firstNonEmpty([
        geom['Receiver Account'],
        geom['Beneficiary Account'],
        geom['Credit Account'],
        geom['To Account'],
        geom['Transfer To Account'],
        geom['Credited Party Account'],
        geom['Credited To Account'],
        _telebirrReceiverAccount(text),
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
    // Payer / Sender fields
    'Source Account Name',
    'Source Account',
    'Sender Account Name',
    'Sender Account',
    'Sender Name',
    'Payer Name',
    'Payer Account',
    'Payer',
    'Debit Account',
    'From Account',
    'Customer Name',
    'From Your Account',

    // Receiver / Beneficiary fields
    'Receiver Account',
    'Receiver Name',
    'Beneficiary Account',
    'Beneficiary Name',
    'Beneficiary',
    'Credit Account',
    'To Account',
    'Transfer To Account',
    'Transfer To Name',
    'Transfer To',
    'Transaction To',
    'Credited To Name',
    'Credited To Account',
    'Credited To',
    'Credited Party Name',
    'Credited Party Account',
    'Merchant Name',

    // Transaction Details
    'Amount',
    'Transaction Date',
    'Transaction Time',
    'Transaction Reference',
    'Transaction ID',
    'Transaction Number',
    'Transaction Type',
    'Reason',
    'Note',
  ];

  Map<String, String> _extractByGeometry(RecognizedText rt) {
    final lines = <_Line>[];
    for (final b in rt.blocks) {
      for (final l in b.lines) {
        lines.add(_Line(l.text.trim(), l.boundingBox));
      }
    }
    final fields = <String, String>{};
    final matchedLines = <_Line>{};
    for (final label in _tableLabels) {
      final lc = label.toLowerCase();
      _Line? labelLine;
      for (final l in lines) {
        if (matchedLines.contains(l)) continue;
        final t = l.text.toLowerCase().replaceAll(':', '').trim();
        if (t == lc || t.startsWith(lc)) {
          labelLine = l;
          matchedLines.add(l);
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
        var value = sameLine;
        value = value.replaceFirst(RegExp(r'^(?:name|account|no|number|num|#)\b\s*[:\-]?\s*', caseSensitive: false), '').trim();
        value = value.replaceAll(RegExp(r'^[:,\-\s]+'), '').trim();
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
    // Telebirr / wallet labelled amounts
    final teleLabelled = RegExp(
      r'(?:transaction\s+amount|amount\s+paid|total\s+amount|paid\s+amount|transferred\s+amount)\s*[:\-]?\s*(?:ETB\s*)?([\d,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    ).firstMatch(text);
    if (teleLabelled != null) return _money(teleLabelled.group(1));

    final telePaid = RegExp(
      r'(?:you\s+have\s+)?(?:paid|transferred|sent)\s+(?:ETB\s*)?([\d,]+(?:\.\d{1,2})?)\s*(?:ETB|Birr)?\s+to\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (telePaid != null) return _money(telePaid.group(1));

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
        if (val != null && val > 0 && (best == null || val > best)) best = val;
      }
    }
    return best?.toStringAsFixed(2);
  }

  // --- CBE-specific (ETB-#### account suffixes, "debited from"/"for") --------
  String? _boaReceiverName(String text) {
    final lines = text.split('\n');
    for (int i = 0; i < lines.length - 1; i++) {
      if (RegExp(
        r'^(?:receiver\s+(?:account\s+)?name|beneficiary\s+name|transfer\s+to\s+name|credited\s+(?:party\s+)?name)\s*:?\s*$',
        caseSensitive: false,
      ).hasMatch(lines[i].trim())) {
        final name = _cleanName(lines[i + 1]);
        if (name != null) return name;
      }
    }
    final sameLine = RegExp(
      r'(?:Receiver\s+(?:Account\s+)?Name|Beneficiary\s+Name|Transfer\s+To\s+Name|Credited\s+(?:Party\s+)?Name)\s*[:\-]?\s*([A-Za-z][A-Za-z .]{2,60}?)'
      r'(?=\s+(?:Receiver|Amount|Transaction|Sender|Source|Account|\d)|\s*$)',
      caseSensitive: false,
    ).firstMatch(text);
    return _cleanName(sameLine?.group(1));
  }

  String? _cbeReceiverName(String text) {
    final m = RegExp(r'\bfor\s+([A-Za-z][A-Za-z .]{2,40}?)\s+ETB-?\d', caseSensitive: false)
        .firstMatch(text);
    if (m != null) return _cleanName(m.group(1));

    final m2 = RegExp(
      r'(?:beneficiary\s+name|receiver\s+name|transfer\s+to\s+name|credited\s+to\s+name|to\s+name)\s*[:\-]?\s*([A-Za-z][A-Za-z .]{2,40}?)',
      caseSensitive: false,
    ).firstMatch(text);
    return _cleanName(m2?.group(1));
  }

  String? _cbeReceiverAccount(String text) {
    final m = RegExp(r'\bfor\s+[A-Za-z .]+?\s+ETB-?(\d{3,})', caseSensitive: false)
        .firstMatch(text);
    if (m != null) return m.group(1);

    final m2 = RegExp(
      r'(?:beneficiary\s+account|receiver\s+account|credit\s+account|to\s+account|transfer\s+to\s+account)\s*[:\-]?\s*([0-9*xX\u2022\u25CF\u25AA]{6,})',
      caseSensitive: false,
    ).firstMatch(text);
    return m2?.group(1)?.replaceAll(RegExp(r'\s+'), '');
  }

  String? _cbeSenderAccount(String text) {
    final m = RegExp(r'debited\s+from\s+[A-Za-z .]+?\s+ETB-?(\d{3,})', caseSensitive: false)
        .firstMatch(text);
    if (m != null) return m.group(1);

    final m2 = RegExp(
      r'(?:from\s+your\s+account|from\s+account|debit\s+account|payer\s+account|sender\s+account)\s*[:\-]?\s*([0-9*xX\u2022\u25CF\u25AA]{6,})',
      caseSensitive: false,
    ).firstMatch(text);
    return m2?.group(1)?.replaceAll(RegExp(r'\s+'), '');
  }

  String? _telebirrReceiverName(String text) {
    final m0 = RegExp(
      r'(?:paid|transferred|sent)\s+(?:ETB\s*)?[\d,]+(?:\.\d{1,2})?\s*(?:ETB|Birr)?\s+to\s+([A-Za-z0-9][A-Za-z0-9 .&]{2,50}?)(?:\s*\(|\s+successful|\s+on\b)',
      caseSensitive: false,
    ).firstMatch(text);
    if (m0 != null) return _cleanName(m0.group(1));

    final m1 = RegExp(r'\bto\s+([A-Za-z0-9][A-Za-z0-9 .&]{2,40}?)\s*(?:\([^)]*\))?\s+successful', caseSensitive: false)
        .firstMatch(text);
    if (m1 != null) return _cleanName(m1.group(1));

    final m2 = RegExp(r'\b(?:transfer|transaction)\s+to\s+([A-Za-z0-9][A-Za-z0-9 .&]{2,40}?)\b', caseSensitive: false)
        .firstMatch(text);
    if (m2 != null) return _cleanName(m2.group(1));

    final m3 = RegExp(
      r'(?:credited\s+party\s+name|merchant\s+name|receiver\s+name)\s*[:\-]?\s*([A-Za-z][A-Za-z .]{2,40}?)',
      caseSensitive: false,
    ).firstMatch(text);
    if (m3 != null) return _cleanName(m3.group(1));

    return null;
  }

  String? _telebirrPayerName(String text, String? bank) {
    if (bank != 'telebirr' && bank != 'cbe_birr') return null;

    final dear = RegExp(r'\bdear\s+([A-Za-z][A-Za-z .]{2,40}?)[,!\n]', caseSensitive: false)
        .firstMatch(text);
    if (dear != null) return _cleanName(dear.group(1));

    final debited = RegExp(
      r'(?:debited\s+party\s+name|payer\s+name|sender\s+name|from\s+name)\s*[:\-]?\s*([A-Za-z][A-Za-z .]{2,40}?)',
      caseSensitive: false,
    ).firstMatch(text);
    if (debited != null) return _cleanName(debited.group(1));

    return null;
  }

  String? _telebirrReceiverAccount(String text) {
    final labelled = RegExp(
      r'(?:credited\s+party\s+account|receiver\s+account|beneficiary\s+account|to\s+account|merchant\s+account)\s*[:\-]?\s*((?:\+?251|0)?9\d{8})',
      caseSensitive: false,
    ).firstMatch(text);
    if (labelled != null) return _normalizePhone(labelled.group(1));

    final inParens = RegExp(r'\((\+?251|0)?9\d{8,9}\)').firstMatch(text);
    if (inParens != null) return _normalizePhone(inParens.group(0)?.replaceAll(RegExp(r'[()]'), ''));

    final bare = RegExp(r'\b((?:\+?251|0)?9\d{8})\b').firstMatch(text);
    return _normalizePhone(bare?.group(1));
  }

  String? _normalizePhone(String? raw) {
    if (raw == null) return null;
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('251') && digits.length >= 12) {
      digits = '0${digits.substring(3)}';
    }
    if (digits.length == 9 && digits.startsWith('9')) digits = '0$digits';
    return digits.length >= 10 ? digits : null;
  }

  // --- accounts (label-based) -------------------------------------------------
  static const _receiverLabels = [
    'receiver account', 'beneficiary account', 'beneficiary account number',
    'credit account', 'to account', 'credited to', 'account number', 'receiver account number'
  ];
  static const _senderLabels = [
    'from your account', 'from account', 'debited from', 'sender account', 'source account',
    'debit account', 'payer account', 'sender account number', 'source account number'
  ];

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
    if (t.contains('telebirr') || t.contains('tellebirr') || t.contains('telebir') ||
        t.contains('tele birr') || t.contains('telle birr') ||
        t.contains('ethiotelecom') || t.contains('ethio telecom') ||
        t.contains('etelebirr') || t.contains('e-telebirr')) return 'telebirr';
    if (t.contains('m-pesa') || t.contains('mpesa')) return 'mpesa';
    if (t.contains('cbe birr')) return 'cbe_birr';
    if (t.contains('awashbank') || t.contains('awash bank') || t.contains('awashbirr')) return 'awash';
    if (t.contains('nib international') || t.contains('nib bank') || t.contains('nib ')) {
      return 'nib';
    }
    // Zemen Gebeya is the telebirr-powered marketplace
    if (t.contains('zemen') && (t.contains('gebeya') || t.contains('transaction to') || t.contains('transaction number'))) {
      return 'telebirr';
    }
    if (t.contains('zemen bank') || t.contains('zemen')) return 'zemen';
    if (t.contains('dashen')) return 'dashen';
    if (t.contains('bank of abyssinia') || t.contains('source account') || t.contains('the choice for all') || t.contains('abyssinia') || t.contains('abysinia') || t.contains('abysina')) return 'boa';
    if (t.contains('commercial bank of ethiopia') || t.contains('rely on') || t.contains('negid') ||
        (t.contains('debited') && RegExp(r'\bFT', caseSensitive: false).hasMatch(text))) return 'cbe';
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
    return cleanAndValidateName(s);
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

  // 1) Geometry table lookup
  for (final k in ['Transaction Reference', 'Transaction ID', 'Transaction Number',
                   'Receipt No', 'Receipt Number', 'Voucher No', 'Voucher Number', 'Ref No']) {
    final v = geom[k]?.trim();
    if (v != null) {
      final tok = RegExp(r'(?=[A-Z0-9]*\d)[A-Z0-9]{6,}', caseSensitive: false).firstMatch(v)?.group(0);
      if (tok != null && valid(tok)) return normalizeFTReference(tok);
    }
  }

  // 2) Label same-line: "Transaction ID: 12345" etc
  final labelled = RegExp(
    r'(?:Transaction\s*(?:ID|Reference|Number|No|Code)|Receipt\s*(?:No|Number|Code|ID)|'
    r'Voucher\s*(?:No|Number)|Ref\s*(?:No|Number|Code|ID)|Reference)\s*[:\-#]?\s*'
    r'((?=[A-Z0-9]*\d)[A-Z0-9]{6,})',
    caseSensitive: false,
  ).firstMatch(text);
  if (labelled != null) return normalizeFTReference(labelled.group(1)!);

  // 3) Label on one line, value on next line
  final lines = text.split('\n');
  final labelRe = RegExp(
    r'^(?:Transaction\s*(?:ID|Reference|Number|No|Code)|Receipt\s*(?:No|Number|Code|ID)|'
    r'Voucher\s*(?:No|Number)|Ref\s*(?:No|Number|Code|ID)|Reference)\s*:?\s*$',
    caseSensitive: false,
  );
  for (int i = 0; i < lines.length - 1; i++) {
    if (labelRe.hasMatch(lines[i].trim())) {
      final val = lines[i + 1].trim();
      final tok = RegExp(r'(?=[A-Z0-9]*\d)[A-Z0-9]{6,}', caseSensitive: false).firstMatch(val)?.group(0);
      if (tok != null && valid(tok)) return normalizeFTReference(tok);
    }
  }

  // 4) FT-prefixed codes
  final ft = RegExp(r'\bFT[A-Z0-9]{6,}\b', caseSensitive: false).firstMatch(text);
  if (ft != null) return normalizeFTReference(ft.group(0)!);

  // 5) Pure digits 8+ chars (Ethiopian refs are often 10-14 digits)
  final digits = RegExp(r'\b\d{8,20}\b').firstMatch(text);
  if (digits != null) return digits.group(0);

  // 6) Fallback: generic alphanumeric 8+ chars containing at least one digit
  final generic = RegExp(r'\b(?=[A-Z0-9]*\d)[A-Z0-9]{8,20}\b', caseSensitive: false).firstMatch(text);
  if (generic != null) return normalizeFTReference(generic.group(0)!);

  // 7) Desperate fallback: any consecutive digits 6+ chars
  final anyDigits = RegExp(r'\b\d{6,}\b').firstMatch(text);
  return anyDigits?.group(0);
}

/// Customer/sender name across CBE, BOA, Awash, Telebirr, and other banks.
/// Pass [bank] (e.g. 'cbe', 'boa', 'telebirr') for bank-specific extraction logic.
bool _looksLikeName(String s) {
  final n = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (n.length < 3 || n.length > 60) return false;
  if (RegExp(r'\d').hasMatch(n)) return false;
  if (RegExp(r'\b(?:ETB|Birr|Amount|Debited|Total|Charge|VAT|Transaction|Status)\b',
          caseSensitive: false)
      .hasMatch(n)) return false;
  if (n.split(' ').length > 5) return false;
  return true;
}

String? cleanAndValidateName(String? raw) {
  if (raw == null) return null;
  // Strip leading non-alphabetic/noise characters
  var n = raw.replaceFirst(RegExp(r'^[^A-Za-z]+'), '').trim();
  // Strip trailing numbers, parentheses, colons, slashes, or other garbage
  n = n.replaceFirst(RegExp(r'[^A-Za-z\s.]+$'), '').trim();
  n = n.replaceAll(RegExp(r'\s+'), ' ');
  if (_looksLikeName(n)) return n.toUpperCase();
  
  final cleaned = n.replaceAll(
    RegExp(r'\s+(?:Account|Bank|Name|Number|Ref|Reference|ID|Date|Time|Type|Note|Status)\s*\S*$',
        caseSensitive: false),
    '',
  ).trim();
  if (_looksLikeName(cleaned)) return cleaned.toUpperCase();
  return null;
}



/// Customer/sender name across CBE, BOA, Awash, Telebirr, and other banks.
/// Pass [bank] (e.g. 'cbe', 'boa', 'telebirr') for bank-specific extraction logic.
String? extractCustomerName(String text,
    {Map<String, String> geom = const {}, String? bank}) {
  String? tryName(String? raw) => cleanAndValidateName(raw);

  final lines = text.split('\n');

  // ── BOA: text-only, skip geometry (geometry mis-pairs two-column layout) ──
  if (bank == 'boa') {
    // ML Kit reads the right-column values WITHOUT labels, in order:
    // [values from rows: Source Account Name value, Source Account value,
    //  Amount, Receiver Account value, Receiver Name value, ...]
    // The sender name may be split: "ARSEMA TEWODROS" / "1****127" / "MULUGETA"
    // So we look for a masked account number and combine the lines around it.

    for (int i = 0; i < lines.length; i++) {
      final t = lines[i].trim();
      // A masked/partial account number line (digits and stars, 4-12 chars)
      if (RegExp(r'^[\d*xX\u2022\u25CF\u25AA/]{4,12}$').hasMatch(t)) {
        // Lines immediately before and after the account number form the name
        final before = i > 0 ? lines[i - 1].trim() : '';
        final after  = i + 1 < lines.length ? lines[i + 1].trim() : '';

        // Only treat as sender account if line before looks like a name part
        if (before.isNotEmpty && RegExp(r'^[A-Za-z .&]+$').hasMatch(before)) {
          // Combine before + after if after also looks like a name part
          final combined = (after.isNotEmpty && RegExp(r'^[A-Za-z .&]+$').hasMatch(after))
              ? '$before $after'
              : before;
          final n = tryName(combined);
          if (n != null) return n;
          // fallback: just the before part alone
          final n2 = tryName(before);
          if (n2 != null) return n2;
        }
      }
    }

    // Fallback: label-based scan (for receipts that DO include labels)
    for (int i = 0; i < lines.length; i++) {
      if (RegExp(
        r'^(?:source\s+account\s+name|sender\s+(?:account\s+)?name|payer\s+name|debit\s+account\s+name)',
        caseSensitive: false,
      ).hasMatch(lines[i].trim())) {
        final afterLabel = lines[i].trim().replaceFirst(
          RegExp(r'^(?:source\s+account\s+name|sender\s+(?:account\s+)?name|payer\s+name|debit\s+account\s+name)\s*[:\-]?\s*',
              caseSensitive: false),
          '',
        ).trim();
        if (afterLabel.isNotEmpty && !RegExp(r'^\d').hasMatch(afterLabel)) {
          var combined = afterLabel;
          if (i + 1 < lines.length) {
            final nxt = lines[i + 1].trim();
            if (RegExp(r'^[A-Za-z .&]+$').hasMatch(nxt) &&
                !RegExp(r'^(?:receiver|amount|transaction|bank|note)',
                    caseSensitive: false).hasMatch(nxt)) {
              combined = '$combined $nxt';
            }
          }
          final n = tryName(combined);
          if (n != null) return n;
        } else if (i + 1 < lines.length) {
          final next = lines[i + 1].trim();
          if (RegExp(r'^[\d*xX\u2022\u25CF\u25AA/]{4,}$').hasMatch(next) && i + 2 < lines.length) {
            final n = tryName(lines[i + 2].trim());
            if (n != null) return n;
          } else {
            var combined = next;
            if (i + 2 < lines.length) {
              final nxt = lines[i + 2].trim();
              if (RegExp(r'^[A-Za-z .&]+$').hasMatch(nxt) &&
                  !RegExp(r'^(?:receiver|amount|transaction|bank|note)',
                      caseSensitive: false).hasMatch(nxt)) {
                combined = '$next $nxt';
              }
            }
            final n = tryName(combined);
            if (n != null) return n;
          }
        }
      }
    }
    return null;
  }

  // ── CBE / Negid ─────────────────────────────────────────────────────────
  if (bank == 'cbe') {
    // Negid SMS format: "ETB X debited from SENDER NAME for RECEIVER NAME-ETB-ACCT"
    final dbt = RegExp(
      r'debited\s+from\s+([A-Za-z][A-Za-z .]{2,50}?)\s+for\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (dbt != null) {
      final n = tryName(dbt.group(1)?.trim());
      if (n != null) return n;
    }

    // CBE receipt format: "From Your Account ****2693 NAME" on one line
    for (final line in lines) {
      final m = RegExp(
        r'from\s+(?:your\s+)?account\s*[:\-]?\s*[\d*xX\u2022\u25CF\u25AA/]+\s+([A-Za-z].+)',
        caseSensitive: false,
      ).firstMatch(line);
      if (m != null) {
        final n = tryName(m.group(1)?.trim());
        if (n != null) return n;
      }
    }

    // "From Your Account" on one line, masked account on next, name after
    for (int i = 0; i < lines.length; i++) {
      if (!RegExp(r'from\s+(?:your\s+)?account', caseSensitive: false).hasMatch(lines[i])) continue;
      for (int j = i; j < lines.length && j <= i + 4; j++) {
        if (!RegExp(r'[\d*xX\u2022\u25CF\u25AA/]{4,}').hasMatch(lines[j])) continue;
        for (int k = j + 1; k <= j + 3 && k < lines.length; k++) {
          final n = tryName(lines[k]);
          if (n != null) return n;
        }
        break;
      }
    }

    // Explicit label patterns
    for (int i = 0; i < lines.length - 1; i++) {
      if (RegExp(
        r'^(?:account\s*holder(?:\s*name)?|sender\s*name|payer\s*name|customer\s*name|account\s*name)\s*:?\s*$',
        caseSensitive: false,
      ).hasMatch(lines[i].trim())) {
        final n = tryName(lines[i + 1]);
        if (n != null) return n;
      }
    }
    final lblRe = RegExp(
      r'(?:account\s*holder(?:\s*name)?|sender\s*name|payer\s*name|customer\s*name)\s*[:\-]?\s*([A-Za-z][^\n]{2,50})',
      caseSensitive: false,
    ).firstMatch(text);
    if (lblRe != null) {
      final n = tryName(lblRe.group(1));
      if (n != null) return n;
    }
    return null;
  }

  // ── Telebirr ────────────────────────────────────────────────────────────
  if (bank == 'telebirr' || bank == 'cbe_birr') {
    final dear = RegExp(r'\bdear\s+([A-Za-z][A-Za-z .]{2,40}?)[,!\n]', caseSensitive: false)
        .firstMatch(text);
    if (dear != null) {
      final n = tryName(dear.group(1));
      if (n != null) return n;
    }
    final lbl = RegExp(
      r'(?:debited\s+party\s+name|payer\s+name|sender\s+name|from\s+name)\s*[:\-]?\s*([^\n]+)',
      caseSensitive: false,
    ).firstMatch(text);
    if (lbl != null) {
      final n = tryName(lbl.group(1));
      if (n != null) return n;
    }
    return null;
  }

  // ── Zemen / NIB ─────────────────────────────────────────────────────────
  if (bank == 'zemen' || bank == 'nib') {
    for (int i = 0; i < lines.length - 1; i++) {
      if (RegExp(
        r'^(?:sender\s*name|payer\s*name|source\s*account\s*name|debit\s*account\s*name|from\s*name)\s*:?\s*$',
        caseSensitive: false,
      ).hasMatch(lines[i].trim())) {
        final n = tryName(lines[i + 1]);
        if (n != null) return n;
      }
    }
    final senderLine = RegExp(
      r'(?:sender\s*name|payer\s*name|source\s*account\s*name|debit\s*account\s*name|from\s*name)\s*[:\-]?\s*([^\n]+)',
      caseSensitive: false,
    ).firstMatch(text);
    if (senderLine != null) {
      final n = tryName(senderLine.group(1));
      if (n != null) return n;
    }
    return null;
  }

  // ── Awash ────────────────────────────────────────────────────────────────
  if (bank == 'awash') {
    for (int i = 0; i < lines.length - 1; i++) {
      if (RegExp(
        r'^(?:sender\s*name|payer\s*name|source\s*account\s*name|debit\s*account\s*name)\s*:?\s*$',
        caseSensitive: false,
      ).hasMatch(lines[i].trim())) {
        final n = tryName(lines[i + 1]);
        if (n != null) return n;
      }
    }
    final sameLine = RegExp(
      r'(?:sender\s*name|payer\s*name|source\s*account\s*name|debit\s*account\s*name)\s*[:\-]?\s*([^\n]+)',
      caseSensitive: false,
    ).firstMatch(text);
    if (sameLine != null) {
      final n = tryName(sameLine.group(1));
      if (n != null) return n;
    }
    // Geometry fallback for Awash
    for (final k in ['Sender Name', 'Source Account Name', 'Customer Name', 'Payer Name']) {
      final v = geom[k];
      if (v != null) {
        final n = tryName(v);
        if (n != null) return n;
      }
    }
    return null;
  }

  // ── Generic fallback for other banks ────────────────────────────────────
  for (final k in ['Sender Name', 'Source Account Name', 'Customer Name', 'Payer Name', 'Payer']) {
    final v = geom[k];
    if (v != null) {
      final n = tryName(v);
      if (n != null) return n;
    }
  }
  final lbl = RegExp(
    r'(?:sender\s*name|source\s*account\s*name|customer\s*name|payer)\s*[:\-]?\s*([^\n]+)',
    caseSensitive: false,
  ).firstMatch(text);
  if (lbl != null) {
    final n = tryName(lbl.group(1));
    if (n != null) return n;
  }
  return null;
}

class _Line {
  final String text;
  final Rect? rect;
  _Line(this.text, this.rect);
}