import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrResult {
  final String rawText;
  final String? extractedAmount;
  final String? extractedReference;
  final String? extractedBuyerName;
  final String? extractedBankName;
  final double confidence;

  const OcrResult({
    required this.rawText,
    this.extractedAmount,
    this.extractedReference,
    this.extractedBuyerName,
    this.extractedBankName,
    this.confidence = 0.0,
  });

  bool get hasAmount => extractedAmount != null;
  bool get hasReference => extractedReference != null;
}

class OcrService {
  final TextRecognizer _recognizer;

  OcrService() : _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  void dispose() => _recognizer.close();

  Future<OcrResult> processImage(InputImage inputImage) async {
    final recognisedText = await _recognizer.processImage(inputImage);
    final text = recognisedText.text;

    return OcrResult(
      rawText: text,
      extractedAmount: _extractAmount(text),
      extractedReference: _extractReference(text),
      extractedBuyerName: _extractBuyerName(text),
      extractedBankName: _extractBankName(text),
      confidence: _calculateConfidence(text),
    );
  }

  String? _extractAmount(String text) {
    final regex = RegExp(r'(?:ETB|Birr|Br|ብር)\s*[:\-]?\s*(\d{1,6}(?:,\d{3})*(?:\.\d{1,2})?)',
        caseSensitive: false);
    final match = regex.firstMatch(text);
    if (match != null) return match.group(1)?.replaceAll(',', '');

    final numRegex = RegExp(r'(\d{1,6}(?:,\d{3})*(?:\.\d{2})?)\s*(?:ETB|Birr|Br|ብር)',
        caseSensitive: false);
    final numMatch = numRegex.firstMatch(text);
    if (numMatch != null) return numMatch.group(1)?.replaceAll(',', '');

    return null;
  }

  String? _extractReference(String text) {
    final regex = RegExp(
      r'(?:TXN|TRX|REF|TRANS|CBE|AW|CBB)\d{6,12}',
      caseSensitive: false,
    );
    return regex.firstMatch(text)?.group(0);
  }

  String? _extractBuyerName(String text) {
    final lines = text.split('\n');
    for (int i = 0; i < lines.length && i < 5; i++) {
      final line = lines[i].trim();
      if (line.length > 3 && line.length < 50 &&
          !line.contains(RegExp(r'\d', caseSensitive: false)) &&
          !line.contains(RegExp(r'(?:receipt|payment|transfer|date|time|total|amount|ETB|Birr)',
              caseSensitive: false))) {
        return line;
      }
    }
    return null;
  }

  String? _extractBankName(String text) {
    final banks = [
      'Commercial Bank of Ethiopia', 'CBE',
      'Telebirr', 'Tele Birr',
      'CBE Birr', 'Awash Bank', 'Awash',
      'Dashen Bank', 'Bank of Abyssinia',
      'Hibret Bank', 'Wegagen Bank',
      'Nib International Bank',
    ];
    for (final bank in banks) {
      if (text.contains(RegExp(bank, caseSensitive: false))) {
        return bank;
      }
    }
    return null;
  }

  double _calculateConfidence(String text) {
    double score = 0.0;
    if (text.length > 20) score += 0.3;
    if (text.length > 50) score += 0.2;
    if (_extractAmount(text) != null) score += 0.25;
    if (_extractReference(text) != null) score += 0.25;
    return score.clamp(0.0, 1.0);
  }
}
