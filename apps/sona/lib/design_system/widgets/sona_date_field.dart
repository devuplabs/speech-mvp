import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // Mirrors SonaTextField: Flutter web routes IME edits through a single shared
  // hidden <input>, so listening on the controller (rather than only onChanged)
  // catches every committed change regardless of input pathway. This is what
  // makes the field reliably fillable by keyboard from automation (Playwright
  // pressSequentially) — far more robust on headless Flutter web than tapping
  // through the Material date-picker dialog, whose grid renders unreliably in
  // the accessibility tree. See e2e/README.md "Date-picker E2E strategy".
  bool _suppressListener = false;
  String _lastReported = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _lastReported = widget.value;
    _controller.addListener(_handleControllerChange);
  }

  void _handleControllerChange() {
    if (_suppressListener) return;
    final text = _controller.text;
    if (text == _lastReported) return;
    _lastReported = text;
    widget.onChanged(text);
  }

  @override
  void didUpdateWidget(SonaDateField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value == widget.value) return;

    // Parent pushed a new [value]. Do not clobber live typing when the model is
    // still stale (common on Flutter web: a keystroke fires onChanged →
    // setState → rebuild before the model has actually absorbed the new text).
    // Without this guard a fast Playwright pressSequentially would have its
    // characters reset to empty mid-stream and the date would never commit.
    if (widget.value.isEmpty && _controller.text.isNotEmpty) {
      _lastReported = _controller.text;
      widget.onChanged(_controller.text);
      return;
    }

    if (_controller.text != widget.value) {
      _suppressListener = true;
      _controller.text = widget.value;
      _lastReported = widget.value;
      _suppressListener = false;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChange);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    DateTime initial = now;
    if (IntakeValidation.isDdMmYyyy(_controller.text)) {
      final parts = _controller.text.split('/').map((p) => p.trim()).toList();
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
      // Text-input mode is more reliable on mobile web than the calendar grid.
      initialEntryMode: DatePickerEntryMode.input,
    );
    if (picked != null) {
      final formatted = IntakeValidation.formatDdMmYyyy(picked);
      _suppressListener = true;
      _controller.text = formatted;
      _suppressListener = false;
      _lastReported = formatted;
      widget.onChanged(formatted);
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
            // Editable by keyboard so the value can be typed directly. The
            // calendar icon still opens the Material picker for users who
            // prefer it. Both paths funnel through the same onChanged.
            controller: _controller,
            keyboardType: TextInputType.datetime,
            // Belt-and-braces with the controller listener: on Flutter web the
            // shared-input pathway sometimes commits via onChanged before the
            // listener observes it. Reporting from both (guarded by
            // _lastReported) guarantees the parent model sees every change.
            onChanged: (text) {
              if (_suppressListener) return;
              if (text == _lastReported) return;
              _lastReported = text;
              widget.onChanged(text);
            },
            inputFormatters: [
              // DD / MM / YYYY — digits, spaces and slashes only.
              FilteringTextInputFormatter.allow(RegExp(r'[0-9/ ]')),
              LengthLimitingTextInputFormatter(14),
            ],
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
