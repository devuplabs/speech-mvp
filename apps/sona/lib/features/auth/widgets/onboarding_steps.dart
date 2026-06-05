import 'package:flutter/material.dart';
import 'package:sona/design_system/sona_colors.dart';

/// The 4-step onboarding progress header
/// (Account — Plan & seats — Practice — Clinicians), shared by screens 02–05.
class OnboardingSteps extends StatelessWidget {
  const OnboardingSteps({super.key, required this.currentStep});

  /// 1-based index of the active step.
  final int currentStep;

  static const _labels = ['Account', 'Plan & seats', 'Practice', 'Clinicians'];

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < _labels.length; i++) {
      final step = i + 1;
      children.add(_StepChip(
        number: step,
        label: _labels[i],
        done: step <= currentStep,
        current: step == currentStep,
      ));
      if (i < _labels.length - 1) {
        children.add(const Text(
          '—',
          style: TextStyle(fontSize: 12, color: SonaColors.border),
        ));
      }
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }
}

class _StepChip extends StatelessWidget {
  const _StepChip({
    required this.number,
    required this.label,
    required this.done,
    required this.current,
  });

  final int number;
  final String label;
  final bool done;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final labelColor = current
        ? SonaColors.primary
        : (done ? SonaColors.textSecondary : SonaColors.textMuted);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: done ? SonaColors.primary : SonaColors.surface,
            borderRadius: BorderRadius.circular(11),
            border: done ? null : Border.all(color: SonaColors.chipBorder),
          ),
          alignment: Alignment.center,
          child: Text(
            '$number',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: done ? Colors.white : SonaColors.textMuted,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: labelColor,
          ),
        ),
      ],
    );
  }
}
