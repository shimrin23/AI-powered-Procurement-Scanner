import 'package:flutter_test/flutter_test.dart';
import 'package:procurement_scanner/models/line_item.dart';
import 'package:procurement_scanner/models/verification_result.dart';
import 'package:procurement_scanner/services/calculator_service.dart';

void main() {
  test('matches item and written total using decimal arithmetic', () {
    final result = CalculatorService.instance.verify(
      items: [
        LineItem(
          description: 'Paper',
          rawQuantity: '2',
          rawUnitPrice: '12.50',
          rawAmount: '25.00',
        ),
      ],
      rawText: 'Total 25.00',
    );

    expect(result.status, VerificationStatus.calculationsMatch);
    expect(result.computedTotal, '25.00');
    expect(result.totalDifference, '0.00');
  });

  test('requires manual review when a financial value is unreadable', () {
    final result = CalculatorService.instance.verify(
      items: [
        LineItem(
          description: 'Paper',
          rawQuantity: '2',
          rawUnitPrice: '12.50',
          rawAmount: 'unreadable',
        ),
      ],
      rawText: '',
    );

    expect(result.status, VerificationStatus.manualReviewRequired);
    expect(result.computedTotal, '25.00');
  });
}
