import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sona/config/env.dart';
import 'package:sona/design_system/sona_colors.dart';
import 'package:sona/design_system/widgets/sona_button.dart';
import 'package:sona/features/clinician/clinician_parent_summary_screen.dart';
import 'package:sona/features/clinician/clinician_prep_screen.dart';
import 'package:sona/features/clinician/clinician_shell.dart';
import 'package:sona/features/clinician/clinician_today_screen.dart';
import 'package:sona/features/clinician/clinician_triage_screen.dart';
import 'package:sona/features/parent/parent_form_screen.dart';
import 'package:sona/features/parent/parent_review_screen.dart';
import 'package:sona/features/parent/parent_summary_screen.dart';
import 'package:sona/features/parent/parent_welcome_screen.dart';
import 'package:sona/services/api_client.dart';
import 'package:sona/state/sona_app_state.dart';

enum SonaRoute {
  launcher,
  parentWelcome,
  parentForm,
  parentReview,
  parentSummary,
  clinicianToday,
  clinicianPrep,
  clinicianTriage,
  clinicianSummaryPreview,
}

class SonaAppShell extends StatefulWidget {
  const SonaAppShell({super.key});

  @override
  State<SonaAppShell> createState() => _SonaAppShellState();
}

class _SonaAppShellState extends State<SonaAppShell> {
  final _api = SonaApiClient();
  final _state = SonaAppState();

  SonaRoute _route = SonaRoute.launcher;
  ClinicianRoute _clinicianNav = ClinicianRoute.today;
  bool _busy = false;
  String? _status;
  String? _parentSummaryHtml;

  Future<void> _run(Future<void> Function() fn, {String? label}) async {
    setState(() {
      _busy = true;
      if (label != null) _status = '$label…';
    });
    try {
      await fn();
    } catch (e) {
      setState(() => _status = 'Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _ensureTenant() async {
    _state.tenantId ??= await _api.bootstrapDemoTenant();
  }

  Future<void> _refreshCase() async {
    final id = _state.caseId;
    if (id == null) return;
    final detail = await _api.getCase(id);
    final caseMap = detail['case'] as Map<String, dynamic>?;
    final status = caseMap?['status'] as String? ?? '';
    setState(() {
      _status = 'Case: $status';
      _state.prepStatus = status.contains('intake') || status == 'new' ? 'Drafting' : 'Ready';
      if (caseMap?['childDisplayName'] != null) {
        _state.childName = caseMap!['childDisplayName'] as String;
      }
    });
  }

  Future<void> _submitParentIntake() async {
    if (!_state.consentGuardian || !_state.consentPrivacy || !_state.consentAccurate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please confirm all checkboxes before submitting.')),
      );
      return;
    }
    await _run(() async {
      await _ensureTenant();
      final caseRow = await _api.createCase(
        tenantId: _state.tenantId!,
        childDisplayName: _state.childName,
        parentEmail: _state.parentEmail,
      );
      final caseId = caseRow['id'] as String;
      await _api.submitIntake(
        caseId,
        answers: {
          'concerns': _state.selectedConcerns.toList(),
          'dentist_seen': _state.dentistAnswer,
          'consent': true,
        },
        parentEmail: _state.parentEmail,
        childDisplayName: _state.childName,
      );
      setState(() {
        _state.caseId = caseId;
        _state.prepStatus = 'Drafting';
        _status = 'Intake submitted';
        _route = SonaRoute.clinicianToday;
        _clinicianNav = ClinicianRoute.today;
      });
      await _refreshCase();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Intake submitted — clinician prep is updating.')),
        );
      }
    }, label: 'Submit intake');
  }

  Future<void> _publishSummary() async {
    final id = _state.caseId;
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No case yet — complete parent intake first.')),
      );
      return;
    }
    await _run(() async {
      await _api.recordTriage(id, outcome: _state.triageOutcome, reason: 'MVP demo');
      await _api.publishParentSummary(id);
      final html = await _api.fetchParentSummaryHtml(id);
      setState(() {
        _parentSummaryHtml = html;
        _route = SonaRoute.clinicianSummaryPreview;
        _status = 'Summary published to portal';
      });
    }, label: 'Publish summary');
  }

  Future<void> _loadParentSummary() async {
    final id = _state.caseId;
    if (id == null) return;
    await _run(() async {
      final html = await _api.fetchParentSummaryHtml(id);
      setState(() {
        _parentSummaryHtml = html;
        _route = SonaRoute.parentSummary;
      });
    }, label: 'Load summary');
  }

  void _go(SonaRoute route) => setState(() => _route = route);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SonaColors.background,
      body: switch (_route) {
        SonaRoute.launcher => _launcher(),
        SonaRoute.parentWelcome => ParentWelcomeScreen(onGetStarted: () => _go(SonaRoute.parentForm)),
        SonaRoute.parentForm => ParentFormScreen(
            state: _state,
            onBack: () => _go(SonaRoute.parentWelcome),
            onContinue: () => _go(SonaRoute.parentReview),
          ),
        SonaRoute.parentReview => ParentReviewScreen(
            state: _state,
            busy: _busy,
            onBack: () => _go(SonaRoute.parentForm),
            onSubmit: _submitParentIntake,
          ),
        SonaRoute.parentSummary => ParentSummaryScreen(
            summaryHtml: _parentSummaryHtml,
            onBack: () => _go(SonaRoute.launcher),
          ),
        SonaRoute.clinicianToday ||
        SonaRoute.clinicianPrep ||
        SonaRoute.clinicianTriage ||
        SonaRoute.clinicianSummaryPreview =>
          _clinicianBody(),
      },
      bottomNavigationBar: _route == SonaRoute.launcher
          ? null
          : Material(
              elevation: 2,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () => _go(SonaRoute.launcher),
                        child: const Text('Home'),
                      ),
                      const Spacer(),
                      if (_state.caseId != null)
                        TextButton(
                          onPressed: _busy ? null : _loadParentSummary,
                          child: const Text('Parent summary'),
                        ),
                      if (_status != null || kDebugMode)
                        Expanded(
                          child: Text(
                            _status ?? (kDebugMode ? Env.apiBaseUrl : ''),
                            textAlign: TextAlign.end,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _launcher() {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: SonaColors.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: const Text('S', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 16),
              Semantics(
                header: true,
                child: const Text(
                  'Speech Therapy MVP',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Intake & first-session co-pilot — matches Figma flows',
                textAlign: TextAlign.center,
                style: TextStyle(color: SonaColors.textSecondary),
              ),
              const SizedBox(height: 32),
              SonaButton(
                label: 'Parent intake (mobile)',
                onPressed: () => _go(SonaRoute.parentWelcome),
              ),
              const SizedBox(height: 12),
              SonaButton(
                label: 'Clinician workspace (desktop)',
                variant: SonaButtonVariant.secondary,
                onPressed: () {
                  _go(SonaRoute.clinicianToday);
                  _refreshCase();
                },
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _clinicianBody() {
    final child = switch (_route) {
      SonaRoute.clinicianPrep => ClinicianPrepScreen(
          onBackToday: () => _go(SonaRoute.clinicianToday),
          onContinueTriage: () => _go(SonaRoute.clinicianTriage),
        ),
      SonaRoute.clinicianTriage => ClinicianTriageScreen(
          busy: _busy,
          onBackPrep: () => _go(SonaRoute.clinicianPrep),
          onPublishSummary: _publishSummary,
        ),
      SonaRoute.clinicianSummaryPreview => ClinicianParentSummaryScreen(
          summaryHtml: _parentSummaryHtml,
          onBackClinician: () => _go(SonaRoute.clinicianTriage),
        ),
      _ => ClinicianTodayScreen(
          state: _state,
          onOpenPrep: () {
            _refreshCase();
            _go(SonaRoute.clinicianPrep);
          },
        ),
    };

    if (_route == SonaRoute.clinicianSummaryPreview) {
      return child;
    }

    return ClinicianShell(
      route: _clinicianNav,
      onNavigate: (r) {
        setState(() => _clinicianNav = r);
        if (r == ClinicianRoute.today) _go(SonaRoute.clinicianToday);
      },
      child: child,
    );
  }
}
