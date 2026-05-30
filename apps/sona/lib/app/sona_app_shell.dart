import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sona/config/env.dart';
import 'package:sona/design_system/sona_colors.dart';
import 'package:sona/design_system/widgets/sona_button.dart';
import 'package:sona/features/clinician/clinician_parent_summary_screen.dart';
import 'package:sona/features/clinician/clinician_clients_screen.dart';
import 'package:sona/features/clinician/clinician_intake_forms_screen.dart';
import 'package:sona/features/clinician/clinician_intake_review_screen.dart';
import 'package:sona/features/clinician/clinician_reports_screen.dart';
import 'package:sona/features/clinician/clinician_coming_soon_screen.dart';
import 'package:sona/features/clinician/clinician_settings_screen.dart';
import 'package:sona/features/clinician/clinician_prep_screen.dart';
import 'package:sona/features/clinician/clinician_shell.dart';
import 'package:sona/features/clinician/clinician_today_screen.dart';
import 'package:sona/features/clinician/clinician_triage_screen.dart';
import 'package:sona/features/parent/intake/parent_intake_step_screen.dart';
import 'package:sona/features/parent/parent_review_screen.dart';
import 'package:sona/features/parent/parent_summary_screen.dart';
import 'package:sona/features/parent/parent_welcome_screen.dart';
import 'package:sona/models/intake_form_data.dart';
import 'package:sona/models/intake_template.dart';
import 'package:sona/services/api_client.dart';
import 'package:sona/services/intake_draft_storage.dart';
import 'package:sona/services/intake_local_autosave.dart';
import 'package:sona/state/sona_app_state.dart';
import 'package:sona/test_utils/intake_personas.dart';
import 'package:sona/utils/api_errors.dart';
import 'package:sona/utils/intake_validation.dart';
import 'package:sona/utils/case_status.dart';
import 'package:sona/utils/open_url.dart';

enum SonaRoute {
  launcher,
  parentWelcome,
  parentIntake,
  parentReview,
  parentSummary,
  clinicianToday,
  clinicianClients,
  clinicianIntakeForms,
  clinicianIntakeReview,
  clinicianReports,
  clinicianResources,
  clinicianBilling,
  clinicianSettings,
  clinicianPrep,
  clinicianTriage,
  clinicianSummaryPreview,
}

class SonaAppShell extends StatefulWidget {
  const SonaAppShell({super.key, this.apiClient, this.intakeToken});

  /// Optional override; integration tests inject a [SonaApiClient] backed by
  /// a `MockClient` so the full 8-step flow can run with no live API.
  final SonaApiClient? apiClient;

  /// Magic-link token from parent web URL `?t=`.
  final String? intakeToken;

  @override
  State<SonaAppShell> createState() => _SonaAppShellState();
}

class _SonaAppShellState extends State<SonaAppShell> {
  late final SonaApiClient _api = widget.apiClient ?? SonaApiClient();
  final _draftStorage = IntakeDraftStorage();
  late final IntakeLocalAutosave _localAutosave = IntakeLocalAutosave(_draftStorage);
  final _state = SonaAppState();

  SonaRoute _route = SonaRoute.launcher;
  ClinicianRoute _clinicianNav = ClinicianRoute.today;
  bool _busy = false;
  String? _status;
  String? _parentSummaryHtml;
  bool _hasResumableDraft = false;
  List<Map<String, dynamic>> _availabilityRules = [];
  bool _needsAvailabilityConfirm = true;
  List<Map<String, dynamic>> _intakeFormItems = [];
  List<Map<String, dynamic>> _clinicalReportItems = [];

  @override
  void initState() {
    super.initState();
    _localAutosave.attach(_state, onPersisted: () {
      _hasResumableDraft = true;
    });
    _checkResumableDraft();
    final token = widget.intakeToken;
    if (token != null && token.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_openFromIntakeToken(token));
      });
    }
  }

  Future<void> _openFromIntakeToken(String token) async {
    await _run(() async {
      try {
        final resolved = await _api.resolveIntakeLink(token);
        final caseId = resolved['caseId'] as String;
        _state.caseId = caseId;
        _state.intakeTemplateId = intakeTemplateIdFromApi(resolved['templateId'] as String?);
        _state.intakeLocked = resolved['locked'] as bool? ?? false;
        _state.intakeLinkExpired = false;
        await _draftStorage.saveLastCaseId(caseId);
        final detail = await _api.getCase(caseId);
        _syncTenantFromCaseDetail(detail);
        final caseMap = detail['case'] as Map<String, dynamic>?;
        final status = caseMap?['status'] as String? ?? '';
        if (status != 'intake_pending') {
          setState(() {
            _status = 'This intake link has already been used.';
            _route = SonaRoute.parentWelcome;
          });
          return;
        }
        await _loadParentDraft();
        setState(() {
          _route = SonaRoute.parentWelcome;
          _status = _state.intakeLocked
              ? 'This intake is locked by your clinician.'
              : 'Intake link opened — tap Get started when ready.';
        });
      } on SonaApiException catch (e) {
        if (e.statusCode == 410) {
          setState(() {
            _state.intakeLinkExpired = true;
            _route = SonaRoute.parentWelcome;
            _status = 'This intake link has expired. Ask your clinician for a new link.';
          });
          return;
        }
        rethrow;
      }
    }, label: 'Open intake link');
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
    if (lastCase == null) return;
    final local = await _draftStorage.loadLocal(lastCase);
    if (local != null && mounted) {
      setState(() => _hasResumableDraft = true);
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
      if (e is SonaApiException) {
        final validation = parseApiValidationFailure(e);
        if (validation != null) {
          _applyApiValidationFailure(validation);
          setState(() => _status = 'Error: ${validation.summaryMessage}');
          return;
        }
      }
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
    if (_state.tenantId != null) return;
    final stored = await _draftStorage.loadLastTenantId();
    if (stored != null) {
      _state.tenantId = stored;
      return;
    }
    final tenantId = await _api.bootstrapDemoTenant();
    _state.tenantId = tenantId;
    await _draftStorage.saveLastTenantId(tenantId);
  }

  void _syncTenantFromCaseDetail(Map<String, dynamic> detail) {
    final caseMap = detail['case'] as Map<String, dynamic>?;
    final tenantId = caseMap?['tenantId'] as String?;
    if (tenantId == null || tenantId.isEmpty) return;
    _state.tenantId = tenantId;
    unawaited(_draftStorage.saveLastTenantId(tenantId));
  }

  Future<void> _clearStaleCase(String caseId) async {
    await _draftStorage.clearLocal(caseId);
    await _draftStorage.clearLastCaseId();
    _state.caseId = null;
  }

  /// Ensures [caseId] exists on the API; recreates the case if the stored id is stale.
  Future<void> _ensureValidParentCase() async {
    await _ensureTenant();
    final email = _state.intake.email.trim();
    final parentEmail = IntakeValidation.isEmail(email) ? email : null;
    final existingId = _state.caseId;

    if (existingId != null) {
      try {
        final detail = await _api.getCase(existingId);
        final caseMap = detail['case'] as Map<String, dynamic>?;
        if (caseMap != null) {
          _syncTenantFromCaseDetail(detail);
          final status = caseMap['status'] as String? ?? '';
          if (status == 'intake_pending') return;
          await _clearStaleCase(existingId);
        }
      } on SonaApiException catch (e) {
        if (!e.isNotFound) rethrow;
        await _clearStaleCase(existingId);
      }
    }

    final caseRow = await _api.createCase(
      tenantId: _state.tenantId!,
      parentEmail: parentEmail,
      childDisplayName: _state.childName,
    );
    final newId = caseRow['id'] as String;
    if (existingId != null && existingId != newId) {
      final local = await _draftStorage.loadLocal(existingId);
      if (local != null) {
        await _draftStorage.saveLocal(
          caseId: newId,
          answers: local.answers,
          formStep: local.formStep,
        );
      }
      await _draftStorage.clearLocal(existingId);
    }
    _state.caseId = newId;
    await _draftStorage.saveLastCaseId(newId);
    await _draftStorage.saveLastTenantId(_state.tenantId!);
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
          const SnackBar(content: Text('Progress saved to the server.')),
        );
      }
    } on SonaApiException catch (e) {
      if (e.isNotFound) {
        await _ensureValidParentCase();
        await _api.saveIntakeDraft(
          _state.caseId!,
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
            const SnackBar(content: Text('New session started — progress saved to the server.')),
          );
        }
        return;
      }
      rethrow;
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
      _syncTenantFromCaseDetail(detail);
      final intake = detail['intake'] as Map<String, dynamic>?;
      if (intake != null) {
        _state.intakeLocked = intake['locked'] as bool? ?? false;
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
      if (resume) {
        final lastCase = await _draftStorage.loadLastCaseId();
        _state.caseId = lastCase;
      } else {
        _state.caseId = null;
        _state.formStep = 1;
        _state.formSubstep = 0;
        _state.returnToReviewAfterEdit = false;
      }
      await _ensureValidParentCase();
      await _loadParentDraft();
      setState(() {
        _route = SonaRoute.parentIntake;
        _status = resume ? 'Resumed draft' : 'New intake started';
      });
    }, label: resume ? 'Resume' : 'Start');
  }

  Future<void> _parentSaveExit() async {
    await _run(() async {
      await _ensureValidParentCase();
      await _saveDraft(quiet: true);
      setState(() => _route = SonaRoute.parentWelcome);
    }, label: 'Save');
  }

  void _applyApiValidationFailure(ApiValidationFailure failure) {
    final firstKey = failure.firstFieldKey;
    if (firstKey == null) return;
    final step = IntakeFormData.stepForFieldKey(firstKey);
    setState(() {
      _state.formStep = step;
      if (step == 1) {
        _state.formSubstep =
            IntakeFormData.step1aFieldKeys.contains(firstKey) ? 0 : 1;
      } else {
        _state.formSubstep = 0;
      }
      _state.pendingValidationFieldKey = firstKey;
      _state.pendingValidationMessage = failure.summaryMessage;
      if (_route == SonaRoute.parentReview) {
        _route = SonaRoute.parentIntake;
      }
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failure.summaryMessage),
          duration: const Duration(seconds: 8),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showValidationError(({String message, String fieldKey}) err) {
    setState(() {
      _state.pendingValidationFieldKey = err.fieldKey;
      _state.pendingValidationMessage = err.message;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(err.message),
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Surface a modal so the user cannot miss that Continue was rejected and
  /// the form silently popped back to page 1. Visible diff between substeps
  /// is subtle, so the dialog calls it out explicitly.
  Future<void> _showStep1PopBackDialog(String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Page 1 needs another look'),
        content: Text(
          '$message\n\nWe took you back to page 1 of step 1 so you can fix it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Emits a structured log line for parent-intake transitions; PHI-free.
  void _logIntakeTransition(String event, Map<String, Object?> fields) {
    if (!kDebugMode) return;
    final pairs = fields.entries.map((e) => '${e.key}=${e.value}').join(' ');
    developer.log('intake.$event $pairs', name: 'sona.intake');
  }

  Future<void> _parentContinue() async {
    if (_state.intakeLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This intake is locked by your clinician.')),
      );
      return;
    }
    _logIntakeTransition('continue.start', {
      'step': _state.formStep,
      'substep': _state.formSubstep,
    });
    // Step 1 is paginated 1a/1b — advance the substep inside step 1 first.
    if (_state.formStep == 1 && _state.formSubstep == 0) {
      final pageErr = _state.intake.validateStep1a();
      if (pageErr != null) {
        _logIntakeTransition('continue.blocked.step1a', {
          'fieldKey': pageErr.fieldKey,
        });
        _showValidationError(pageErr);
        return;
      }
      setState(() {
        _state.pendingValidationFieldKey = null;
        _state.pendingValidationMessage = null;
        _state.formSubstep = 1;
      });
      _logIntakeTransition('continue.advanced.step1a_to_1b', const {});
      await _run(() async {
        await _ensureValidParentCase();
        await _saveDraft(quiet: true);
      }, label: 'Save');
      return;
    }
    final err = _state.intake.validateStep(_state.formStep);
    if (err != null) {
      // Step 1 page 2 might fail on a page-1 field if the user backed/edited;
      // pop to page 1 so the highlight is visible AND show a modal so the
      // pop-back is unmissable (the visual diff between 1a and 1b is subtle).
      final poppedToPage1 = _state.formStep == 1 &&
          _state.formSubstep == 1 &&
          IntakeFormData.step1aFieldKeys.contains(err.fieldKey);
      if (poppedToPage1) {
        setState(() => _state.formSubstep = 0);
      }
      _logIntakeTransition('continue.blocked', {
        'step': _state.formStep,
        'substep': _state.formSubstep,
        'fieldKey': err.fieldKey,
        'poppedToPage1': poppedToPage1,
      });
      _showValidationError(err);
      if (poppedToPage1) {
        await _showStep1PopBackDialog(err.message);
      }
      return;
    }
    setState(() {
      _state.pendingValidationFieldKey = null;
      _state.pendingValidationMessage = null;
    });
    await _run(() async {
      await _ensureValidParentCase();
      await _saveDraft(quiet: true);
      if (_state.returnToReviewAfterEdit) {
        _logIntakeTransition('continue.return_to_review', const {});
        setState(() {
          _state.returnToReviewAfterEdit = false;
          _route = SonaRoute.parentReview;
        });
        return;
      }
      final templateSteps = stepsForTemplate(_state.intakeTemplateId);
      final lastStep = templateSteps.last;
      if (_state.formStep >= lastStep) {
        _logIntakeTransition('continue.advanced.to_review', const {});
        setState(() => _route = SonaRoute.parentReview);
        return;
      }
      final next = _state.advanceTemplateStep(_state.formStep);
      if (next == null) {
        setState(() => _route = SonaRoute.parentReview);
        return;
      }
      _logIntakeTransition('continue.advanced.next_step', {
        'fromStep': _state.formStep,
        'toStep': next,
      });
      setState(() {
        _state.formStep = next;
        _state.formSubstep = 0;
      });
    }, label: 'Save');
  }

  Future<void> _parentBack() async {
    _logIntakeTransition('back.start', {
      'step': _state.formStep,
      'substep': _state.formSubstep,
      'returnToReview': _state.returnToReviewAfterEdit,
    });
    if (_state.returnToReviewAfterEdit) {
      await _run(() async {
        await _ensureValidParentCase();
        await _saveDraft(quiet: true);
        setState(() {
          _state.returnToReviewAfterEdit = false;
          _route = SonaRoute.parentReview;
        });
      }, label: 'Save');
      return;
    }
    // Step 1 page 2 → page 1 (no API call, just pop the substep)
    if (_state.formStep == 1 && _state.formSubstep == 1) {
      setState(() {
        _state.formSubstep = 0;
        _state.pendingValidationFieldKey = null;
        _state.pendingValidationMessage = null;
      });
      _logIntakeTransition('back.step1b_to_1a', const {});
      return;
    }
    final templateSteps = stepsForTemplate(_state.intakeTemplateId);
    final stepIndex = templateSteps.indexOf(_state.formStep);
    if (stepIndex <= 0) {
      _logIntakeTransition('back.exit_to_welcome', const {});
      _go(SonaRoute.parentWelcome);
      return;
    }
    await _run(() async {
      await _ensureValidParentCase();
      await _saveDraft(quiet: true);
      final prev = templateSteps[stepIndex - 1];
      setState(() {
        _state.formStep = prev;
        _state.formSubstep = _state.formStep == 1 ? 1 : 0;
      });
      _logIntakeTransition('back.advanced.previous_step', {
        'toStep': _state.formStep,
        'substep': _state.formSubstep,
      });
    }, label: 'Save');
  }

  void _parentEditStep(int step) {
    if (!_state.stepAllowed(step)) return;
    setState(() {
      _state.returnToReviewAfterEdit = true;
      _state.formStep = step;
      _state.formSubstep = 0;
      _route = SonaRoute.parentIntake;
    });
  }

  /// Switches the active clinician case and drops stale detail from a prior row
  /// so prep/triage never flash the wrong child while the new fetch is in flight.
  void _selectClinicianCase(String caseId) {
    setState(() {
      _state.caseId = caseId;
      final loadedId =
          (_state.caseDetail?['case'] as Map<String, dynamic>?)?['id'] as String?;
      if (loadedId != caseId) {
        _state.caseDetail = null;
      }
    });
  }

  Future<void> _refreshCase() async {
    final id = _state.caseId;
    if (id == null) return;
    final detail = await _api.getCase(id);
    _syncTenantFromCaseDetail(detail);
    final caseMap = detail['case'] as Map<String, dynamic>?;
    final status = caseMap?['status'] as String? ?? '';
    final intakeMap = detail['intake'] as Map<String, dynamic>?;
    final answers = intakeMap?['answers'] as Map<String, dynamic>?;
    setState(() {
      _state.caseDetail = detail;
      _status = 'Case: $status';
      _state.prepStatus = prepLabelFromCaseStatus(status);
      final name = caseMap?['childDisplayName'] as String?;
      if (name != null && name.isNotEmpty) {
        _state.intake.childName = name;
      }
      // Hydrate the intake form data from the submitted answers so screens
      // that read `state.intake` (review summary, parent summary preview)
      // surface this case's content rather than whatever the clinician
      // happened to be looking at last.
      if (answers != null && intakeMap?['submittedAt'] != null) {
        _state.applyDraftAnswers(answers);
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

  Future<void> _loadIntakeForms() async {
    await _ensureTenant();
    final items = await _api.listIntakeSubmissions(_state.tenantId!);
    setState(() {
      _intakeFormItems = items;
      _status = '${items.length} intake form(s)';
    });
  }


  Future<void> _loadClinicalReports() async {
    await _ensureTenant();
    final items = await _api.listClinicalReports(_state.tenantId!);
    setState(() {
      _clinicalReportItems = items;
      _status = '${items.length} report(s)';
    });
  }

  void _openClinicianResources() => _go(SonaRoute.clinicianResources);

  void _openClinicianBilling() => _go(SonaRoute.clinicianBilling);

  Future<void> _openClinicianReports() async {
    _go(SonaRoute.clinicianReports);
    await _run(_loadClinicalReports, label: 'Load reports');
  }

  void _downloadClinicalReportPdf(String caseId) {
    final url = _api.clinicalReportPdfUrl(caseId);
    openUrlInNewTab(url);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opening PDF download…')),
    );
  }

  Future<void> _viewClinicalReport(String caseId) async {
    await _run(() async {
      final detail = await _api.fetchClinicalReport(caseId);
      final content = detail['content'] as Map<String, dynamic>? ?? {};
      final sections = (content['sections'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(content['title'] as String? ?? 'Clinical report'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    content['disclaimer'] as String? ?? '',
                    style: const TextStyle(fontSize: 12, color: SonaColors.textMuted),
                  ),
                  const SizedBox(height: 12),
                  for (final s in sections) ...[
                    Text(
                      s['heading'] as String? ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(s['body'] as String? ?? ''),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ],
        ),
      );
    }, label: 'Load report');
  }

  Future<void> _openClinicianIntakeForms() async {
    _go(SonaRoute.clinicianIntakeForms);
    await _run(_loadIntakeForms, label: 'Load intake forms');
  }

  Future<void> _openIntakeReview(String caseId) async {
    _selectClinicianCase(caseId);
    await _run(() async {
      final detail = await _api.getCase(caseId);
      _syncTenantFromCaseDetail(detail);
      final intake = detail['intake'] as Map<String, dynamic>?;
      if (intake != null) {
        final answers = intake['answers'] as Map<String, dynamic>?;
        if (answers != null) {
          final step = answers['formStep'] as int? ?? 1;
          _state.applyDraftAnswers(answers, step: step);
        }
        _state.intakeLocked = intake['locked'] as bool? ?? false;
      }
      setState(() => _route = SonaRoute.clinicianIntakeReview);
    }, label: 'Load intake');
  }

  Future<String?> _resendIntakeLink(String caseId) async {
    String? url;
    await _run(() async {
      final result = await _api.resendIntakeLink(caseId);
      url = result['url'] as String?;
      await _loadIntakeForms();
    }, label: 'Resend link');
    return url;
  }

  Future<void> _revokeIntakeLink(String caseId) async {
    await _run(() async {
      await _api.revokeIntakeLink(caseId);
      await _loadIntakeForms();
    }, label: 'Revoke link');
  }

  Future<void> _lockIntake(String caseId) async {
    await _run(() async {
      await _api.lockIntake(caseId);
      await _loadIntakeForms();
    }, label: 'Lock intake');
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
          SnackBar(content: Text('Step $step: ${err.message}')),
        );
        setState(() {
          _state.formStep = step;
          _state.pendingValidationFieldKey = err.fieldKey;
          _state.pendingValidationMessage = err.message;
          if (step == 1) {
            _state.formSubstep =
                IntakeFormData.step1aFieldKeys.contains(err.fieldKey) ? 0 : 1;
          } else {
            _state.formSubstep = 0;
          }
          _route = SonaRoute.parentIntake;
        });
        return;
      }
    }
    await _run(() async {
      await _ensureValidParentCase();
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
        _state.caseId = null;
        _state.formStep = 1;
        _state.consentGuardian = false;
        _state.consentPrivacy = false;
        _state.consentAccurate = false;
        _status = 'Intake submitted';
        _route = SonaRoute.parentWelcome;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Intake submitted successfully. Your clinician will review it before your call.'),
          ),
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

    // Guard: only fetch if the case status is summary_sent.
    // Calling the endpoint before publishing returns a 404; surface a friendly
    // message instead of a raw API error.
    final activeCase = _state.clinicianCases.where((c) => c['id'] == id).firstOrNull;
    final status = activeCase?['status'] as String?;
    if (!isSummarySent(status)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Summary not published yet. Complete triage and publish from the clinician prep flow.'),
          ),
        );
      }
      return;
    }

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

  /// Dev-only: persona-fill is enabled if we're a debug build AND the API base
  /// URL doesn't look like prod. Hard guard — we never want this affordance to
  /// hydrate real client data even by accident.
  bool get _devFillSampleEnabled {
    if (!kDebugMode) return false;
    final url = Env.apiBaseUrl.toLowerCase();
    if (url.contains('prod') || url.contains('production')) return false;
    return true;
  }

  /// Hydrate `_state` from [persona], save a server-side draft, and jump
  /// straight to the review screen so the demo / human tester can submit with
  /// a single tap.
  Future<void> _fillSampleAndOpenReview(IntakePersona persona) async {
    await _run(() async {
      await _ensureTenant();
      _state.caseId = null;
      _state.formStep = 8;
      _state.formSubstep = 0;
      _state.returnToReviewAfterEdit = false;
      _state.applyDraftAnswers({
        ...persona.answers,
        'consentGuardian': false,
        'consentPrivacy': false,
        'consentAccurate': false,
      }, step: 8);
      _state.intake.childName = persona.childDisplayName;
      _state.intake.email = persona.parentEmail;
      await _ensureValidParentCase();
      await _saveDraft(quiet: true);
      setState(() {
        _route = SonaRoute.parentReview;
        _status = 'Filled with sample persona: ${persona.label}';
      });
    }, label: 'Fill sample');
  }

  Future<void> _registerPatient({
    required String childFirstName,
    required String dateOfBirth,
    required String parentName,
    required String parentEmail,
    String? parentPhone,
    required String referralSource,
    String? initialConcerns,
    required bool sendIntakeLink,
    String? templateId,
    String? bookConsultStart,
  }) async {
    await _ensureTenant();
    final result = await _api.registerPatient(
      tenantId: _state.tenantId!,
      childFirstName: childFirstName,
      dateOfBirth: dateOfBirth,
      parentName: parentName,
      parentEmail: parentEmail,
      parentPhone: parentPhone,
      referralSource: referralSource,
      initialConcerns: initialConcerns,
      sendIntakeLink: sendIntakeLink,
      templateId: templateId,
      bookConsultStart: bookConsultStart,
    );
    final caseMap = result['case'] as Map<String, dynamic>;
    _state.caseId = caseMap['id'] as String;
    await _loadClinicianDashboard();
    final link = result['intakeLink'] as Map<String, dynamic>?;
    if (link != null && mounted) {
      await showIntakeLinkCopiedSnackBar(context, url: link['url'] as String);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient registered.')),
      );
    }
  }

  Future<void> _loadAvailabilityRules() async {
    await _ensureTenant();
    _availabilityRules = await _api.fetchAvailabilityRules(_state.tenantId!);
    if (mounted) setState(() => _needsAvailabilityConfirm = _availabilityRules.isEmpty);
  }

  Future<void> _openClinicianSettings() async {
    _go(SonaRoute.clinicianSettings);
    await _run(() async {
      await _ensureTenant();
      await _loadAvailabilityRules();
    }, label: 'Load settings');
  }

  Future<void> _openClinicianClients() async {
    _go(SonaRoute.clinicianClients);
    await _run(() async {
      await _ensureTenant();
      await _loadClinicianDashboard();
      await _loadAvailabilityRules();
    }, label: 'Load clients');
  }

  Future<void> _openClinicianToday() async {
    _go(SonaRoute.clinicianToday);
    await _run(() async {
      if (_state.tenantId == null && _state.caseId == null) {
        await _ensureTenant();
      }
      await _loadClinicianDashboard();
      await _loadAvailabilityRules();
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
            linkExpired: _state.intakeLinkExpired,
            intakeLocked: _state.intakeLocked,
            onGetStarted: _state.intakeLocked || _state.intakeLinkExpired
                ? null
                : () => _startParentIntake(resume: false),
            onResume: (_hasResumableDraft && !_state.intakeLocked && !_state.intakeLinkExpired)
                ? () => _startParentIntake(resume: true)
                : null,
            onFillSample: _devFillSampleEnabled ? _fillSampleAndOpenReview : null,
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
                _state.formStep = stepsForTemplate(_state.intakeTemplateId).last;
                _state.formSubstep = 0;
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
        SonaRoute.clinicianClients ||
        SonaRoute.clinicianIntakeForms ||
        SonaRoute.clinicianIntakeReview ||
        SonaRoute.clinicianReports ||
        SonaRoute.clinicianResources ||
        SonaRoute.clinicianBilling ||
        SonaRoute.clinicianSettings ||
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
      SonaRoute.clinicianClients => ClinicianClientsScreen(
          state: _state,
          onRefresh: _loadClinicianDashboard,
          onOpenCase: (caseId) {
            _selectClinicianCase(caseId);
            _refreshCase();
            _go(SonaRoute.clinicianPrep);
          },
          onRegisterPatient: _registerPatient,
          fetchSlots: _state.tenantId == null
              ? null
              : () => _api.fetchAvailabilitySlots(_state.tenantId!),
        ),
      SonaRoute.clinicianIntakeForms => ClinicianIntakeFormsScreen(
          items: _intakeFormItems,
          onRefresh: _loadIntakeForms,
          onOpenReview: (caseId) => unawaited(_openIntakeReview(caseId)),
          onResendLink: _resendIntakeLink,
          onRevokeLink: _revokeIntakeLink,
          onLock: _lockIntake,
        ),
      SonaRoute.clinicianIntakeReview => ClinicianIntakeReviewScreen(
          state: _state,
          onBack: () => _go(SonaRoute.clinicianIntakeForms),
        ),
      SonaRoute.clinicianReports => ClinicianReportsScreen(
          items: _clinicalReportItems,
          onRefresh: _loadClinicalReports,
          onDownloadPdf: _downloadClinicalReportPdf,
          onViewReport: (id) => unawaited(_viewClinicalReport(id)),
        ),
      SonaRoute.clinicianResources => const ClinicianComingSoonScreen(
          title: 'Resources',
          description:
              'Clinician resource library for handouts, referral templates, and session materials.',
          plannedItems: [
            'Parent-friendly handouts',
            'Referral letter templates',
            'Activity sheets by goal area',
          ],
        ),
      SonaRoute.clinicianBilling => const ClinicianComingSoonScreen(
          title: 'Billing',
          description:
              'Practice billing for consult fees, therapy blocks, and invoices — integrated with your workflow.',
          plannedItems: [
            'Session invoicing',
            'Package pricing',
            'Payment status per family',
          ],
        ),
      SonaRoute.clinicianSettings => ClinicianSettingsScreen(
          initialRules: _availabilityRules,
          onSave: (rules) async {
            await _ensureTenant();
            _availabilityRules = await _api.saveAvailabilityRules(_state.tenantId!, rules);
            setState(() => _needsAvailabilityConfirm = false);
          },
        ),
      SonaRoute.clinicianPrep => ClinicianPrepScreen(
          caseDetail: _state.caseDetail,
          onBackToday: () => _go(SonaRoute.clinicianToday),
          onContinueTriage: () => _go(SonaRoute.clinicianTriage),
          onRefresh: _state.caseId == null ? null : _refreshCase,
        ),
      SonaRoute.clinicianTriage => ClinicianTriageScreen(
          caseDetail: _state.caseDetail,
          busy: _busy,
          onBackPrep: () => _go(SonaRoute.clinicianPrep),
          onPublishSummary: _publishSummary,
        ),
      SonaRoute.clinicianSummaryPreview => ClinicianParentSummaryScreen(
          caseDetail: _state.caseDetail,
          summaryHtml: _parentSummaryHtml,
          onBackClinician: () => _go(SonaRoute.clinicianTriage),
        ),
      _ => ClinicianTodayScreen(
          state: _state,
          showAvailabilityBanner: _needsAvailabilityConfirm,
          onOpenPrep: (caseId) {
            _selectClinicianCase(caseId);
            _refreshCase();
            _go(SonaRoute.clinicianPrep);
          },
          onRefresh: _loadClinicianDashboard,
        ),
    };

    if (_route == SonaRoute.clinicianSummaryPreview) {
      return child;
    }

    final navRoute = switch (_route) {
      SonaRoute.clinicianClients => ClinicianRoute.clients,
      SonaRoute.clinicianIntakeForms || SonaRoute.clinicianIntakeReview =>
        ClinicianRoute.intakeForms,
      SonaRoute.clinicianReports => ClinicianRoute.reports,
      SonaRoute.clinicianResources => ClinicianRoute.resources,
      SonaRoute.clinicianBilling => ClinicianRoute.billing,
      SonaRoute.clinicianSettings => ClinicianRoute.settings,
      _ => _clinicianNav,
    };

    return ClinicianShell(
      route: navRoute,
      onNavigate: (r) {
        setState(() => _clinicianNav = r);
        if (r == ClinicianRoute.today) {
          unawaited(_openClinicianToday());
        } else if (r == ClinicianRoute.clients) {
          unawaited(_openClinicianClients());
        } else if (r == ClinicianRoute.intakeForms) {
          unawaited(_openClinicianIntakeForms());
        } else if (r == ClinicianRoute.reports) {
          unawaited(_openClinicianReports());
        } else if (r == ClinicianRoute.resources) {
          _openClinicianResources();
        } else if (r == ClinicianRoute.billing) {
          _openClinicianBilling();
        } else if (r == ClinicianRoute.settings) {
          unawaited(_openClinicianSettings());
        }
      },
      child: child,
    );
  }
}
