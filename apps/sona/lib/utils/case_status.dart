/// Maps API `case.status` to clinician UI labels.
String prepLabelFromCaseStatus(String? status) {
  switch (status) {
    case 'prep_ready':
    case 'plan_ready':
    case 'summary_sent':
      return 'Ready';
    case 'prep_drafting':
    case 'intake_submitted':
    case 'plan_drafting':
      return 'Drafting';
    case 'triaged':
      return 'Triaged';
    case 'intake_pending':
    default:
      return 'Not started';
  }
}

bool showCaseOnTodayDashboard(String? status) {
  if (status == null) return false;
  return status != 'intake_pending';
}
