import 'package:flutter/material.dart';
import 'package:sona/design_system/sona_colors.dart';
import 'package:sona/design_system/widgets/sona_button.dart';

typedef SaveAvailabilityRules = Future<void> Function(List<Map<String, dynamic>> rules);

const _weekdays = [
  (1, 'Mon'),
  (2, 'Tue'),
  (3, 'Wed'),
  (4, 'Thu'),
  (5, 'Fri'),
  (6, 'Sat'),
  (7, 'Sun'),
];

class ClinicianSettingsScreen extends StatefulWidget {
  const ClinicianSettingsScreen({
    super.key,
    required this.initialRules,
    required this.onSave,
  });

  final List<Map<String, dynamic>> initialRules;
  final SaveAvailabilityRules onSave;

  @override
  State<ClinicianSettingsScreen> createState() => _ClinicianSettingsScreenState();
}

class _ClinicianSettingsScreenState extends State<ClinicianSettingsScreen> {
  late final Map<int, bool> _enabled;
  late final Map<int, int> _startMin;
  late final Map<int, int> _endMin;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _enabled = {for (final w in _weekdays) w.$1: false};
    _startMin = {for (final w in _weekdays) w.$1: 9 * 60};
    _endMin = {for (final w in _weekdays) w.$1: 20 * 60};
    for (final r in widget.initialRules) {
      final wd = r['weekday'] as int;
      _enabled[wd] = r['active'] as bool? ?? true;
      _startMin[wd] = r['startMinuteLocal'] as int? ?? 9 * 60;
      _endMin[wd] = r['endMinuteLocal'] as int? ?? 20 * 60;
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final rules = <Map<String, dynamic>>[];
      for (final (wd, _) in _weekdays) {
        if (_enabled[wd] != true) continue;
        rules.add({
          'weekday': wd,
          'startMinuteLocal': _startMin[wd]!,
          'endMinuteLocal': _endMin[wd]!,
          'timezone': 'Europe/London',
          'active': true,
        });
      }
      await widget.onSave(rules);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Consult windows saved.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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
          child: const Text('Settings', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Consult windows',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Free 20-minute consults can only be booked inside these windows (Europe/London).',
                  style: TextStyle(fontSize: 13, color: SonaColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 20),
                ..._weekdays.map((w) => _dayRow(w.$1, w.$2)),
                const SizedBox(height: 24),
                SonaButton(label: _busy ? 'Saving…' : 'Save consult windows', onPressed: _busy ? null : _save),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _dayRow(int weekday, String label) {
    final on = _enabled[weekday] == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Switch(
            value: on,
            onChanged: (v) => setState(() => _enabled[weekday] = v),
          ),
          if (on) ...[
            Expanded(child: _timeDropdown('Start', _startMin[weekday]!, (m) => setState(() => _startMin[weekday] = m))),
            const SizedBox(width: 8),
            Expanded(child: _timeDropdown('End', _endMin[weekday]!, (m) => setState(() => _endMin[weekday] = m))),
          ],
        ],
      ),
    );
  }

  Widget _timeDropdown(String label, int minute, ValueChanged<int> onChanged) {
    final options = <int>[];
    for (var m = 8 * 60; m <= 21 * 60; m += 30) {
      options.add(m);
    }
    return DropdownButtonFormField<int>(
      value: options.contains(minute) ? minute : options.first,
      decoration: InputDecoration(labelText: label, isDense: true),
      items: [
        for (final m in options)
          DropdownMenuItem(
            value: m,
            child: Text('${m ~/ 60}:${(m % 60).toString().padLeft(2, '0')}'),
          ),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}
