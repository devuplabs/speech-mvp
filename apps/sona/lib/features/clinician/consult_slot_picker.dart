import 'package:flutter/material.dart';
import 'package:sona/design_system/sona_colors.dart';

/// Simple list of available consult slots from the API.
class ConsultSlotPicker extends StatelessWidget {
  const ConsultSlotPicker({
    super.key,
    required this.slots,
    required this.selectedStart,
    required this.onSelected,
    this.loading = false,
  });

  final List<Map<String, dynamic>> slots;
  final String? selectedStart;
  final ValueChanged<String> onSelected;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final available = slots.where((s) => s['available'] == true).toList();
    if (available.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No open slots in the next two weeks. Adjust consult windows in Settings.',
          style: TextStyle(fontSize: 13, color: SonaColors.textSecondary),
        ),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 200),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: available.length.clamp(0, 24),
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final slot = available[i];
          final start = slot['start'] as String;
          final label = _formatSlot(start);
          final selected = start == selectedStart;
          return ListTile(
            dense: true,
            title: Text(label, style: TextStyle(fontWeight: selected ? FontWeight.w600 : FontWeight.w500)),
            trailing: selected ? const Icon(Icons.check_circle, color: SonaColors.primary, size: 20) : null,
            onTap: () => onSelected(start),
          );
        },
      ),
    );
  }

  String _formatSlot(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    final local = d.toLocal();
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final day = days[local.weekday - 1];
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$day ${local.day} ${local.month} · $h:$m';
  }
}
