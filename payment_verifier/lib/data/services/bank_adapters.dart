import 'ocr_service.dart';
import 'verification_service.dart';

/// How a bank's receipt CAN be authoritatively confirmed (future, needs an
/// Ethiopia-hosted backend). Without that backend, the app relies on the local
/// checks in VerificationService (duplicate + fields + QR + freshness).
enum VerifyMethod { cbeLookup, boaQr, telebirrUrl, awashLookup, zemenQr, none }

class BankAdapter {
  final String id; // cbe | boa | awash | telebirr | zemen
  final String name;
  final VerifyMethod verifyMethod;
  final String? officialQrDomain; // used for in-app QR consistency check
  final bool Function(String text) detect;
  const BankAdapter({
    required this.id,
    required this.name,
    required this.verifyMethod,
    required this.detect,
    this.officialQrDomain,
  });
}

class BankRegistry {
  static final List<BankAdapter> all = [
    BankAdapter(
      id: 'telebirr',
      name: 'Telebirr',
      verifyMethod: VerifyMethod.telebirrUrl,
      officialQrDomain: 'ethiotelecom',
      detect: (t) => _has(t, ['telebirr', 'tele birr', 'ethiotelecom']),
    ),
    BankAdapter(
      id: 'awash',
      name: 'Awash Bank',
      verifyMethod: VerifyMethod.awashLookup,
      officialQrDomain: 'awash',
      detect: (t) => _has(t, ['awashbank', 'awash bank', 'awashbirr']),
    ),
    BankAdapter(
      id: 'boa',
      name: 'Bank of Abyssinia',
      verifyMethod: VerifyMethod.boaQr,
      officialQrDomain: 'abyssinia',
      detect: (t) => _has(t, ['bank of abyssinia', 'abyssinia', 'source account', 'the choice for all']),
    ),
    BankAdapter(
      id: 'cbe',
      name: 'Commercial Bank of Ethiopia',
      verifyMethod: VerifyMethod.cbeLookup,
      officialQrDomain: 'cbe.com.et',
      detect: (t) => _has(t, ['commercial bank of ethiopia', 'cbe', 'rely on']),
    ),
  ];

  static BankAdapter detect(String text) {
    final t = text.toLowerCase();
    for (final a in all) {
      if (a.detect(t)) return a;
    }
    return const BankAdapter(
      id: 'unknown', name: 'Unknown', verifyMethod: VerifyMethod.none, detect: _never);
  }

  static BankAdapter byId(String id) =>
      all.firstWhere((a) => a.id == id, orElse: () => detect(''));

  static bool _has(String t, List<String> keys) => keys.any((k) => t.contains(k));
  static bool _never(String _) => false;
}

/// OPTIONAL: backend router for when you DO get an Ethiopia-hosted server.
/// Until then, leave VerificationService.fetch = null and rely on local checks.
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
      'reference': ocr.reference == null ? null : normalizeFTReference(ocr.reference!),
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
        if (qrData == null) return const FetchResult(found: false, error: 'QR not scanned');
        break;
      case VerifyMethod.telebirrUrl:
      case VerifyMethod.awashLookup:
        break;
      case VerifyMethod.none:
        return const FetchResult(found: false, error: 'no method for this bank');
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
    final d = accounts.first.replaceAll(RegExp(r'\D'), '');
    return d.length >= 8 ? d.substring(d.length - 8) : d;
  }
}

/* ---------------------------------------------------------------------------
USAGE (no Ethiopian backend — current setup):

final ocr = await OcrService().processImage(inputImage);
// decode the receipt QR separately with mobile_scanner -> qrText (or null)

final service = VerificationService(
  config: VerifyConfig(
    expectedAmount: billTotal,                 // the café bill
    businessAccounts: ['1000774223804'],       // YOUR café account(s)
    businessName: 'Tomoca Cafe',               // optional
    freshnessWindow: Duration(hours: 24),
  ),
  // fetch: null  -> no bank lookup (no Ethiopia hosting). Local checks only.
  isDuplicate: (ref) async => await db.findUsedDate(ref), // null if unused
);

final result = await service.verify(ocr, qrData: qrText);
// result.verdict: rejected | review | looksGenuine | verified
// looksGenuine => show "Looks genuine — confirm the money landed in your account"
// On success, save result.ocr.reference (normalized) so it can't be reused.
--------------------------------------------------------------------------- */