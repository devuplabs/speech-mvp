import 'package:flutter/material.dart';
import 'package:sona/design_system/sona_colors.dart';
import 'package:sona/design_system/widgets/sona_select_chip.dart';
import 'package:sona/models/intake_constants.dart';

/// Isolated checklist — toggles repaint only this widget, not the full intake step.
class DifficultyChecklist extends StatefulWidget {
  const DifficultyChecklist({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  State<DifficultyChecklist> createState() => _DifficultyChecklistState();
}

class _DifficultyChecklistState extends State<DifficultyChecklist> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.selected);
  }

  @override
  void didUpdateWidget(DifficultyChecklist oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      _selected = Set<String>.from(widget.selected);
    }
  }

  void _toggle(String label, bool value) {
    setState(() {
      if (value) {
        _selected.add(label);
      } else {
        _selected.remove(label);
      }
    });
    widget.onChanged(Set<String>.from(_selected));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final section in IntakeConstants.difficultySections) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Text(
              section.title,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: SonaColors.primaryDark,
                letterSpacing: 0.4,
              ),
            ),
          ),
          ...section.options.map(
            (opt) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SonaSelectChip(
                key: ValueKey(opt),
                label: opt,
                selected: _selected.contains(opt),
                onChanged: (v) => _toggle(opt, v),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
