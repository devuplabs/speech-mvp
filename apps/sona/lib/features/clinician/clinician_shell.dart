import 'package:flutter/material.dart';
import 'package:sona/design_system/sona_colors.dart';

enum ClinicianRoute { today, clients, prep, triage, summary }

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

  // (label, route, implemented)
  // Unimplemented items are rendered as inactive and show a "coming soon"
  // tooltip rather than silently navigating back to Today.
  static const _navItems = [
    (label: 'Today', route: ClinicianRoute.today, implemented: true),
    (label: 'Clients', route: ClinicianRoute.today, implemented: false),
    (label: 'Intake forms', route: ClinicianRoute.today, implemented: false),
    (label: 'Resources', route: ClinicianRoute.today, implemented: false),
    (label: 'Reports', route: ClinicianRoute.today, implemented: false),
    (label: 'Billing', route: ClinicianRoute.today, implemented: false),
    (label: 'Settings', route: ClinicianRoute.today, implemented: false),
  ];

  static const _sidebarBreakpoint = 1024.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SonaColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < _sidebarBreakpoint) {
            return child;
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 240, child: _sidebar()),
              Expanded(child: child),
            ],
          );
        },
      ),
    );
  }

  Widget _sidebar() {
    return Container(
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
                final active = item.route == route && item.implemented;
                final disabled = !item.implemented;
                final navItem = Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Semantics(
                    button: item.implemented,
                    selected: active,
                    label: item.implemented ? item.label : '${item.label} (coming soon)',
                    child: Material(
                      color: active ? SonaColors.navActiveBg : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        onTap: disabled ? null : () => onNavigate(item.route),
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
                                  border: active ? null : Border.all(
                                    color: disabled ? SonaColors.border : SonaColors.chipBorder,
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item.label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                                    color: disabled
                                        ? SonaColors.textMuted
                                        : active
                                            ? SonaColors.primaryDark
                                            : SonaColors.textSecondary,
                                  ),
                                ),
                              ),
                              if (disabled)
                                const Text(
                                  'Soon',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: SonaColors.textMuted,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
                return navItem;
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
    );
  }
}
