import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sona/services/intake_draft_storage.dart';
import 'package:sona/state/sona_app_state.dart';

/// Debounced device-only draft saves (2s after last edit). Never calls the API.
class IntakeLocalAutosave {
  IntakeLocalAutosave(this._storage);

  final IntakeDraftStorage _storage;
  static const debounce = Duration(seconds: 2);

  Timer? _timer;
  SonaAppState? _state;
  VoidCallback? _onPersisted;

  void attach(SonaAppState state, {VoidCallback? onPersisted}) {
    _state = state;
    _onPersisted = onPersisted;
    state.onFormEdited = schedule;
  }

  void detach(SonaAppState state) {
    state.onFormEdited = null;
    cancelPending();
    _state = null;
    _onPersisted = null;
  }

  void schedule() {
    cancelPending();
    _timer = Timer(debounce, () {
      unawaited(flush());
    });
  }

  void cancelPending() => _timer?.cancel();

  Future<void> flush() async {
    final state = _state;
    final caseId = state?.caseId;
    if (state == null || caseId == null) return;

    await _storage.saveLocal(
      caseId: caseId,
      answers: state.buildAnswersPayload(),
      formStep: state.formStep,
    );
    await _storage.saveLastCaseId(caseId);
    state.lastLocalSavedAt = DateTime.now();
    _onPersisted?.call();
  }
}
