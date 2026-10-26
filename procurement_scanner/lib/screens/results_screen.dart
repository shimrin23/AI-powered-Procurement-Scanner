import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../models/document_scan.dart';
import '../models/verification_result.dart';
import '../services/pdf_service.dart';
import '../theme.dart';
import '../widgets/status_badge.dart';
import '../widgets/extracted_field_tile.dart';

/// Screen 4 — Displays verification results, editable fields, and PDF export.
class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key, required this.scan});
  final DocumentScan scan;

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  bool _generatingPdf = false;

  VerificationResult get _result => widget.scan.verificationResult!;

  Future<void> _savePdf() async {
    setState(() => _generatingPdf = true);
    try {
      final ts = widget.scan.scannedAt.millisecondsSinceEpoch;
      final filename = 'procurement_report_$ts.pdf';
      final bytes = await PdfService.instance.generatePdfBytes(widget.scan);

      // Opens native Android "Save as PDF" dialog letting user choose folder manually
      await Printing.layoutPdf(
        name: filename,
        onLayout: (PdfPageFormat format) async => bytes,
      );
    } catch (e) {
      if (!mounted) return;
      _showError('Could not open Save dialog: $e');
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  Future<void> _sharePdf() async {
    setState(() => _generatingPdf = true);
    try {
      final ts = widget.scan.scannedAt.millisecondsSinceEpoch;
      final filename = 'procurement_report_$ts.pdf';
      final bytes = await PdfService.instance.generatePdfBytes(widget.scan);

      await Printing.sharePdf(
        bytes: bytes,
        filename: filename,
      );
    } catch (e) {
      if (!mounted) return;
      _showError('PDF share failed: $e');
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }


  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Verification Results'),
        backgroundColor: AppTheme.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: _generatingPdf ? null : _sharePdf,
            tooltip: 'Share PDF',
          ),
          IconButton(
            icon: const Icon(Icons.home_rounded),
            onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
            tooltip: 'Home',
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Status banner ─────────────────────────────────────────────
            StatusBanner(status: _result.status)
                .animate()
                .fadeIn(duration: 500.ms)
                .slideY(begin: -0.1),

            const Gap(14),

            // ── Document-level audit summary metrics ─────────────────────
            _AuditSummaryCard(result: _result).animate().fadeIn(delay: 50.ms),

            const Gap(14),

            // ── Financial & VAT discrepancies breakdown ──────────────────
            if (_result.discrepancyNotes.isNotEmpty) ...[
              _DiscrepanciesCard(notes: _result.discrepancyNotes)
                  .animate()
                  .fadeIn(delay: 80.ms),
              const Gap(14),
            ],

            // ── Warnings ─────────────────────────────────────────────────
            if (_result.warnings.isNotEmpty) ...[
              _WarningsCard(warnings: _result.warnings)
                  .animate()
                  .fadeIn(delay: 100.ms),
              const Gap(12),
            ],

            // ── Cropped image thumbnail ────────────────────────────────────
            _ImageRow(scan: widget.scan).animate().fadeIn(delay: 150.ms),

            const Gap(16),

            // ── Line items ────────────────────────────────────────────────
            _SectionTitle(title: 'Extracted Line Items'),
            const Gap(8),

            if (_result.itemResults.isEmpty)
              _EmptyItems()
            else
              ..._result.itemResults.asMap().entries.map(
                    (entry) => ExtractedFieldTile(
                      index: entry.key,
                      item: entry.value,
                    ).animate().fadeIn(delay: (200 + entry.key * 60).ms),
                  ),

            const Gap(16),

            // ── Totals ────────────────────────────────────────────────────
            _TotalsCard(result: _result).animate().fadeIn(delay: 300.ms),

            const Gap(16),

            // ── Raw OCR text ──────────────────────────────────────────────
            _RawTextCard(text: _result.rawOcrText)
                .animate()
                .fadeIn(delay: 350.ms),

            const Gap(24),

            // ── PDF actions ───────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _generatingPdf ? null : _savePdf,
                icon: _generatingPdf
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_alt_rounded),
                label: Text(
                  _generatingPdf ? 'Preparing PDF…' : 'Save PDF (Choose Location)',
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  backgroundColor: AppTheme.accent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ).animate().fadeIn(delay: 400.ms).scaleXY(begin: 0.95),

            const Gap(12),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _generatingPdf ? null : _sharePdf,
                icon: const Icon(Icons.share_rounded, size: 20),
                label: const Text('Share PDF Report'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  foregroundColor: AppTheme.textPrimary,
                  side: const BorderSide(color: AppTheme.border, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ).animate().fadeIn(delay: 450.ms),

            const Gap(12),

            Center(
              child: TextButton.icon(
                onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Scan Another Document'),
              ).animate().fadeIn(delay: 500.ms),
            ),

            const Gap(24),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: AppTheme.textSecond,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.0,
      ),
    );
  }
}

class _ImageRow extends StatelessWidget {
  const _ImageRow({required this.scan});
  final DocumentScan scan;

  @override
  Widget build(BuildContext context) {
    if (scan.croppedImages.length > 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Scanned Pages (${scan.croppedImages.length})',
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Gap(6),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: scan.croppedImages.length,
              separatorBuilder: (_, __) => const Gap(10),
              itemBuilder: (ctx, idx) => ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  children: [
                    Image.file(
                      scan.croppedImages[idx],
                      height: 120,
                      width: 90,
                      fit: BoxFit.cover,
                    ),
                    Positioned(
                      bottom: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Page ${idx + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: _thumb(context, scan.originalImage, 'Original')),
        const Gap(12),
        Expanded(child: _thumb(context, scan.croppedImage, 'Cropped')),
      ],
    );
  }

  Widget _thumb(BuildContext ctx, File f, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w500),
        ),
        const Gap(4),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(
            f,
            height: 120,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
      ],
    );
  }
}

class _WarningsCard extends StatelessWidget {
  const _WarningsCard({required this.warnings});
  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: AppTheme.warning, size: 18),
              Gap(8),
              Text(
                'Warnings',
                style: TextStyle(
                    color: AppTheme.warning,
                    fontWeight: FontWeight.w700,
                    fontSize: 13),
              ),
            ],
          ),
          const Gap(8),
          ...warnings.map(
            (w) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• $w',
                style: const TextStyle(
                    color: AppTheme.textSecond, fontSize: 12, height: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuditSummaryCard extends StatelessWidget {
  const _AuditSummaryCard({required this.result});
  final VerificationResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Document Audit Summary',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const Gap(10),
          Row(
            children: [
              Expanded(
                child: _AuditMetricTile(
                  title: 'Item Errors',
                  value: '${result.itemTotalErrorsCount}',
                  isError: result.itemTotalErrorsCount > 0,
                  icon: Icons.receipt_long_rounded,
                ),
              ),
              const Gap(8),
              Expanded(
                child: _AuditMetricTile(
                  title: 'VAT Errors',
                  value: '${result.vatErrorsCount}',
                  isError: result.vatErrorsCount > 0,
                  icon: Icons.percent_rounded,
                ),
              ),
              const Gap(8),
              Expanded(
                child: _AuditMetricTile(
                  title: 'Grand Total',
                  value: result.grandTotalDiscrepancy ? 'Mismatch' : 'OK',
                  isError: result.grandTotalDiscrepancy,
                  icon: Icons.account_balance_wallet_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AuditMetricTile extends StatelessWidget {
  const _AuditMetricTile({
    required this.title,
    required this.value,
    required this.isError,
    required this.icon,
  });

  final String title;
  final String value;
  final bool isError;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppTheme.error : AppTheme.accent;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          const Gap(4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Gap(2),
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _DiscrepanciesCard extends StatelessWidget {
  const _DiscrepanciesCard({required this.notes});
  final List<String> notes;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.error.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 18),
              Gap(8),
              Text(
                'Financial & VAT Discrepancies',
                style: TextStyle(
                  color: AppTheme.error,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const Gap(8),
          ...notes.map(
            (n) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ',
                      style: TextStyle(
                          color: AppTheme.error,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Text(
                      n,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.result});
  final VerificationResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Financial & Tax Totals',
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14),
          ),
          const Gap(12),
          const Divider(height: 1),
          const Gap(12),

          // Subtotal
          if (result.subtotalCalculated != null) ...[
            _TotalRow(
              label: 'Computed Subtotal (Excl. VAT)',
              value: result.subtotalCalculated!,
            ),
            if (result.writtenSubtotal != null) ...[
              const Gap(6),
              _TotalRow(
                label: 'Written Subtotal',
                value: result.writtenSubtotal!,
              ),
            ],
            const Gap(8),
            const Divider(height: 1),
            const Gap(8),
          ],

          // Total VAT
          if (result.totalVatCalculated != null) ...[
            _TotalRow(
              label: 'Computed Total VAT',
              value: result.totalVatCalculated!,
              color: AppTheme.primary,
            ),
            if (result.writtenVatTotal != null) ...[
              const Gap(6),
              _TotalRow(
                label: 'Written VAT Total',
                value: result.writtenVatTotal!,
              ),
            ],
            const Gap(8),
            const Divider(height: 1),
            const Gap(8),
          ],

          // Grand Total
          _TotalRow(
            label: 'Computed Grand Total',
            value: result.computedTotal,
            color: AppTheme.primary,
          ),
          if (result.writtenTotal != null) ...[
            const Gap(6),
            _TotalRow(
              label: 'Written Grand Total',
              value: result.writtenTotal!,
            ),
          ],
          if (result.totalDifference != null) ...[
            const Gap(6),
            _TotalRow(
              label: 'Grand Total Variance',
              value: result.totalDifference!,
              color: result.grandTotalDiscrepancy
                  ? AppTheme.error
                  : AppTheme.accent,
              icon: result.grandTotalDiscrepancy
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
            ),
          ],
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.color = AppTheme.textPrimary,
    this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(color: AppTheme.textSecond, fontSize: 13)),
        ),
        if (icon != null) ...[
          Icon(icon, color: color, size: 14),
          const Gap(4),
        ],
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _EmptyItems extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: const Column(
        children: [
          Icon(Icons.table_rows_outlined, color: AppTheme.textMuted, size: 40),
          Gap(12),
          Text(
            'No line items could be extracted from this document.\n'
            'This may be due to poor image quality or unsupported handwriting.\n'
            'Please check the warnings above.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppTheme.textSecond, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _RawTextCard extends StatefulWidget {
  const _RawTextCard({required this.text});
  final String text;

  @override
  State<_RawTextCard> createState() => _RawTextCardState();
}

class _RawTextCardState extends State<_RawTextCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: 'Raw OCR Output'),
        const Gap(8),
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceHigh,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.text_snippet_outlined,
                        color: AppTheme.textMuted, size: 16),
                    const Gap(6),
                    const Text('Tap to expand/collapse',
                        style:
                            TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                    const Spacer(),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: AppTheme.textMuted,
                      size: 20,
                    ),
                  ],
                ),
                if (_expanded) ...[
                  const Gap(8),
                  const Divider(height: 1),
                  const Gap(8),
                  SelectableText(
                    widget.text.isEmpty ? '(no text extracted)' : widget.text,
                    style: const TextStyle(
                      color: AppTheme.textSecond,
                      fontSize: 12,
                      fontFamily: 'monospace',
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
