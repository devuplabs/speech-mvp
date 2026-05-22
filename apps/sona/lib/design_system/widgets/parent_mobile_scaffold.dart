import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:sona/design_system/sona_colors.dart';
import 'package:sona/design_system/widgets/mobile_status_bar.dart';

/// Responsive column widths for the parent intake form.
/// On narrow devices the form fills the width; on wider viewports it centers
/// in a comfortable reading column rather than a narrow 375px phone shell.
double _formColumnWidth(double screenWidth) {
  if (screenWidth < 480) return screenWidth;           // phone: full width
  if (screenWidth < 768) return min(screenWidth, 480); // large phone / small tablet
  if (screenWidth < 1024) return 600;                  // tablet portrait
  return 720;                                          // tablet landscape / desktop
}

class ParentMobileScaffold extends StatelessWidget {
  const ParentMobileScaffold({
    super.key,
    required this.body,
    this.header,
    this.footer,
    this.showStatusBar = true,
  });

  final Widget body;
  final Widget? header;
  final Widget? footer;
  final bool showStatusBar;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final columnWidth = _formColumnWidth(screenWidth);
    // Row gives the inner Column a bounded height; Center + Expanded renders blank on web.
    return Scaffold(
      backgroundColor: SonaColors.background,
      body: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: columnWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showStatusBar && screenWidth < 480) const MobileStatusBar(),
                  ?header,
                  Expanded(child: body),
                  ?footer,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
