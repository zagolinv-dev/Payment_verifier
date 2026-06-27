import 'ocr_service.dart';
import 'verification_service.dart';

/// How a given bank's receipt is authoritatively confirmed.
enum VerifyMethod {
  cbeLookup,
  boaQr,
  telebirrUrl,
  awashLookup,
  zemenQr,
  none,
}

/// One bank's profile: how to detect it and how to confirm it.
class BankAdapter {
  final String id;
  final String name;
  final VerifyMethod verifyMethod;
  final bool Function(String text) detect;
  const BankAdapter({
    required this.id,
    required this.name,
    required this.verifyMethod,
    required this.detect,
  });
}

class BankRegistry {
  static final List<BankAdapter> all = [
    BankAdapter(
      id: 'telebirr',
      name: 'Telebirr',
      verifyMethod: VerifyMethod.telebirrUrl,
      detect: (t) => _has(t, ['telebirr', 'tele birr', 'ethiotelecom']),
    ),
    BankAdapter(
      id: 'awash',
      name: 'Awash Bank',
      verifyMethod: VerifyMethod.awashLookup,
      detect: (t) => _has(t, ['awashbank', 'awash bank', 'awashbirr']),
    ),
    BankAdapter(
      id: 'zemen',
      name: 'Zemen Bank',
      verifyMethod: VerifyMethod.zemenQr,
      detect: (t) => _has(t, ['zemen']),
    ),
    BankAdapter(
      id: 'boa',
      name: 'Bank of Abyssinia',
      verifyMethod: VerifyMethod.boaQr,
      detect: (t) =>
          _has(t, ['bank of abyssinia', 'abyssinia', 'source account', 'the choice for all']),
    ),
    BankAdapter(
      id: 'cbe',
      name: 'Commercial Bank of Ethiopia',
      verifyMethod: VerifyMethod.cbeLookup,
      detect: (t) => _has(t, ['commercial bank of ethiopia', 'cbe', 'rely on']),
    ),
  ];

  static BankAdapter detect(String text) {
    final t = text.toLowerCase();
    for (final a in all) {
      if (a.detect(t)) return a;
    }
    return const BankAdapter(
      id: 'unknown',
      name: 'Unknown',
      verifyMethod: VerifyMethod.none,
      detect: _never,
    );
  }

  static bool _has(String t, List<String> keys) => keys.any((k) => t.contains(k));
  static bool _never(String _) => false;
}

/// Builds a [FetchReceipt] that routes each receipt to the right per-bank
/// verification. Call your backend endpoint per bank.
class BankFetcher {
  final String backendBaseUrl;
  final List<String> businessAccounts;
  final Future<Map<String, dynamic>> Function(String url, Map<String, dynamic> body) post;
  final String? qrData;

  BankFetcher({
    required this.backendBaseUrl,
    required this.businessAccounts,
    required this.post,
    this.qrData,
  });

  FetchReceipt get fetch => _fetch;

  Future<FetchResult> _fetch(OcrResult ocr) async {
    final adapter = BankRegistry.detect(ocr.rawText);

    final body = <String, dynamic>{
      'bank': adapter.id,
      'method': adapter.verifyMethod.name,
      'reference': ocr.reference,
      'amount': ocr.amountValue,
      'receiverAccount': ocr.receiverAccount,
      'qr': qrData,
    };

    switch (adapter.verifyMethod) {
      case VerifyMethod.cbeLookup:
        body['accountLast8'] = _last8(businessAccounts);
        break;
      case VerifyMethod.boaQr:
      case VerifyMethod.zemenQr:
        if (qrData == null) {
          return const FetchResult(found: false, error: 'QR not scanned');
        }
        break;
      case VerifyMethod.telebirrUrl:
        break;
      case VerifyMethod.awashLookup:
        break;
      case VerifyMethod.none:
        return const FetchResult(found: false, error: 'no verification method for this bank');
    }

    try {
      final res = await post('$backendBaseUrl/${adapter.id}', body);
      if (res['found'] == true) {
        return FetchResult(
          found: true,
          amount: (res['amount'] as num?)?.toDouble(),
          receiverAccount: res['receiverAccount'] as String?,
          receiverName: res['receiverName'] as String?,
        );
      }
      return FetchResult(found: false, error: res['error']?.toString() ?? 'not found');
    } catch (e) {
      return FetchResult(found: false, error: e.toString());
    }
  }

  String? _last8(List<String> accounts) {
    if (accounts.isEmpty) return null;
    final digits = accounts.first.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 8 ? digits.substring(digits.length - 8) : digits;
  }
}
