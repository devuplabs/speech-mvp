import 'package:flutter/material.dart';
import 'package:sona/design_system/sona_colors.dart';
import 'package:sona/design_system/widgets/sona_text_field.dart';

class SonaYesNoField extends StatelessWidget {
  const SonaYesNoField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.detailLabel,
    this.detailValue = '',
    this.onDetailChanged,
    this.required = true,
    this.onAutoAdvance,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final String? detailLabel;
  final String detailValue;
  final ValueChanged<String>? onDetailChanged;
  final bool required;

  /// When non-null and [detailLabel] is null, the field will call this after
  /// selection to trigger an auto-advance to the next field or step.
  /// The caller is responsible for the 300ms delay and undo affordance.
  final VoidCallback? onAutoAdvance;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            required ? '$label *' : label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            children: ['yes', 'no'].map((opt) {
              final selected = value == opt;
              final display = opt == 'yes' ? 'Yes' : 'No';
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48, minWidth: 72),
                  child: ChoiceChip(
                    label: Text(display, style: const TextStyle(fontSize: 14)),
                    selected: selected,
                    onSelected: (_) {
                      onChanged(opt);
                      // Auto-advance only when no conditional detail is shown
                      if (detailLabel == null && onAutoAdvance != null) {
                        Future.delayed(const Duration(milliseconds: 300), onAutoAdvance!);
                      }
                    },
                    selectedColor: SonaColors.heroTint,
                    side: BorderSide(color: selected ? SonaColors.primary : SonaColors.border),
                  ),
                ),
              );
            }).toList(),
          ),
          if (value == 'yes' && detailLabel != null && onDetailChanged != null) ...[
            const SizedBox(height: 8),
            SonaTextField(
              label: detailLabel!,
              value: detailValue,
              onChanged: onDetailChanged!,
              maxLines: 3,
              required: true,
            ),
          ],
        ],
      ),
    );
  }
}
