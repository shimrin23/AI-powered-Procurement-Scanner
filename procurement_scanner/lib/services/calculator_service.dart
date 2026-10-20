import 'package:decimal/decimal.dart';
import '../models/line_item.dart';
import '../models/verification_result.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// Calculator Service
///
/// Performs entirely deterministic, decimal-accurate arithmetic to verify
/// procurement document calculations independently of the AI model.
///
/// Rules:
///  1. Qty × Unit Price  → expected item amount
///  2. ΣItem amounts     → expected subtotal / grand total
///  3. Differences       → written value minus computed value
///  4. Status determination:
///      • If any field has lowConfidence → ManualReviewRequired
///      • Else if any amount mismatches → DiscrepancyDetected
///      • Else                          → CalculationsMatch
/// ─────────────────────────────────────────────────────────────────────────────
class CalculatorService {
  CalculatorService._();
  static final CalculatorService instance = CalculatorService._();

  VerificationResult verify({
    required List<LineItem> items,
    required String rawText,
    String? writtenTotalRaw,
    List<String> ocrWarnings = const [],
  }) {
    bool anyLowConfidence = false;
    bool anyMismatch = false;
    final itemResults = <ItemVerification>[];
    Decimal computedSum = Decimal.zero;

    for (final item in items) {
      if (item.confidence < 0.8) anyLowConfidence = true;

      final qty = _parseDecimal(item.rawQuantity);
      final unitPrice = _parseDecimal(item.rawUnitPrice);
      final written = _parseDecimal(item.rawAmount);

      // Compute expected amount with precision.
      final calculated =
          (qty != null && unitPrice != null) ? qty * unitPrice : null;

      final writtenStr = written != null ? _format(written) : item.rawAmount;
      final calculatedStr = calculated != null ? _format(calculated) : '—';

      bool matches = false;
      String diff = '—';

      if (written != null && calculated != null) {
        final delta = written - calculated;
        diff = _format(delta.abs());
        matches = delta.abs() <= Decimal.parse('0.01');
        if (!matches) anyMismatch = true;
        computedSum += calculated;
      } else {
        // Cannot parse → treat as unverified.
        anyLowConfidence = true;
        if (calculated != null) computedSum += calculated;
      }

      itemResults.add(ItemVerification(
        description: item.description,
        rawQuantity: item.rawQuantity,
        rawUnitPrice: item.rawUnitPrice,
        writtenAmount: writtenStr,
        calculatedAmount: calculatedStr,
        difference: matches ? '0.00' : diff,
        matches: matches,
        lowConfidence: item.confidence < 0.8,
      ));
    }

    // Total verification.
    final writtenTotal = writtenTotalRaw != null
        ? _parseDecimal(writtenTotalRaw)
        : _extractTotalFromText(rawText);

    String? totalDiff;
    if (writtenTotal != null) {
      final delta = writtenTotal - computedSum;
      totalDiff = _format(delta.abs());
      if (delta.abs() > Decimal.parse('0.01')) anyMismatch = true;
    }

    // Determine overall status.
    VerificationStatus status;
    if (ocrWarnings.isNotEmpty || anyLowConfidence) {
      status = VerificationStatus.manualReviewRequired;
    } else if (anyMismatch) {
      status = VerificationStatus.discrepancyDetected;
    } else if (itemResults.isEmpty) {
      status = VerificationStatus.manualReviewRequired;
    } else {
      status = VerificationStatus.calculationsMatch;
    }

    return VerificationResult(
      status: status,
      itemResults: itemResults,
      writtenTotal:
          writtenTotal != null ? _format(writtenTotal) : writtenTotalRaw,
      computedTotal: _format(computedSum),
      totalDifference: totalDiff,
      rawOcrText: rawText,
      warnings: ocrWarnings,
    );
  }

  // ── Parsing helpers ─────────────────────────────────────────────────────────

  Decimal? _parseDecimal(String raw) {
    // Remove currency symbols, spaces, thousands-separators, non-numeric chars.
    final cleaned =
        raw.replaceAll(RegExp(r'[^\d.,\-]'), '').replaceAll(',', '');
    if (cleaned.isEmpty) return null;
    try {
      return Decimal.parse(cleaned);
    } catch (_) {
      return null;
    }
  }

  String _format(Decimal d) => d.toStringAsFixed(2);

  /// Heuristic: find the largest number in the OCR text — often the grand total.
  Decimal? _extractTotalFromText(String text) {
    final pattern = RegExp(r'\d{1,3}(?:,\d{3})*(?:\.\d+)?|\d+(?:\.\d+)?');
    final matches = pattern.allMatches(text);
    Decimal? largest;
    for (final m in matches) {
      final d = _parseDecimal(m.group(0)!);
      if (d != null && (largest == null || d > largest)) {
        largest = d;
      }
    }
    return largest;
  }
}
