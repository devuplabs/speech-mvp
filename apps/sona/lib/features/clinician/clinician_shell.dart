import 'package:flutter/material.dart';
import 'package:sona/design_system/sona_colors.dart';

enum ClinicianRoute { today, prep, triage, summary }

class ClinicianShell extends StatelessWidget {
  const ClinicianShell({
    super.key,
    required this.route,
    required this.onNavigate,
    required this.child,
  });

  final ClinicianRoute route;
  final ValueChanged<ClinicianRoute> onNavigate;
  final Widget child;

  static const _navItems = [
    ('Today', ClinicianRoute.today),
    ('Clients', ClinicianRoute.today),
    ('Intake forms', ClinicianRoute.today),
    ('Resources', ClinicianRoute.today),
    ('Reports', ClinicianRoute.today),
    ('Billing', ClinicianRoute.today),
    ('Settings', ClinicianRoute.today),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SonaColors.background,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 240,
            child: Container(
              decoration: const BoxDecoration(
                color: SonaColors.surface,
                border: Border(right: BorderSide(color: SonaColors.border)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: SonaColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: const Text('S', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 10),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Sona', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text('Monal Gajjar SLT', style: TextStyle(fontSize: 11, color: SonaColors.textMuted)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Column(
                      children: _navItems.map((item) {
                        final active = item.$1 == 'Today' && route == ClinicianRoute.today;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Material(
                            color: active ? SonaColors.navActiveBg : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              onTap: () => onNavigate(item.$2),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 18,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        color: active ? SonaColors.primary : Colors.transparent,
                                        border: active ? null : Border.all(color: SonaColors.chipBorder, width: 1.5),
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      item.$1,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                                        color: active ? SonaColors.primaryDark : SonaColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: SonaColors.border)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(color: SonaColors.accent, shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: const Text('MG', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Monal Gajjar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              Text('HCPC SLT01234', style: TextStyle(fontSize: 10, color: SonaColors.textMuted)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
