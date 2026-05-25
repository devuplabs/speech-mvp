import 'package:flutter/material.dart';
import 'package:sona/features/parent/parent_review_screen.dart';
import 'package:sona/state/sona_app_state.dart';

/// Read-only view of a parent's submitted or in-progress intake answers.
class ClinicianIntakeReviewScreen extends StatelessWidget {
  const ClinicianIntakeReviewScreen({
    super.key,
    required this.state,
    required this.onBack,
  });

  final SonaAppState state;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
          ),
          child: Row(
            children: [
              IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back)),
              const Expanded(
                child: Text(
                  'Parent intake (read-only)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ParentReviewScreen(
            state: state,
            readOnly: true,
            onBack: onBack,
            onSubmit: () {},
            onEditStep: (_) {},
          ),
        ),
      ],
    );
  }
}
