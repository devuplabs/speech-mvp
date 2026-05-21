import 'package:flutter/material.dart';
import 'package:sona/design_system/sona_colors.dart';
import 'package:sona/design_system/widgets/parent_mobile_scaffold.dart';
import 'package:sona/design_system/widgets/sona_button.dart';
import 'package:sona/state/sona_app_state.dart';

class ParentFormScreen extends StatefulWidget {
  const ParentFormScreen({
    super.key,
    required this.state,
    required this.onBack,
    required this.onContinue,
  });

  final SonaAppState state;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  @override
  State<ParentFormScreen> createState() => _ParentFormScreenState();
}

class _ParentFormScreenState extends State<ParentFormScreen> {
  static const _options = [
    'Fussy eater (limited foods)',
    'Gagging or choking on textures',
    'Refuses to chew certain foods',
    'Only eats specific brands/colours',
    'None of the above',
  ];

  @override
  Widget build(BuildContext context) {
    final progress = widget.state.formStep / 8;

    return ParentMobileScaffold(
      header: _formHeader(progress),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: SonaColors.heroTint,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'FEEDING & EATING',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: SonaColors.primaryDark,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Does Aria have specific challenges with eating?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, height: 1.3),
          ),
          const SizedBox(height: 8),
          const Text(
            "Pick any that apply. We'll branch into more questions if needed.",
            style: TextStyle(fontSize: 14, color: SonaColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 16),
          ..._options.map(_chip),
          if (widget.state.selectedConcerns.contains('Fussy eater (limited foods)')) ...[
            const SizedBox(height: 16),
            _branchCard(),
          ],
        ],
      ),
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
        child: Row(
          children: [
            Expanded(
              child: SonaButton(
                label: 'Back',
                variant: SonaButtonVariant.secondary,
                expanded: true,
                onPressed: widget.onBack,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: SonaButton(
                label: 'Continue →',
                expanded: true,
                onPressed: widget.onContinue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formHeader(double progress) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: widget.onBack,
                icon: const Icon(Icons.chevron_left, size: 28),
                style: IconButton.styleFrom(
                  backgroundColor: SonaColors.surface,
                  side: const BorderSide(color: SonaColors.border),
                ),
              ),
              Expanded(
                child: Text(
                  'Step ${widget.state.formStep} of 8',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              OutlinedButton(
                onPressed: () {},
                child: const Text('Save & exit', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: SonaColors.border,
              color: SonaColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label) {
    final selected = widget.state.selectedConcerns.contains(label);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            if (selected) {
              widget.state.selectedConcerns.remove(label);
            } else {
              widget.state.selectedConcerns.add(label);
            }
          });
        },
        borderRadius: BorderRadius.circular(10),
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
              Container(
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
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _branchCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SonaColors.surface,
        border: Border.all(color: SonaColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: SonaColors.aiBadgeBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                alignment: Alignment.center,
                child: const Text('?', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              const Text(
                'BECAUSE YOU SAID “FUSSY EATER”',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: SonaColors.aiBadgeText),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Has Aria been seen by a dentist about this?',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Row(
            children: ['Yes', 'No', 'Not sure'].map((opt) {
              final selected = widget.state.dentistAnswer == opt;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(opt),
                  selected: selected,
                  onSelected: (_) {
                    setState(() => widget.state.dentistAnswer = opt);
                  },
                  selectedColor: SonaColors.heroTint,
                  side: BorderSide(color: selected ? SonaColors.primary : SonaColors.border),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
