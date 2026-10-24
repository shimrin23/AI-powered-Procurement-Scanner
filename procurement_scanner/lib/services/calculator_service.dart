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
    if (raw.trim().isEmpty) return null;

    String cleaned = raw.trim();
    cleaned = cleaned.replaceAll(
      RegExp(r'(?:rs|lkr|usd|eur|gbp|inr)\.?', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(RegExp(r'[^0-9,\.\-]'), '');

    // Handle OCR artefacts such as "1,234.56", "1.234,56", and "12 345,67".
    if (cleaned.contains(',') && cleaned.contains('.')) {
      final lastComma = cleaned.lastIndexOf(',');
      final lastDot = cleaned.lastIndexOf('.');
      if (lastComma > lastDot) {
        cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
      } else {
        cleaned = cleaned.replaceAll(',', '');
      }
    } else if (cleaned.contains(',')) {
      final commaParts = cleaned.split(',');
      if (commaParts.length > 1 && commaParts.last.length <= 2) {
        cleaned = cleaned.replaceAll(',', '.');
      } else {
        cleaned = cleaned.replaceAll(',', '');
      }
    }

    cleaned = cleaned.replaceAll(RegExp(r'\s+'), '');
    if (cleaned.isEmpty || cleaned == '-' || cleaned == '.') return null;

    try {
      return Decimal.parse(cleaned);
    } catch (_) {
      return null;
    }
  }

  String _format(Decimal d) => d.toStringAsFixed(2);

  Decimal? _extractTotalFromText(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return null;

    final keywordPattern = RegExp(
      r'(grand\s*total|total\s*amount|net\s*total|sub\s*total|subtotal|total)\s*[:=]?\s*(?:rs\.?\s*)?(\d[\d,\s\.\-]*)',
      caseSensitive: false,
    );
    for (final match in keywordPattern.allMatches(normalized)) {
      final candidate = match.group(2)?.trim();
      if (candidate == null || candidate.isEmpty) continue;
      final parsed = _parseDecimal(candidate);
      if (parsed != null) return parsed;
    }

    final pattern = RegExp(r'\d{1,3}(?:[\s,]\d{3})*(?:\.\d+)?|\d+(?:\.\d+)?');
    Decimal? largest;
    for (final match in pattern.allMatches(normalized)) {
      final value = _parseDecimal(match.group(0)!);
      if (value == null) continue;
      if (largest == null || value > largest) {
        largest = value;
      }
    }
    return largest;
  }
}
