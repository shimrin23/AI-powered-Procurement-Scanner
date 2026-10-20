import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../models/verification_result.dart';
import '../theme.dart';

/// A card representing one extracted line item with its verification status.
/// Shows description, Qty, Unit Price, Written Amount, Calculated Amount,
/// and the difference. If low-confidence, the card is highlighted in amber.
class ExtractedFieldTile extends StatelessWidget {
  const ExtractedFieldTile({
    super.key,
    required this.index,
    required this.item,
  });

  final int index;
  final ItemVerification item;

  @override
  Widget build(BuildContext context) {
    final Color borderColor;
    final Color badgeColor;
    final IconData badgeIcon;
    final String badgeLabel;

    if (item.lowConfidence) {
      borderColor = AppTheme.warning.withOpacity(0.4);
      badgeColor = AppTheme.warning;
      badgeIcon = Icons.warning_amber_rounded;
      badgeLabel = 'Low Confidence — Review';
    } else if (item.matches) {
      borderColor = AppTheme.accent.withOpacity(0.3);
      badgeColor = AppTheme.accent;
      badgeIcon = Icons.check_circle_rounded;
      badgeLabel = 'Match';
    } else {
      borderColor = AppTheme.error.withOpacity(0.4);
      badgeColor = AppTheme.error;
      badgeIcon = Icons.cancel_rounded;
      badgeLabel = 'Mismatch';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ──────────────────────────────────────────────────
            Row(
              children: [
                _IndexBadge(index: index + 1),
                const Gap(10),
                Expanded(
                  child: Text(
                    item.description.isEmpty
                        ? 'Item ${index + 1}'
                        : item.description,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Gap(8),
                _Badge(icon: badgeIcon, label: badgeLabel, color: badgeColor),
              ],
            ),

            const Gap(12),
            const Divider(height: 1),
            const Gap(10),

            // ── Values grid ─────────────────────────────────────────────────
            Row(
              children: [
                _ValueCell(label: 'Quantity', value: item.rawQuantity),
                _ValueCell(label: 'Unit Price', value: item.rawUnitPrice),
                _ValueCell(label: 'Written Amt', value: item.writtenAmount),
              ],
            ),

            const Gap(8),

            Row(
              children: [
                _ValueCell(
                  label: 'Calc. Amount',
                  value: item.calculatedAmount,
                  color: AppTheme.primary,
                ),
                _ValueCell(
                  label: 'Difference',
                  value: item.matches ? '0.00' : item.difference,
                  color: item.matches ? AppTheme.accent : AppTheme.error,
                  bold: true,
                ),
                const Spacer(),
              ],
            ),

            if (item.lowConfidence) ...[
              const Gap(8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.edit_note_rounded,
                        color: AppTheme.warning, size: 14),
                    Gap(6),
                    Expanded(
                      child: Text(
                        'Low OCR confidence. Please manually verify these values.',
                        style: TextStyle(
                            color: AppTheme.warning, fontSize: 11, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _IndexBadge extends StatelessWidget {
  const _IndexBadge({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Text(
          '$index',
          style: const TextStyle(
            color: AppTheme.primary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const Gap(4),
          Text(
            label,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ValueCell extends StatelessWidget {
  const _ValueCell({
    required this.label,
    required this.value,
    this.color = AppTheme.textPrimary,
    this.bold = false,
  });

  final String label;
  final String value;
  final Color color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w500),
          ),
          const Gap(2),
          Text(
            value.isEmpty ? '—' : value,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
