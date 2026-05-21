import 'package:flutter/material.dart';
import 'package:sona/design_system/sona_colors.dart';
import 'package:sona/utils/intake_validation.dart';

class SonaDateField extends StatefulWidget {
  const SonaDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.required = false,
    this.errorText,
    this.firstDate,
    this.lastDate,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final bool required;
  final String? errorText;
  final DateTime? firstDate;
  final DateTime? lastDate;

  @override
  State<SonaDateField> createState() => _SonaDateFieldState();
}

class _SonaDateFieldState extends State<SonaDateField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(SonaDateField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    DateTime initial = now;
    if (IntakeValidation.isDdMmYyyy(widget.value)) {
      final parts = widget.value.split('/').map((p) => p.trim()).toList();
      initial = DateTime(
        int.parse(parts[2]),
        int.parse(parts[1]),
        int.parse(parts[0]),
      );
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? now : initial,
      firstDate: widget.firstDate ?? DateTime(1900),
      lastDate: widget.lastDate ?? now,
      helpText: 'Select date',
    );
    if (picked != null) {
      widget.onChanged(IntakeValidation.formatDdMmYyyy(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    final labelText = widget.required ? '${widget.label} *' : widget.label;
    final borderColor =
        widget.errorText != null ? SonaColors.dangerText : SonaColors.border;
    final focusColor =
        widget.errorText != null ? SonaColors.dangerText : SonaColors.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            labelText,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: SonaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            readOnly: true,
            controller: _controller,
            onTap: () => _pick(context),
            decoration: InputDecoration(
              hintText: 'DD / MM / YYYY',
              errorText: widget.errorText,
              suffixIcon: IconButton(
                tooltip: 'Open calendar',
                icon: const Icon(Icons.calendar_today_outlined, size: 20),
                onPressed: () => _pick(context),
              ),
              filled: true,
              fillColor: SonaColors.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: SonaColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: focusColor, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
