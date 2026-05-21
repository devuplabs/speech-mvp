import 'package:flutter/material.dart';
import 'package:sona/design_system/sona_colors.dart';
import 'package:sona/design_system/widgets/mobile_status_bar.dart';

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
    // Row gives the inner Column a bounded height; Center + Expanded often renders blank on web.
    return Scaffold(
      backgroundColor: SonaColors.background,
      body: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 375,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showStatusBar) const MobileStatusBar(),
                  if (header != null) header!,
                  Expanded(child: body),
                  if (footer != null) footer!,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
