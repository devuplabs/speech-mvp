import 'package:flutter/material.dart';

/// Page heading with screen-reader header semantics (WCAG).
class SonaPageTitle extends StatelessWidget {
  const SonaPageTitle(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(text, style: style),
    );
  }
}
