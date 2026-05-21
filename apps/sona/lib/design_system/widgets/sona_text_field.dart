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
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final String? hint;
  final bool required;
  final int maxLines;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;

  @override
  State<SonaTextField> createState() => _SonaTextFieldState();
}

class _SonaTextFieldState extends State<SonaTextField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(SonaTextField oldWidget) {
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

  @override
  Widget build(BuildContext context) {
    final labelText = widget.required ? '${widget.label} *' : widget.label;
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
            controller: _controller,
            onChanged: widget.onChanged,
            maxLines: widget.maxLines,
            keyboardType: widget.keyboardType,
            autofillHints: widget.autofillHints,
            decoration: InputDecoration(
              hintText: widget.hint ?? 'Tap to enter',
              filled: true,
              fillColor: SonaColors.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: SonaColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: SonaColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: SonaColors.primary, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
