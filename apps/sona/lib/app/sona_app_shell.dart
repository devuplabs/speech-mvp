import 'dart:async';

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
import 'package:sona/features/parent/intake/parent_intake_step_screen.dart';
import 'package:sona/features/parent/parent_review_screen.dart';
import 'package:sona/features/parent/parent_summary_screen.dart';
import 'package:sona/features/parent/parent_welcome_screen.dart';
import 'package:sona/services/api_client.dart';
import 'package:sona/services/intake_draft_storage.dart';
import 'package:sona/services/intake_local_autosave.dart';
import 'package:sona/state/sona_app_state.dart';
import 'package:sona/utils/api_errors.dart';
import 'package:sona/utils/intake_validation.dart';
import 'package:sona/utils/case_status.dart';

enum SonaRoute {
  launcher,
  parentWelcome,
  parentIntake,
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
  final _draftStorage = IntakeDraftStorage();
  late final IntakeLocalAutosave _localAutosave = IntakeLocalAutosave(_draftStorage);
  final _state = SonaAppState();

  SonaRoute _route = SonaRoute.launcher;
  ClinicianRoute _clinicianNav = ClinicianRoute.today;
  bool _busy = false;
  String? _status;
  String? _parentSummaryHtml;
  bool _hasResumableDraft = false;

  @override
  void initState() {
    super.initState();
    _localAutosave.attach(_state, onPersisted: () {
      _hasResumableDraft = true;
    });
    _checkResumableDraft();
  }

  @override
  void dispose() {
    _localAutosave.cancelPending();
    unawaited(_localAutosave.flush());
    _localAutosave.detach(_state);
    super.dispose();
  }

  Future<void> _checkResumableDraft() async {
    final lastCase = await _draftStorage.loadLastCaseId();
    if (lastCase != null) {
      _state.caseId = lastCase;
      final local = await _draftStorage.loadLocal(lastCase);
      if (local != null && mounted) {
        setState(() => _hasResumableDraft = true);
      }
    }
  }

  Future<void> _run(Future<void> Function() fn, {String? label}) async {
    setState(() {
      _busy = true;
      if (label != null) _status = '$label…';
    });
    try {
      await fn();
    } catch (e) {
      final friendly = friendlyApiError(e);
      setState(() => _status = 'Error: $friendly');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendly)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _ensureTenant() async {
    _state.tenantId ??= await _api.bootstrapDemoTenant();
  }

  Future<void> _ensureParentCase() async {
    await _ensureTenant();
    if (_state.caseId != null) return;
    final caseRow = await _api.createCase(
      tenantId: _state.tenantId!,
      parentEmail: _state.parentEmail,
      childDisplayName: _state.childName,
    );
    _state.caseId = caseRow['id'] as String;
  }

  Future<void> _saveDraft({bool quiet = false}) async {
    final caseId = _state.caseId;
    if (caseId == null) return;
    _localAutosave.cancelPending();
    final answers = _state.buildAnswersPayload();
    final email = _state.intake.email.trim();
    final parentEmail = IntakeValidation.isEmail(email) ? email : null;
    await _draftStorage.saveLocal(caseId: caseId, answers: answers, formStep: _state.formStep);
    await _draftStorage.saveLastCaseId(caseId);
    setState(() => _state.lastLocalSavedAt = DateTime.now());
    try {
      await _api.saveIntakeDraft(
        caseId,
        answers: answers,
        parentEmail: parentEmail,
        childDisplayName: _state.childName,
      );
      setState(() {
        _state.lastSavedAt = DateTime.now();
        _state.draftDirty = false;
      });
      if (!quiet && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Progress saved. You can continue later.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Saved on this device only. ${friendlyApiError(e)}',
            ),
          ),
        );
      }
      setState(() {
        _state.lastSavedAt = DateTime.now();
      });
    }
  }

  Future<void> _loadParentDraft() async {
    await _ensureTenant();
    if (_state.caseId == null) return;
    final caseId = _state.caseId!;
    final local = await _draftStorage.loadLocal(caseId);
    if (local != null) {
      _state.applyDraftAnswers(local.answers, step: local.formStep);
      setState(() => _state.lastLocalSavedAt = DateTime.now());
    }
    try {
      final detail = await _api.getCase(caseId);
      final intake = detail['intake'] as Map<String, dynamic>?;
      if (intake != null) {
        final answers = intake['answers'] as Map<String, dynamic>?;
        final submitted = intake['submittedAt'];
        if (answers != null && submitted == null) {
          final step = answers['formStep'] as int? ?? local?.formStep ?? 1;
          _state.applyDraftAnswers(answers, step: step);
        }
      }
    } catch (_) {
      // Local draft still usable
    }
  }

  Future<void> _startParentIntake({bool resume = false}) async {
    await _run(() async {
      await _ensureTenant();
      if (!resume || _state.caseId == null) {
        final caseRow = await _api.createCase(
          tenantId: _state.tenantId!,
          parentEmail: _state.parentEmail,
          childDisplayName: _state.childName,
        );
        _state.caseId = caseRow['id'] as String;
        await _draftStorage.saveLastCaseId(_state.caseId!);
        if (!resume) {
          _state.formStep = 1;
          _state.returnToReviewAfterEdit = false;
        }
      }
      await _loadParentDraft();
      setState(() {
        _route = SonaRoute.parentIntake;
        _status = resume ? 'Resumed draft' : 'New intake started';
      });
    }, label: resume ? 'Resume' : 'Start');
  }

  Future<void> _parentSaveExit() async {
    await _run(() async {
      await _ensureParentCase();
      await _saveDraft(quiet: true);
      setState(() => _route = SonaRoute.parentWelcome);
    }, label: 'Save');
  }

  Future<void> _parentContinue() async {
    final err = _state.intake.validateStep(_state.formStep);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    await _run(() async {
      await _ensureParentCase();
      await _saveDraft(quiet: true);
      if (_state.returnToReviewAfterEdit) {
        setState(() {
          _state.returnToReviewAfterEdit = false;
          _route = SonaRoute.parentReview;
        });
        return;
      }
      if (_state.formStep >= 8) {
        setState(() => _route = SonaRoute.parentReview);
        return;
      }
      setState(() => _state.formStep += 1);
    }, label: 'Save');
  }

  Future<void> _parentBack() async {
    if (_state.returnToReviewAfterEdit) {
      await _run(() async {
        await _ensureParentCase();
        await _saveDraft(quiet: true);
        setState(() {
          _state.returnToReviewAfterEdit = false;
          _route = SonaRoute.parentReview;
        });
      }, label: 'Save');
      return;
    }
    if (_state.formStep <= 1) {
      _go(SonaRoute.parentWelcome);
      return;
    }
    await _run(() async {
      await _ensureParentCase();
      await _saveDraft(quiet: true);
      setState(() => _state.formStep -= 1);
    }, label: 'Save');
  }

  void _parentEditStep(int step) {
    setState(() {
      _state.returnToReviewAfterEdit = true;
      _state.formStep = step;
      _route = SonaRoute.parentIntake;
    });
  }

  Future<void> _refreshCase() async {
    final id = _state.caseId;
    if (id == null) return;
    final detail = await _api.getCase(id);
    final caseMap = detail['case'] as Map<String, dynamic>?;
    final status = caseMap?['status'] as String? ?? '';
    setState(() {
      _status = 'Case: $status';
      _state.prepStatus = prepLabelFromCaseStatus(status);
      final name = caseMap?['childDisplayName'] as String?;
      if (name != null && name.isNotEmpty) {
        _state.intake.childName = name;
      }
    });
  }

  Future<void> _loadClinicianDashboard() async {
    await _ensureTenant();
    final rows = await _api.listCases(_state.tenantId!);
    setState(() {
      _state.clinicianCases = rows;
      if (_state.caseId != null) {
        for (final row in rows) {
          if (row['id'] == _state.caseId) {
            _state.prepStatus = prepLabelFromCaseStatus(row['status'] as String?);
            final name = row['childDisplayName'] as String?;
            if (name != null && name.isNotEmpty) _state.intake.childName = name;
            break;
          }
        }
      }
      _status = '${rows.length} case(s) loaded';
    });
  }

  Future<void> _submitParentIntake() async {
    if (!_state.consentGuardian || !_state.consentPrivacy || !_state.consentAccurate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please confirm all checkboxes before submitting.')),
      );
      return;
    }
    for (var step = 1; step <= 8; step++) {
      final err = _state.intake.validateStep(step);
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Step $step: $err')),
        );
        setState(() {
          _state.formStep = step;
          _route = SonaRoute.parentIntake;
        });
        return;
      }
    }
    await _run(() async {
      await _ensureParentCase();
      final caseId = _state.caseId!;
      final email = _state.intake.email.trim();
      await _api.submitIntake(
        caseId,
        answers: _state.buildAnswersPayload(),
        parentEmail: IntakeValidation.isEmail(email) ? email : null,
        childDisplayName: _state.childName,
      );
      await _draftStorage.clearLocal(caseId);
      await _draftStorage.clearLastCaseId();
      setState(() => _hasResumableDraft = false);
      setState(() {
        _state.prepStatus = 'Drafting';
        _status = 'Intake submitted';
        _route = SonaRoute.clinicianToday;
        _clinicianNav = ClinicianRoute.today;
      });
      await _refreshCase();
      await _loadClinicianDashboard();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Intake submitted — see Today dashboard for your case.')),
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

  void _go(SonaRoute route) {
    final onParent =
        _route == SonaRoute.parentIntake || _route == SonaRoute.parentReview;
    final toParent = route == SonaRoute.parentIntake || route == SonaRoute.parentReview;
    if (onParent && !toParent) {
      _localAutosave.cancelPending();
      unawaited(_localAutosave.flush());
    }
    setState(() => _route = route);
  }

  Future<void> _openClinicianToday() async {
    _go(SonaRoute.clinicianToday);
    await _run(() async {
      if (_state.tenantId == null && _state.caseId == null) {
        await _ensureTenant();
      }
      await _loadClinicianDashboard();
      if (_state.caseId != null) await _refreshCase();
    }, label: 'Load dashboard');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SonaColors.background,
      body: switch (_route) {
        SonaRoute.launcher => _launcher(),
        SonaRoute.parentWelcome => ParentWelcomeScreen(
            hasDraft: _hasResumableDraft,
            onGetStarted: () => _startParentIntake(resume: false),
            onResume: _hasResumableDraft ? () => _startParentIntake(resume: true) : null,
          ),
        SonaRoute.parentIntake => ParentIntakeStepScreen(
            state: _state,
            saving: _busy,
            onBack: _parentBack,
            onContinue: _parentContinue,
            onSaveExit: _parentSaveExit,
          ),
        SonaRoute.parentReview => ParentReviewScreen(
            state: _state,
            busy: _busy,
            onBack: () {
              setState(() {
                _state.formStep = 8;
                _route = SonaRoute.parentIntake;
              });
            },
            onEditStep: _parentEditStep,
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
                  onPressed: () => _openClinicianToday(),
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
          onOpenPrep: (caseId) {
            setState(() => _state.caseId = caseId);
            _refreshCase();
            _go(SonaRoute.clinicianPrep);
          },
          onRefresh: _loadClinicianDashboard,
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
