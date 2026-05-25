/// Parent intake questionnaire templates (mirrors API `intake-template.ts`).
enum IntakeTemplateId { full, short, followUp }

const Map<IntakeTemplateId, List<int>> kIntakeTemplateSteps = {
  IntakeTemplateId.full: [1, 2, 3, 4, 5, 6, 7, 8],
  IntakeTemplateId.short: [1, 2, 3],
  IntakeTemplateId.followUp: [1, 6, 7],
};

IntakeTemplateId intakeTemplateIdFromApi(String? raw) {
  switch (raw) {
    case 'short':
      return IntakeTemplateId.short;
    case 'follow_up':
      return IntakeTemplateId.followUp;
    default:
      return IntakeTemplateId.full;
  }
}

String intakeTemplateIdToApi(IntakeTemplateId id) {
  switch (id) {
    case IntakeTemplateId.short:
      return 'short';
    case IntakeTemplateId.followUp:
      return 'follow_up';
    case IntakeTemplateId.full:
      return 'full';
  }
}

List<int> stepsForTemplate(IntakeTemplateId id) => kIntakeTemplateSteps[id]!;

bool isStepInTemplate(IntakeTemplateId id, int step) =>
    kIntakeTemplateSteps[id]!.contains(step);

int? nextTemplateStep(IntakeTemplateId id, int current) {
  final steps = kIntakeTemplateSteps[id]!;
  final idx = steps.indexOf(current);
  if (idx < 0) return steps.first;
  if (idx >= steps.length - 1) return null;
  return steps[idx + 1];
}

int templateProgressIndex(IntakeTemplateId id, int step) {
  final steps = kIntakeTemplateSteps[id]!;
  final idx = steps.indexOf(step);
  return idx < 0 ? 1 : idx + 1;
}

int templateStepCount(IntakeTemplateId id) => kIntakeTemplateSteps[id]!.length;
