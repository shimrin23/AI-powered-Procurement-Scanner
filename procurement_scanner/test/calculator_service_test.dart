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

  test('parses comma-formatted figures and prefers a grand total keyword', () {
    final result = CalculatorService.instance.verify(
      items: [
        LineItem(
          description: 'Item 1',
          rawQuantity: '50',
          rawUnitPrice: '16,200.00',
          rawAmount: '810,000.00',
        ),
        LineItem(
          description: 'Item 2',
          rawQuantity: '10',
          rawUnitPrice: '15,750.00',
          rawAmount: '157,500.00',
        ),
      ],
      rawText: 'Item 1 50 16,200.00 810,000.00\nItem 2 10 15,750.00 157,500.00\nGrand Total 787,500.00',
    );

    expect(result.writtenTotal, '787500.00');
    expect(result.computedTotal, '967500.00');
    expect(result.totalDifference, '180000.00');
    expect(result.status, VerificationStatus.discrepancyDetected);
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
