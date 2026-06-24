import 'package:payment_verifier/core/constants/app_constants.dart';
import 'package:payment_verifier/domain/entities/transaction_entity.dart';
import 'package:payment_verifier/domain/entities/bank_account_entity.dart';
import 'package:payment_verifier/domain/entities/user_profile_entity.dart';

class MockData {
  static final List<UserProfileEntity> users = [
    UserProfileEntity(
      id: 'mock-admin-id',
      email: 'simonnjege@gmail.com',
      fullName: 'Simon Njege',
      role: UserRole.admin,
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
    ),
    UserProfileEntity(
      id: 'mock-waitress-1',
      email: 'tigist@tspay.com',
      fullName: 'Tigist Alemu',
      role: UserRole.waitress,
      createdAt: DateTime.now().subtract(const Duration(days: 15)),
    ),
    UserProfileEntity(
      id: 'mock-waitress-2',
      email: 'selam@tspay.com',
      fullName: 'Selamawit Kebede',
      role: UserRole.waitress,
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
  ];

  static final List<BankAccountEntity> bankAccounts = [
    BankAccountEntity(
      id: 'acc-1',
      holderName: "T's Pay Cafe - Main",
      bankName: 'Commercial Bank of Ethiopia (CBE)',
      accountNumber: '1000123456789',
      phone: '+251911223344',
      notes: 'Primary collection account for CBE Birr and CBE transfers',
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 60)),
    ),
    BankAccountEntity(
      id: 'acc-2',
      holderName: "T's Pay Cafe - Telebirr",
      bankName: 'Telebirr',
      accountNumber: '0911223344',
      phone: '+251911223344',
      notes: 'Merchant ID collection account',
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 60)),
    ),
    BankAccountEntity(
      id: 'acc-3',
      holderName: "T's Pay Cafe - Settlement",
      bankName: 'Awash Bank',
      accountNumber: '01320444555600',
      phone: '+251911223344',
      notes: 'Weekly settlements account',
      isActive: false,
      createdAt: DateTime.now().subtract(const Duration(days: 45)),
    ),
  ];

  static final List<TransactionEntity> transactions = [
    TransactionEntity(
      id: 'tx-1',
      bankName: 'Telebirr',
      referenceCode: 'TXN789456123',
      buyerName: 'Abebe Bikila',
      amount: 450.00,
      tip: 50.00,
      status: TransactionStatus.verified,
      verifiedBy: 'mock-waitress-1',
      createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
    ),
    TransactionEntity(
      id: 'tx-2',
      bankName: 'Commercial Bank of Ethiopia (CBE)',
      referenceCode: 'CBE987654321',
      buyerName: 'Aster Aweke',
      amount: 1200.00,
      tip: 100.00,
      status: TransactionStatus.verified,
      verifiedBy: 'mock-waitress-2',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    TransactionEntity(
      id: 'tx-3',
      bankName: 'CBE Birr',
      referenceCode: 'CBB112233445',
      buyerName: 'Teddy Afro',
      amount: 750.00,
      tip: 0.00,
      status: TransactionStatus.pending,
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
    ),
    TransactionEntity(
      id: 'tx-4',
      bankName: 'Awash Bank',
      referenceCode: 'AWA556677889',
      buyerName: 'Chala Balcha',
      amount: 320.00,
      tip: 30.00,
      status: TransactionStatus.failed,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    TransactionEntity(
      id: 'tx-5',
      bankName: 'Telebirr',
      referenceCode: 'TXN554433221',
      buyerName: 'Genzebe Dibaba',
      amount: 150.00,
      tip: 15.00,
      status: TransactionStatus.verified,
      verifiedBy: 'mock-admin-id',
      createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
    ),
  ];
}
