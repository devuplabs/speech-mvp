import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sona/design_system/sona_colors.dart';
import 'package:sona/design_system/widgets/sona_button.dart';
import 'package:sona/features/clinician/clinician_clients_screen.dart';
import 'package:sona/state/sona_app_state.dart';

class ClinicianIntakeFormsScreen extends StatelessWidget {
  const ClinicianIntakeFormsScreen({
    super.key,
    required this.items,
    required this.onRefresh,
    required this.onOpenReview,
    required this.onResendLink,
    required this.onRevokeLink,
    required this.onLock,
  });

  final List<Map<String, dynamic>> items;
  final Future<void> Function() onRefresh;
  final ValueChanged<String> onOpenReview;
  final Future<String?> Function(String caseId) onResendLink;
  final Future<void> Function(String caseId) onRevokeLink;
  final Future<void> Function(String caseId) onLock;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          decoration: const BoxDecoration(
            color: SonaColors.surface,
            border: Border(bottom: BorderSide(color: SonaColors.border)),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text('Intake forms', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ),
              TextButton(onPressed: () => onRefresh(), child: const Text('Refresh')),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? const Center(
                  child: Text(
                    'No intake forms yet. Register a patient from Clients.',
                    style: TextStyle(color: SonaColors.textSecondary),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(32),
                  itemCount: items.length,
                  itemBuilder: (context, i) => _row(context, items[i]),
                ),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, Map<String, dynamic> item) {
    final caseId = item['caseId'] as String;
    final name = (item['childDisplayName'] as String?) ?? 'Child';
    final status = (item['status'] as String?) ?? 'sent';
    final templateId = (item['templateId'] as String?) ?? 'full';
    final locked = item['locked'] as bool? ?? false;
    final last = _relative(item['lastActivityAt'] as String?);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SonaColors.surface,
        border: Border.all(color: SonaColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              ),
              _statusChip(status),
              if (locked) ...[
                const SizedBox(width: 8),
                const Text('Locked', style: TextStyle(fontSize: 11, color: SonaColors.textMuted)),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text('$templateId template · $last', style: const TextStyle(fontSize: 12, color: SonaColors.textMuted)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(onPressed: () => onOpenReview(caseId), child: const Text('Open')),
              TextButton(
                onPressed: () async {
                  final url = await onResendLink(caseId);
                  if (url != null && context.mounted) {
                    await showIntakeLinkCopiedSnackBar(context, url: url);
                  }
                },
                child: const Text('Resend link'),
              ),
              TextButton(
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Revoke link?'),
                      content: const Text('The parent will not be able to use the current magic link.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Revoke')),
                      ],
                    ),
                  );
                  if (ok == true) await onRevokeLink(caseId);
                },
                child: const Text('Revoke'),
              ),
              if (!locked)
                TextButton(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Lock intake?'),
                        content: const Text(
                          'The parent will no longer be able to edit their answers.',
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Lock')),
                        ],
                      ),
                    );
                    if (ok == true) await onLock(caseId);
                  },
                  child: const Text('Lock'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final label = switch (status) {
      'in_progress' => 'In progress',
      'submitted' => 'Submitted',
      'expired' => 'Expired',
      _ => 'Sent',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: SonaColors.warningBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  String _relative(String? iso) {
    if (iso == null) return 'Recently';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return 'Recently';
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    return 'Just now';
  }
}
