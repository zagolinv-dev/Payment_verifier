import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payment_verifier/core/constants/app_constants.dart';
import 'package:payment_verifier/presentation/widgets/status_chip.dart';

void main() {
  testWidgets('StatusChip renders VERIFIED text for verified status', (WidgetTester tester) async {
    // Build our widget and trigger a frame.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatusChip(status: TransactionStatus.verified),
        ),
      ),
    );

    // Verify that the status chip displays 'VERIFIED'.
    expect(find.text('VERIFIED'), findsOneWidget);
    expect(find.text('FAILED'), findsNothing);
  });
}
