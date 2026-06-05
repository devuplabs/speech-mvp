import 'package:flutter/material.dart';
import 'package:sona/design_system/sona_colors.dart';

/// Multi-select option chip — keyboard-focusable, 48dp min height, toggle semantics.
class SonaSelectChip extends StatelessWidget {
  const SonaSelectChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onChanged,
    this.pill = false,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onChanged;

  /// Compact pill style (teal-filled when selected) used by the practice
  /// specialties multi-select; defaults to the checkbox-row style.
  final bool pill;

  @override
  Widget build(BuildContext context) {
    if (pill) return _pill();
    return Semantics(
      button: true,
      toggled: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onChanged(!selected),
          borderRadius: BorderRadius.circular(10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: selected ? SonaColors.heroTint : SonaColors.surface,
                border: Border.all(
                  color: selected ? SonaColors.primary : SonaColors.border,
                  width: selected ? 1.5 : 1,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  _checkboxVisual(selected),
                  const SizedBox(width: 12),
                  Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill() {
    return Semantics(
      button: true,
      toggled: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onChanged(!selected),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? SonaColors.primary : SonaColors.surface,
              border: Border.all(
                color: selected ? SonaColors.primary : SonaColors.chipBorder,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: selected ? Colors.white : SonaColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _checkboxVisual(bool selected) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: selected ? SonaColors.primary : Colors.transparent,
        border: Border.all(
          color: selected ? SonaColors.primary : SonaColors.chipBorder,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: selected
          ? const Text('✓', style: TextStyle(color: Colors.white, fontSize: 12))
          : null,
    );
  }
}
