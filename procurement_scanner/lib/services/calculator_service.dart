import 'package:decimal/decimal.dart';
import '../models/line_item.dart';
import '../models/verification_result.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// Calculator Service
///
/// Performs entirely deterministic, decimal-accurate financial & VAT verification
/// independently of the AI model.
///
/// VAT Rules (18% standard rate or detected document rate):
///  1. VAT amount = Unit price excluding VAT × Rate (0.18)
///  2. Unit price including VAT = Unit price excluding VAT × (1 + Rate)
///  3. Unit price excluding VAT = Unit price including VAT ÷ (1 + Rate)
///  4. Total VAT = VAT-exclusive unit price × quantity × Rate
///  5. Total excluding VAT = Unit price excluding VAT × Quantity
///  6. Total including VAT = Unit price including VAT × Quantity
/// ─────────────────────────────────────────────────────────────────────────────
class CalculatorService {
  CalculatorService._();
  static final CalculatorService instance = CalculatorService._();

  VerificationResult verify({
    required List<LineItem> items,
    required String rawText,
    String? writtenTotalRaw,
    String? writtenSubtotalRaw,
    String? writtenVatTotalRaw,
    String? documentVatRateRaw,
    PriceVatStatus documentPriceStatus = PriceVatStatus.unspecified,
    List<String> ocrWarnings = const [],
  }) {
    bool anyLowConfidence = false;
    bool anyMismatch = false;
    int vatErrorsCount = 0;
    int itemTotalErrorsCount = 0;
    final itemResults = <ItemVerification>[];
    final discrepancyNotes = <String>[];

    Decimal computedSum = Decimal.zero;
    Decimal computedVatSum = Decimal.zero;
    Decimal computedSubtotalSum = Decimal.zero;

    // Detect fallback VAT rate from document or default to 18%
    final docVatRate = _parseRate(documentVatRateRaw) ?? Decimal.parse('0.18');

    // ── Check for duplicate rows ─────────────────────────────────────────────
    final seenItems = <String>{};
    for (final item in items) {
      final desc = item.description.trim().toLowerCase();
      final qty = item.rawQuantity.trim();
      final price = item.rawUnitPrice.trim();
      if (desc.isNotEmpty && qty.isNotEmpty && price.isNotEmpty) {
        final key = '$desc|$qty|$price';
        if (seenItems.contains(key)) {
          discrepancyNotes.add(
            'Possible duplicate item detected: "${item.description}" (Qty: $qty, Unit Price: $price)',
          );
        } else {
          seenItems.add(key);
        }
      }
    }

    // ── Process each line item ───────────────────────────────────────────────
    for (final item in items) {
      if (item.confidence < 0.8) anyLowConfidence = true;

      final qty = _parseDecimal(item.rawQuantity);
      final rawPrice = _parseDecimal(item.rawUnitPrice);
      final written = _parseDecimal(item.rawAmount);
      final itemVatRate = _parseRate(item.rawVatRate) ?? docVatRate;
      final vatPercentStr =
          '${(itemVatRate * Decimal.fromInt(100)).toStringAsFixed(0)}%';

      // 1. Determine Unit Price Excluding and Including VAT
      Decimal? pExcl = _parseDecimal(item.rawUnitPriceExclVat);
      Decimal? pIncl = _parseDecimal(item.rawUnitPriceInclVat);

      final priceStatus = item.priceVatStatus != PriceVatStatus.unspecified
          ? item.priceVatStatus
          : documentPriceStatus;

      if (pExcl != null && pIncl == null) {
        pIncl = _round2(pExcl * (Decimal.one + itemVatRate));
      } else if (pIncl != null && pExcl == null) {
        pExcl = _div(pIncl, Decimal.one + itemVatRate);
      } else if (pExcl == null && pIncl == null && rawPrice != null) {
        if (priceStatus == PriceVatStatus.inclusive) {
          pIncl = rawPrice;
          pExcl = _div(rawPrice, Decimal.one + itemVatRate);
        } else if (priceStatus == PriceVatStatus.exclusive) {
          pExcl = rawPrice;
          pIncl = _round2(rawPrice * (Decimal.one + itemVatRate));
        } else {
          // Unspecified: analyze against written line amount
          if (qty != null && written != null) {
            final testExclTotal = _round2(qty * rawPrice);
            final testInclTotal =
                _round2(qty * _round2(rawPrice * (Decimal.one + itemVatRate)));
            if ((written - testInclTotal).abs() <= Decimal.parse('0.02') &&
                testInclTotal != testExclTotal) {
              pExcl = _div(rawPrice, Decimal.one + itemVatRate);
              pIncl = rawPrice;
            } else {
              pExcl = rawPrice;
              pIncl = _round2(rawPrice * (Decimal.one + itemVatRate));
            }
          } else {
            pExcl = rawPrice;
            pIncl = _round2(rawPrice * (Decimal.one + itemVatRate));
          }
        }
      }

      // 2. Line VAT calculation
      Decimal lineVat = Decimal.zero;
      if (pExcl != null && qty != null) {
        lineVat = _round2(pExcl * qty * itemVatRate);
        computedVatSum += lineVat;
      }

      // Verify item written VAT if explicitly provided
      if (item.rawVatAmount != null) {
        final writtenItemVat = _parseDecimal(item.rawVatAmount!);
        if (writtenItemVat != null && (writtenItemVat - lineVat).abs() > Decimal.parse('0.02')) {
          vatErrorsCount++;
          discrepancyNotes.add(
            'Item "${item.description}": written VAT (${_format(writtenItemVat)}) differs from expected (${_format(lineVat)})',
          );
        }
      }

      // 3. Expected item total calculation
      Decimal? expectedTotal;
      if (qty != null) {
        if (written != null && pIncl != null && (written - _round2(qty * pIncl)).abs() <= Decimal.parse('0.02')) {
          expectedTotal = _round2(qty * pIncl);
        } else if (pExcl != null) {
          expectedTotal = _round2(qty * pExcl);
        } else if (rawPrice != null) {
          expectedTotal = _round2(qty * rawPrice);
        }
      }

      final writtenStr = written != null ? _format(written) : item.rawAmount;
      final expectedStr = expectedTotal != null ? _format(expectedTotal) : '—';

      bool matches = false;
      String diffStr = '—';
      ItemStatus itemStatus;
      String? itemError;

      if (qty == null || rawPrice == null) {
        itemStatus = ItemStatus.needsReview;
        itemError = 'Missing quantity or unit price value.';
        anyLowConfidence = true;
      } else if (written == null) {
        itemStatus = ItemStatus.needsReview;
        itemError = 'Missing written line total.';
        anyLowConfidence = true;
      } else if (expectedTotal != null) {
        final delta = (written - expectedTotal).abs();
        diffStr = _format(delta);
        matches = delta <= Decimal.parse('0.02');

        if (matches) {
          if (item.confidence < 0.8 && !item.amountReviewed) {
            itemStatus = ItemStatus.needsReview;
            itemError = 'Low OCR confidence. Please verify values.';
          } else {
            itemStatus = ItemStatus.correct;
          }
        } else {
          itemStatus = ItemStatus.incorrect;
          itemTotalErrorsCount++;
          anyMismatch = true;
          itemError =
              'Calculation mismatch: expected $expectedStr, detected $writtenStr (Difference: $diffStr)';
          discrepancyNotes.add(
            'Item "${item.description}": Expected $expectedStr, detected $writtenStr',
          );
        }
      } else {
        itemStatus = ItemStatus.needsReview;
        itemError = 'Could not compute expected total.';
        anyLowConfidence = true;
      }

      if (expectedTotal != null) {
        computedSum += expectedTotal;
      } else if (written != null) {
        computedSum += written;
      }

      if (pExcl != null && qty != null) {
        computedSubtotalSum += _round2(pExcl * qty);
      }

      itemResults.add(ItemVerification(
        description: item.description,
        rawQuantity: item.rawQuantity,
        rawUnitPrice: item.rawUnitPrice,
        writtenAmount: writtenStr,
        unitPriceExclVat: pExcl != null ? _format(pExcl) : null,
        unitPriceInclVat: pIncl != null ? _format(pIncl) : null,
        vatRatePercent: vatPercentStr,
        calculatedVatAmount: _format(lineVat),
        expectedItemTotal: expectedStr,
        difference: matches ? '0.00' : diffStr,
        itemStatus: itemStatus,
        errorMessage: itemError,
        matches: matches,
        lowConfidence: item.confidence < 0.8,
      ));
    }

    // ── Grand Total & Document Totals Verification ───────────────────────────
    final writtenTotal = writtenTotalRaw != null
        ? _parseDecimal(writtenTotalRaw)
        : _extractTotalFromText(rawText);

    final writtenSubtotal = _parseDecimal(writtenSubtotalRaw ?? '');
    final writtenVatTotal = _parseDecimal(writtenVatTotalRaw ?? '');

    // Check Subtotal reconciliation if present
    if (writtenSubtotal != null) {
      final subDelta = (writtenSubtotal - computedSubtotalSum).abs();
      if (subDelta > Decimal.parse('0.05')) {
        discrepancyNotes.add(
          'Subtotal mismatch: written ${_format(writtenSubtotal)} vs. computed sum ${_format(computedSubtotalSum)}',
        );
      }
    }

    // Check VAT Total reconciliation if present
    if (writtenVatTotal != null) {
      final vatDelta = (writtenVatTotal - computedVatSum).abs();
      if (vatDelta > Decimal.parse('0.05')) {
        vatErrorsCount++;
        discrepancyNotes.add(
          'Total VAT mismatch: written ${_format(writtenVatTotal)} vs. computed VAT ${_format(computedVatSum)}',
        );
      }
    }

    bool grandTotalDiscrepancy = false;
    String? totalDiff;
    if (writtenTotal != null) {
      // Grand total could match computed item sum, or subtotal + total VAT
      final deltaDirect = (writtenTotal - computedSum).abs();
      final deltaWithVat =
          (writtenTotal - (computedSubtotalSum + computedVatSum)).abs();

      final minDelta = deltaDirect < deltaWithVat ? deltaDirect : deltaWithVat;
      totalDiff = _format(minDelta);

      // Legitimate rounding difference tolerance (±0.05)
      if (minDelta > Decimal.parse('0.05')) {
        grandTotalDiscrepancy = true;
        anyMismatch = true;
        discrepancyNotes.add(
          'Grand Total discrepancy: written ${_format(writtenTotal)} vs. computed ${_format(computedSum)} (Diff: $totalDiff)',
        );
      }
    }

    // ── Overall Status ───────────────────────────────────────────────────────
    VerificationStatus status;
    if (anyMismatch || itemTotalErrorsCount > 0 || vatErrorsCount > 0 || grandTotalDiscrepancy) {
      status = VerificationStatus.discrepancyDetected;
    } else if (anyLowConfidence || ocrWarnings.isNotEmpty || itemResults.isEmpty) {
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
      vatErrorsCount: vatErrorsCount,
      itemTotalErrorsCount: itemTotalErrorsCount,
      grandTotalDiscrepancy: grandTotalDiscrepancy,
      totalVatCalculated: _format(computedVatSum),
      writtenVatTotal: writtenVatTotal != null ? _format(writtenVatTotal) : null,
      subtotalCalculated: _format(computedSubtotalSum),
      writtenSubtotal: writtenSubtotal != null ? _format(writtenSubtotal) : null,
      discrepancyNotes: discrepancyNotes,
    );
  }

  // ── Calculation & Rounding Helpers ─────────────────────────────────────────

  Decimal _round2(Decimal d) {
    return Decimal.parse(d.toStringAsFixed(2));
  }

  Decimal _div(Decimal num, Decimal den, {int scale = 2}) {
    if (den == Decimal.zero) return Decimal.zero;
    final rational = num / den;
    final dec = rational.toDecimal(scaleOnInfinitePrecision: scale + 4);
    return Decimal.parse(dec.toStringAsFixed(scale));
  }

  Decimal? _parseRate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final cleaned = raw.replaceAll('%', '').trim();
    final d = _parseDecimal(cleaned);
    if (d == null) return null;
    if (d > Decimal.one) {
      return _div(d, Decimal.fromInt(100), scale: 4);
    }
    return d;
  }

  // ── Parsing helpers ─────────────────────────────────────────────────────────

  Decimal? _parseDecimal(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;

    String cleaned = raw.trim();
    cleaned = cleaned.replaceAll(
      RegExp(r'(?:rs|lkr|usd|eur|gbp|inr)\.?', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(RegExp(r'[^0-9,\.\-]'), '');

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
