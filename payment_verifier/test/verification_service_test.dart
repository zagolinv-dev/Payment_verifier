import 'package:flutter_test/flutter_test.dart';
import 'package:payment_verifier/data/services/verification_service.dart';
import 'package:payment_verifier/data/services/ocr_service.dart';

void main() {
  group('_namesMatch (via VerificationService)', () {
    late VerificationService service;

    setUp(() {
      service = VerificationService(
        config: const VerifyConfig(
          expectedAmount: 100.0,
          businessAccounts: ['1000123456789'],
          selectedBank: 'CBE',
        ),
      );
    });

    Future<VerifyResult> runVerify({
      String? customerName,
      String? expectedCustomerName,
      String? receiverName,
      String? expectedReceiverName,
      String? paymentMethod,
      String? receiverAccount,
      double amount = 100.0,
      String? reference,
      String? date,
    }) async {
      final ocr = OcrResult(
        rawText: '',
        amount: amount.toStringAsFixed(2),
        reference: reference ?? 'FT12345678',
        paymentMethod: paymentMethod ?? 'cbe',
        customerName: customerName,
        receiverAccount: receiverAccount ?? '1000123456789',
        receiverName: receiverName,
        date: date ?? 'Jun 28, 2026 10:00 AM',
      );

      final svc = VerificationService(
        config: VerifyConfig(
          expectedAmount: 100.0,
          businessAccounts: ['1000123456789'],
          selectedBank: paymentMethod == 'telebirr' ? 'Telebirr' : 'CBE',
          expectedCustomerName: expectedCustomerName,
          expectedReceiverName: expectedReceiverName,
        ),
        isDuplicate: (_) async => null,
      );

      return svc.verify(ocr, scanTime: DateTime(2026, 6, 28, 12, 0));
    }

    test('Customer name exact match passes', () async {
      final result = await runVerify(
        customerName: 'ABEBE GIRMA',
        expectedCustomerName: 'ABEBE GIRMA',
      );
      final nameStep = result.steps.firstWhere((s) => s.name.contains('Customer name'));
      expect(nameStep.passed, isTrue);
    });

    test('Customer name partial token match passes', () async {
      final result = await runVerify(
        customerName: 'ABEBE GIRMA TADESSE',
        expectedCustomerName: 'Abebe Girma',
      );
      final nameStep = result.steps.firstWhere((s) => s.name.contains('Customer name'));
      expect(nameStep.passed, isTrue);
    });

    test('Customer name mismatch fails', () async {
      final result = await runVerify(
        customerName: 'DAWIT BEKELE',
        expectedCustomerName: 'ABEBE GIRMA',
      );
      final nameStep = result.steps.firstWhere((s) => s.name.contains('Customer name'));
      expect(nameStep.passed, isFalse);
    });

    test('Customer name missing fails', () async {
      final result = await runVerify(
        customerName: null,
        expectedCustomerName: 'ABEBE GIRMA',
      );
      final nameStep = result.steps.firstWhere((s) => s.name.contains('Customer name'));
      expect(nameStep.passed, isFalse);
    });

    test('Telebirr uses receiver name match', () async {
      final result = await runVerify(
        paymentMethod: 'telebirr',
        receiverName: 'COFFEE SHOP ACCOUNT',
        expectedReceiverName: 'Coffee Shop',
        receiverAccount: null,
      );
      final nameStep = result.steps.firstWhere((s) => s.name.contains('Receiver name'));
      expect(nameStep.passed, isTrue);
    });

    test('Telebirr receiver name mismatch fails', () async {
      final result = await runVerify(
        paymentMethod: 'telebirr',
        receiverName: 'WRONG MERCHANT',
        expectedReceiverName: 'Coffee Shop',
        receiverAccount: null,
      );
      final nameStep = result.steps.firstWhere((s) => s.name.contains('Receiver name'));
      expect(nameStep.passed, isFalse);
    });
  });

  group('VerificationService.verify - core steps', () {
    const baseConfig = VerifyConfig(
      expectedAmount: 500.0,
      businessAccounts: ['1000123456789'],
      selectedBank: 'CBE',
      maxAgeDays: 7,
    );

    OcrResult makeOcr({
      String? amount,
      String? reference,
      String? paymentMethod,
      String? customerName,
      String? receiverAccount,
      String? date,
    }) {
      return OcrResult(
        rawText: '',
        amount: amount ?? '500.00',
        reference: reference ?? 'FT99887766',
        paymentMethod: paymentMethod ?? 'cbe',
        customerName: customerName ?? 'ABEBE KEBEDE',
        receiverAccount: receiverAccount ?? '1000123456789',
        date: date ?? 'Jun 28, 2026 10:00 AM',
      );
    }

    test('All steps pass → Verdict.verified', () async {
      final svc = VerificationService(
        config: baseConfig,
        isDuplicate: (_) async => null,
      );
      final result = await svc.verify(
        makeOcr(),
        scanTime: DateTime(2026, 6, 28, 12, 0),
      );
      expect(result.verdict, Verdict.verified);
      expect(result.status, 'Verified');
    });

    test('Amount below expected → fails amount check', () async {
      final svc = VerificationService(
        config: baseConfig,
        isDuplicate: (_) async => null,
      );
      final result = await svc.verify(
        makeOcr(amount: '100.00'),
        scanTime: DateTime(2026, 6, 28, 12, 0),
      );
      final amountStep = result.steps.firstWhere((s) => s.name == 'Amount match');
      expect(amountStep.passed, isFalse);
    });

    test('Duplicate reference → fails duplicate check', () async {
      final dupDate = DateTime(2026, 6, 27);
      final svc = VerificationService(
        config: baseConfig,
        isDuplicate: (_) async => dupDate,
      );
      final result = await svc.verify(
        makeOcr(),
        scanTime: DateTime(2026, 6, 28, 12, 0),
      );
      final dupStep = result.steps.firstWhere((s) => s.name == 'Duplicate check');
      expect(dupStep.passed, isFalse);
    });

    test('Receiver account mismatch → fails account match', () async {
      final svc = VerificationService(
        config: baseConfig,
        isDuplicate: (_) async => null,
      );
      final result = await svc.verify(
        makeOcr(receiverAccount: '9999999999999'),
        scanTime: DateTime(2026, 6, 28, 12, 0),
      );
      final acctStep = result.steps.firstWhere((s) => s.name == 'Account match');
      expect(acctStep.passed, isFalse);
    });

    test('status getter maps Verdict → string', () {
      final stepsList = [const VStep('x', 'x', StepState.pass)];
      expect(VerifyResult(stepsList, Verdict.verified, OcrResult(rawText: ''), '').status, 'Verified');
      expect(VerifyResult(stepsList, Verdict.tryAgain, OcrResult(rawText: ''), '').status, 'Suspicious');
      expect(VerifyResult(stepsList, Verdict.failed, OcrResult(rawText: ''), '').status, 'Rejected');
    });
  });

  group('parseReceiptDate', () {
    test('parses month-name format', () {
      final dt = parseReceiptDate('Jun 28, 2026 10:30 AM');
      expect(dt, isNotNull);
      expect(dt!.year, 2026);
      expect(dt.month, 6);
      expect(dt.day, 28);
    });

    test('parses dd/mm/yyyy format', () {
      final dt = parseReceiptDate('28/06/2026 10:30');
      expect(dt, isNotNull);
      expect(dt!.year, 2026);
      expect(dt.month, 6);
    });

    test('returns null for invalid date', () {
      expect(parseReceiptDate(null), isNull);
      expect(parseReceiptDate('not-a-date'), isNull);
    });
  });
}
