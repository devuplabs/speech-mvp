import 'package:flutter/material.dart';
import 'package:sona/design_system/sona_colors.dart';

class SonaTextField extends StatefulWidget {
  const SonaTextField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
    this.required = false,
    this.maxLines = 1,
    this.keyboardType,
    this.autofillHints,
    this.errorText,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final String? hint;
  final bool required;
  final int maxLines;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final String? errorText;

  @override
  State<SonaTextField> createState() => _SonaTextFieldState();
}

class _SonaTextFieldState extends State<SonaTextField> {
  late final TextEditingController _controller;

  // Flutter web routes IME edits through a single shared hidden <input>; relying on
  // TextField.onChanged means rapid focus changes (or programmatic input from
  // browser autofill / Playwright) can drop keystrokes before our callback fires.
  // Listening on the controller catches every committed text change regardless of
  // the input pathway, which keeps IntakeFormData in sync with what the user sees.
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
  void didUpdateWidget(SonaTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
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

  @override
  Widget build(BuildContext context) {
    final labelText = widget.required ? '${widget.label} *' : widget.label;
    final hasError = widget.errorText != null;
    final borderColor = hasError ? SonaColors.dangerText : SonaColors.border;
    final focusColor = hasError ? SonaColors.dangerText : SonaColors.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            labelText,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: hasError ? SonaColors.dangerText : SonaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _controller,
            maxLines: widget.maxLines,
            keyboardType: widget.keyboardType,
            autofillHints: widget.autofillHints,
            decoration: InputDecoration(
              hintText: widget.hint ?? 'Tap to enter',
              errorText: widget.errorText,
              filled: true,
              fillColor: SonaColors.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: borderColor),
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
