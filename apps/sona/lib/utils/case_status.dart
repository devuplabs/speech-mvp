/// Maps API `case.status` to clinician UI labels (British English).
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
    case 'consult_booked':
      return 'Consult booked';
    case 'triaged':
      return 'Triaged';
    case 'carryover':
      return 'Carryover';
    case 'intake_pending':
    default:
      return 'Not started';
  }
}

bool showCaseOnTodayDashboard(String? status) {
  if (status == null) return false;
  return status != 'intake_pending';
}

/// True when a parent summary has been published for this case. Once the case
/// advances into carryover the summary is still published, so both statuses
/// count (DEV-10).
bool isSummarySent(String? status) =>
    status == 'summary_sent' || status == 'carryover';

/// KPI bucket for a case status — every dashboard status maps to exactly one
/// bucket so the three tile counts always sum to the total on-dashboard count.
///
/// Bucket A — "New intakes": submitted but prep not yet generated.
/// Bucket B — "In progress": prep generated through to plan ready / triaged /
///   consult booked.
/// Bucket C — "Summary sent": full loop complete, including the carryover stage.
enum KpiBucket { newIntake, inProgress, summarySent }

KpiBucket kpiBucketFor(String? status) {
  switch (status) {
    case 'intake_submitted':
    case 'prep_drafting':
      return KpiBucket.newIntake;
    case 'prep_ready':
    case 'consult_booked':
    case 'triaged':
    case 'plan_drafting':
    case 'plan_ready':
      return KpiBucket.inProgress;
    case 'summary_sent':
    case 'carryover':
      return KpiBucket.summarySent;
    default:
      // intake_pending is filtered out before reaching dashboard; any unknown
      // status falls into newIntake so it is never silently dropped.
      return KpiBucket.newIntake;
  }
}
