import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/document_scan.dart';
import '../models/verification_result.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// PDF Service
///
/// Generates a structured PDF report for a completed document scan and saves
/// it to the device's Documents directory. Report contains:
///   • Cover page (scan metadata, overall status)
///   • All scanned document images (multi-page support)
///   • Extracted line-item table with clean OK/Wrong verification results
///   • Unicode support for Sinhala, Tamil, and English descriptions
///   • Totals section
///   • Warnings
/// ─────────────────────────────────────────────────────────────────────────────
class PdfService {
  PdfService._();
  static final PdfService instance = PdfService._();

  /// Builds the [pw.Document] for the provided [scan].
  Future<pw.Document> buildDocument(DocumentScan scan) async {
    final result = scan.verificationResult!;
    final doc = pw.Document();

    // Load fonts with Google Fonts to support Sinhala, Tamil, and English Unicode characters
    pw.Font? baseFont;
    pw.Font? boldFont;
    pw.Font? sinhalaFont;
    pw.Font? tamilFont;

    try {
      baseFont = await PdfGoogleFonts.notoSansRegular();
      boldFont = await PdfGoogleFonts.notoSansBold();
      sinhalaFont = await PdfGoogleFonts.notoSansSinhalaRegular();
      tamilFont = await PdfGoogleFonts.notoSansTamilRegular();
    } catch (_) {
      // In case of network unavailability, fall back to default fonts
    }

    final fontFallbacks = <pw.Font>[
      if (sinhalaFont != null) sinhalaFont,
      if (tamilFont != null) tamilFont,
    ];

    final theme = (baseFont != null && boldFont != null)
        ? pw.ThemeData.withFont(
            base: baseFont,
            bold: boldFont,
            fontFallback: fontFallbacks,
          )
        : pw.ThemeData.base();

    // ── Document Report Page ───────────────────────────────────────────────────
    doc.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) => [
          _header(scan),
          pw.SizedBox(height: 16),
          _statusBanner(result),
          pw.SizedBox(height: 20),

          _sectionTitle('Extracted Line Items & Verification'),
          pw.SizedBox(height: 8),
          _lineItemTable(result, fontFallbacks: fontFallbacks),

          pw.SizedBox(height: 16),
          _totalsSection(result),

          if (result.discrepancyNotes.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            _discrepancySection(result.discrepancyNotes),
          ],

          if (result.warnings.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            _warningsSection(result.warnings),
          ],

          pw.SizedBox(height: 24),
          _footer(scan),
        ],
      ),
    );

    return doc;
  }

  /// Generates the raw PDF bytes for saving or sharing.
  Future<Uint8List> generatePdfBytes(DocumentScan scan) async {
    final doc = await buildDocument(scan);
    return doc.save();
  }

  /// Generate and save the PDF; returns the saved [File].
  Future<File> generateReport(DocumentScan scan) async {
    final doc = await buildDocument(scan);
    final dir = await _outputDirectory();
    final ts = scan.scannedAt.millisecondsSinceEpoch;
    final file = File('${dir.path}/procurement_report_$ts.pdf');
    final bytes = await doc.save();
    await file.writeAsBytes(bytes);
    return file;
  }

  // ── Widget builders ─────────────────────────────────────────────────────────

  pw.Widget _header(DocumentScan scan) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Procurement Scanner — Verification Report',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Generated: ${_formatDate(scan.scannedAt)}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
          pw.Divider(color: PdfColors.grey400),
        ],
      );

  pw.Widget _statusBanner(VerificationResult result) {
    final isOk = result.status == VerificationStatus.calculationsMatch;
    final bg = isOk ? PdfColors.green100 : PdfColors.red100;
    final fg = isOk ? PdfColors.green900 : PdfColors.red900;

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: bg,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            isOk ? 'Status: OK' : 'Status: Wrong',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: fg,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            isOk
                ? 'All calculations and VAT amounts match the document.'
                : 'Calculations, VAT rates, or grand totals have discrepancies.',
            style: pw.TextStyle(fontSize: 10, color: fg),
          ),
        ],
      ),
    );
  }

  pw.Widget _sectionTitle(String title) => pw.Text(
        title,
        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
      );

  pw.Widget _lineItemTable(
    VerificationResult result, {
    List<pw.Font> fontFallbacks = const [],
  }) {
    if (result.itemResults.isEmpty) {
      return pw.Text('No line items could be extracted.',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600));
    }

    return pw.TableHelper.fromTextArray(
      headers: [
        'Description',
        'Qty',
        'Price (Excl)',
        'VAT',
        'Expected',
        'Detected',
        'Diff',
        'Status',
      ],
      data: result.itemResults
          .map((r) => [
                r.description,
                r.rawQuantity,
                r.unitPriceExclVat ?? r.rawUnitPrice,
                r.calculatedVatAmount,
                r.expectedItemTotal,
                r.writtenAmount,
                r.difference,
                r.itemStatus == ItemStatus.correct
                    ? 'OK'
                    : (r.itemStatus == ItemStatus.incorrect ? 'Wrong' : 'Review'),
              ])
          .toList(),
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        fontSize: 8.5,
        fontFallback: fontFallbacks,
      ),
      cellStyle: pw.TextStyle(
        fontSize: 8,
        fontFallback: fontFallbacks,
      ),
      cellAlignments: {
        6: pw.Alignment.centerRight,
        7: pw.Alignment.center,
      },
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
    );
  }

  pw.Widget _totalsSection(VerificationResult result) => pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Financial & Tax Totals',
                style:
                    pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            if (result.subtotalCalculated != null)
              _totalRow('Subtotal (Excl. VAT)', result.subtotalCalculated!),
            if (result.totalVatCalculated != null)
              _totalRow('Total VAT Amount', result.totalVatCalculated!,
                  color: PdfColors.blue800),
            _totalRow('Computed Grand Total', result.computedTotal,
                color: PdfColors.black),
            if (result.writtenTotal != null)
              _totalRow('Written Grand Total', result.writtenTotal!),
            if (result.totalDifference != null)
              _totalRow(
                'Grand Total Variance',
                result.totalDifference!,
                color: result.grandTotalDiscrepancy
                    ? PdfColors.red700
                    : PdfColors.green700,
              ),
          ],
        ),
      );

  pw.Widget _discrepancySection(List<String> notes) => pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColors.red50,
          border: pw.Border.all(color: PdfColors.red300, width: 0.5),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Discrepancies Detected',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.red900,
              ),
            ),
            pw.SizedBox(height: 6),
            ...notes.map((n) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 3),
                  child: pw.Text('- $n',
                      style: const pw.TextStyle(
                          fontSize: 9, color: PdfColors.red900)),
                )),
          ],
        ),
      );

  pw.Widget _totalRow(String label, String value,
          {PdfColor color = PdfColors.black}) =>
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 10, fontWeight: pw.FontWeight.bold, color: color)),
        ],
      );

  pw.Widget _warningsSection(List<String> warnings) => pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColors.amber50,
          border: pw.Border.all(color: PdfColors.amber700, width: 0.5),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Warnings',
                style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.amber900)),
            pw.SizedBox(height: 6),
            ...warnings.map((w) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Text('- $w',
                      style: const pw.TextStyle(
                          fontSize: 9, color: PdfColors.amber900)),
                )),
          ],
        ),
      );


  pw.Widget _footer(DocumentScan scan) => pw.Column(
        children: [
          pw.Divider(color: PdfColors.grey400),
          pw.Text(
            'This report was generated by Procurement Scanner. '
            'Verification is based on extracted values only. '
            'Always perform manual review for legally binding documents.',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
            textAlign: pw.TextAlign.center,
          ),
        ],
      );

  // ── Utils ────────────────────────────────────────────────────────────────────

  Future<Directory> _outputDirectory() async {
    // Prefer external storage on Android; fall back to app documents.
    try {
      final ext = await getExternalStorageDirectory();
      if (ext != null) return ext;
    } catch (_) {}
    return getApplicationDocumentsDirectory();
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}-${_pad(dt.month)}-${_pad(dt.day)} '
      '${_pad(dt.hour)}:${_pad(dt.minute)}';

  String _pad(int n) => n.toString().padLeft(2, '0');
}
