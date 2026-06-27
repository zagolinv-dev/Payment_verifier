import 'ocr_service.dart';

class BankAdapter {
  final String id;
  final String name;
  final bool Function(String text) detect;
  const BankAdapter({
    required this.id,
    required this.name,
    required this.detect,
  });
}

class BankRegistry {
  static final List<BankAdapter> all = [
    BankAdapter(
      id: 'telebirr',
      name: 'Telebirr',
      detect: (t) => _has(t, ['telebirr', 'tele birr', 'ethiotelecom']),
    ),
    BankAdapter(
      id: 'awash',
      name: 'Awash Bank',
      detect: (t) => _has(t, ['awashbank', 'awash bank', 'awashbirr']),
    ),
    BankAdapter(
      id: 'boa',
      name: 'Bank of Abyssinia',
      detect: (t) => _has(t, ['bank of abyssinia', 'abyssinia', 'source account', 'the choice for all']),
    ),
    BankAdapter(
      id: 'cbe',
      name: 'Commercial Bank of Ethiopia',
      detect: (t) => _has(t, ['commercial bank of ethiopia', 'cbe', 'rely on']),
    ),
  ];

  static BankAdapter detect(String text) {
    final t = text.toLowerCase();
    for (final a in all) {
      if (a.detect(t)) return a;
    }
    return const BankAdapter(
      id: 'unknown', name: 'Unknown', detect: _never);
  }

  static BankAdapter byId(String id) =>
      all.firstWhere((a) => a.id == id, orElse: () => detect(''));

  static bool _has(String t, List<String> keys) => keys.any((k) => t.contains(k));
  static bool _never(String _) => false;
}
