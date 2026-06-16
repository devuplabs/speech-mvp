/// PHI-safe description of the page a tester is on (DEV-55).
///
/// Carries only a route *name* (never a URL or magic-link token), a role, a
/// journey stage, and an optional tenant id — never child/parent names, DOB,
/// intake answers, draft content, emails, or tokens.
class FeedbackPageContext {
  const FeedbackPageContext({
    this.routeName = 'unknown',
    this.role = 'unknown',
    this.journeyStage = 'general',
    this.tenantId,
  });

  final String routeName;
  final String role;
  final String journeyStage;
  final String? tenantId;
}

/// Plain mutable holder the app shell updates on every build and the feedback
/// overlay reads when a tester opens the panel. A singleton keeps the two
/// decoupled without threading params through the whole widget tree.
class FeedbackContextController {
  FeedbackPageContext current = const FeedbackPageContext();

  void set(FeedbackPageContext context) => current = context;
}

/// App-wide singleton. Tests can inject their own controller into
/// [FeedbackOverlay] instead of relying on this.
final FeedbackContextController feedbackPageContext =
    FeedbackContextController();
