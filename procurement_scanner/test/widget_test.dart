import 'package:flutter_test/flutter_test.dart';
import 'package:procurement_scanner/app.dart';

void main() {
  testWidgets('shows the home screen and scan action', (tester) async {
    await tester.pumpWidget(const ProcurementScannerApp());
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.textContaining('Procurement'), findsOneWidget);
    expect(find.text('Scan Document'), findsOneWidget);
  });
}
