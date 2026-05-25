import 'package:flutter/material.dart';
import 'package:sona/design_system/sona_colors.dart';

/// Shared list row for clinician case lists (Today, Clients).
class ClinicianCaseRow extends StatelessWidget {
  const ClinicianCaseRow({
    super.key,
    required this.leading,
    required this.name,
    required this.meta,
    required this.statusLabel,
    required this.onTap,
    this.highlight = false,
  });

  final String leading;
  final String name;
  final String meta;
  final String statusLabel;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final ready = statusLabel == 'Ready';
    return Semantics(
      button: true,
      label: '$name, $meta, status $statusLabel',
      child: InkWell(
        onTap: onTap,
        child: Container(
          color: highlight ? SonaColors.heroTint.withValues(alpha: 0.35) : null,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Text(leading, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(meta, style: const TextStyle(fontSize: 12, color: SonaColors.textMuted)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: ready ? SonaColors.successBg : SonaColors.warningBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: ready ? SonaColors.successText : SonaColors.warningText,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: SonaColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
