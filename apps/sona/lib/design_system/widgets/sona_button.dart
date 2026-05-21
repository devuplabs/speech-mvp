import 'package:flutter/material.dart';
import 'package:sona/design_system/sona_colors.dart';

enum SonaButtonVariant { primary, secondary, ghost }

class SonaButton extends StatelessWidget {
  const SonaButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = SonaButtonVariant.primary,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final SonaButtonVariant variant;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final child = switch (variant) {
      SonaButtonVariant.primary => FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: SonaColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(64, 48),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          child: Text(label),
        ),
      SonaButtonVariant.secondary => OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: SonaColors.textPrimary,
            minimumSize: const Size(64, 48),
            side: const BorderSide(color: SonaColors.border),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Text(label),
        ),
      SonaButtonVariant.ghost => TextButton(
          onPressed: onPressed,
          child: Text(
            label,
            style: const TextStyle(
              color: SonaColors.textMuted,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
    };

    if (!expanded) return child;
    return SizedBox(width: double.infinity, child: child);
  }
}
