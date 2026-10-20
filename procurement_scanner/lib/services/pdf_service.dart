import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/document_scan.dart';
import '../models/verification_result.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// PDF Service
///
/// Generates a structured PDF report for a completed document scan and saves
/// it to the device's Documents directory.  Report contains:
///   • Cover page (scan metadata, overall status)
///   • Original + cropped document images
///   • Extracted line-item table with verification results
///   • Totals section
///   • Warnings / fields requiring manual review
/// ─────────────────────────────────────────────────────────────────────────────
class PdfService {
  PdfService._();
  static final PdfService instance = PdfService._();

  /// Generate and save the PDF; returns the saved [File].
  Future<File> generateReport(DocumentScan scan) async {
    final result = scan.verificationResult!;
    final doc = pw.Document();

    // Load images as PDF image providers.
    final originalBytes = await scan.originalImage.readAsBytes();
    final croppedBytes = await scan.croppedImage.readAsBytes();
    final originalPdf = pw.MemoryImage(originalBytes);
    final croppedPdf = pw.MemoryImage(croppedBytes);

    // ── Cover page ───────────────────────────────────────────────────────────
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) => [
          _header(scan),
          pw.SizedBox(height: 16),
          _statusBanner(result),
          pw.SizedBox(height: 24),

          // Images row.
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                  child: _imageSection('Original Document', originalPdf)),
              pw.SizedBox(width: 12),
              pw.Expanded(child: _imageSection('Cropped Document', croppedPdf)),
            ],
          ),

          pw.SizedBox(height: 24),
          _sectionTitle('Extracted Line Items & Verification'),
          pw.SizedBox(height: 8),
          _lineItemTable(result),

          pw.SizedBox(height: 16),
          _totalsSection(result),

          if (result.warnings.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _warningsSection(result.warnings),
          ],

          pw.SizedBox(height: 16),
          _rawTextSection(result.rawOcrText),

          pw.SizedBox(height: 24),
          _footer(scan),
        ],
      ),
    );

    // ── Save to disk ─────────────────────────────────────────────────────────
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
    final status = result.status;
    PdfColor bg;
    PdfColor fg;
    switch (status) {
      case VerificationStatus.calculationsMatch:
        bg = PdfColors.green100;
        fg = PdfColors.green900;
      case VerificationStatus.discrepancyDetected:
        bg = PdfColors.red100;
        fg = PdfColors.red900;
      case VerificationStatus.manualReviewRequired:
        bg = PdfColors.amber100;
        fg = PdfColors.amber900;
    }

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
            status.label,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: fg,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(status.description,
              style: pw.TextStyle(fontSize: 10, color: fg)),
        ],
      ),
    );
  }

  pw.Widget _imageSection(String title, pw.ImageProvider image) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title,
              style:
                  pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.ClipRRect(
            horizontalRadius: 4,
            verticalRadius: 4,
            child: pw.Image(image, height: 200, fit: pw.BoxFit.contain),
          ),
        ],
      );

  pw.Widget _sectionTitle(String title) => pw.Text(
        title,
        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
      );

  pw.Widget _lineItemTable(VerificationResult result) {
    if (result.itemResults.isEmpty) {
      return pw.Text('No line items could be extracted.',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600));
    }

    return pw.TableHelper.fromTextArray(
      headers: [
        'Description',
        'Qty',
        'Unit Price',
        'Written Amt',
        'Calc. Amt',
        'Diff',
        'Status',
      ],
      data: result.itemResults
          .map((r) => [
                r.description,
                r.rawQuantity,
                r.rawUnitPrice,
                r.writtenAmount,
                r.calculatedAmount,
                r.difference,
                r.lowConfidence
                    ? '⚠ Review'
                    : r.matches
                        ? '✓ OK'
                        : '✗ Mismatch',
              ])
          .toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignments: {
        5: pw.Alignment.centerRight,
        6: pw.Alignment.center,
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
            pw.Text('Totals',
                style:
                    pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            _totalRow('Computed Total', result.computedTotal),
            if (result.writtenTotal != null)
              _totalRow('Written Total', result.writtenTotal!),
            if (result.totalDifference != null)
              _totalRow('Difference', result.totalDifference!,
                  color: PdfColors.red700),
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
            pw.Text('⚠  Warnings',
                style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.amber900)),
            pw.SizedBox(height: 6),
            ...warnings.map((w) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Text('• $w',
                      style: const pw.TextStyle(
                          fontSize: 9, color: PdfColors.amber900)),
                )),
          ],
        ),
      );

  pw.Widget _rawTextSection(String rawText) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Raw OCR Output',
              style:
                  pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Text(
              rawText.isEmpty ? '(no text extracted)' : rawText,
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
          ),
        ],
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
