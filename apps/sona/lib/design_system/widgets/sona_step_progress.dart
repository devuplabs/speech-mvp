import 'package:flutter/material.dart';
import 'package:sona/design_system/sona_colors.dart';

class SonaStepProgress extends StatelessWidget {
  const SonaStepProgress({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final value = (currentStep / totalSteps).clamp(0.0, 1.0);
    final percent = (value * 100).round();

    return Semantics(
      label: 'Form progress',
      value: 'Step $currentStep of $totalSteps, $percent percent',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LinearProgressIndicator(
          value: value,
          minHeight: 6,
          backgroundColor: SonaColors.border,
          color: SonaColors.primary,
        ),
      ),
    );
  }
}
