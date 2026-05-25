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

/// True when a parent summary has been published for this case.
bool isSummarySent(String? status) => status == 'summary_sent';

/// KPI bucket for a case status — every dashboard status maps to exactly one
/// bucket so the three tile counts always sum to the total on-dashboard count.
///
/// Bucket A — "New intakes": submitted but prep not yet generated.
/// Bucket B — "In progress": prep generated through to plan ready / triaged.
/// Bucket C — "Summary sent": full loop complete.
enum KpiBucket { newIntake, inProgress, summarySent }

KpiBucket kpiBucketFor(String? status) {
  switch (status) {
    case 'intake_submitted':
    case 'prep_drafting':
      return KpiBucket.newIntake;
    case 'prep_ready':
    case 'triaged':
    case 'plan_drafting':
    case 'plan_ready':
      return KpiBucket.inProgress;
    case 'summary_sent':
      return KpiBucket.summarySent;
    default:
      // intake_pending is filtered out before reaching dashboard; any unknown
      // status falls into newIntake so it is never silently dropped.
      return KpiBucket.newIntake;
  }
}
