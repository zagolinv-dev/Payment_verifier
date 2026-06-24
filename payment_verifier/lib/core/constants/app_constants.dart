/// T's Pay — Application-wide Constants
library;

class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = "T's Pay";
  static const String appTagline = 'Ethiopian Payments Simplified';
  static const String appVersion = '1.0.0';

  // Currency
  static const String currency = 'ETB';
  static const String currencySymbol = 'Br';

  // Supabase Table Names
  static const String profilesTable = 'profiles';
  static const String transactionsTable = 'transactions';
  static const String bankAccountsTable = 'bank_accounts';

  // SharedPreferences Keys
  static const String onboardingDoneKey = 'onboarding_done';
}

enum BankName {
  cbe('Commercial Bank of Ethiopia', 'CBE'),
  telebirr('Telebirr', 'Telebirr'),
  cbeBirr('CBE Birr', 'CBE Birr'),
  awash('Awash Bank', 'Awash');

  const BankName(this.displayName, this.shortName);
  final String displayName;
  final String shortName;

  static BankName fromString(String value) {
    return BankName.values.firstWhere(
      (e) => e.displayName == value || e.shortName == value,
      orElse: () => BankName.cbe,
    );
  }
}

enum TransactionStatus {
  pending('PENDING'),
  verified('VERIFIED'),
  failed('FAILED');

  const TransactionStatus(this.value);
  final String value;

  static TransactionStatus fromString(String value) {
    return TransactionStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => TransactionStatus.pending,
    );
  }
}

enum UserRole {
  admin('ADMIN'),
  waitress('WAITRESS');

  const UserRole(this.value);
  final String value;

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (e) => e.value == value,
      orElse: () => UserRole.waitress,
    );
  }
}

/// Payment reference regex validators by bank
class PaymentValidators {
  PaymentValidators._();

  static final Map<BankName, RegExp> referencePatterns = {
    BankName.cbe: RegExp(r'^FT\d{12}$'),
    BankName.telebirr: RegExp(r'^TLB\d{8}$'),
    BankName.cbeBirr: RegExp(r'^CB\d{10}$'),
    BankName.awash: RegExp(r'^AW\d{10}$'),
  };

  static bool validateReference(String code, BankName bank) {
    final pattern = referencePatterns[bank];
    if (pattern == null) return false;
    return pattern.hasMatch(code);
  }

  static String hintForBank(BankName bank) {
    switch (bank) {
      case BankName.cbe:
        return 'e.g. FT123456789012';
      case BankName.telebirr:
        return 'e.g. TLB12345678';
      case BankName.cbeBirr:
        return 'e.g. CB1234567890';
      case BankName.awash:
        return 'e.g. AW1234567890';
    }
  }
}
