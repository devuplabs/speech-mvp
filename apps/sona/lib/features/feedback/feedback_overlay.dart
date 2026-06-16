import 'package:flutter/material.dart';
import 'package:sona/design_system/sona_colors.dart';
import 'package:sona/features/feedback/feedback_config.dart';
import 'package:sona/features/feedback/feedback_page_context.dart';
import 'package:sona/services/api_client.dart';

/// Wraps [child] with a small "Feedback" button for user testing (DEV-55).
///
/// Non-intrusive by design:
/// - When [enabled] is false (the default in non-UAT builds) it returns [child]
///   untouched — zero footprint, so it never affects the real user experience.
/// - When enabled it floats a compact, low-emphasis button at the bottom-right
///   that opens a TEXT-ONLY feedback panel (no screenshots or other capture).
///   Submitting is async and never blocks the page; a toast confirms.
class FeedbackOverlay extends StatelessWidget {
  FeedbackOverlay({
    super.key,
    required this.child,
    bool? enabled,
    this.contextController,
    this.apiClient,
  }) : enabled = enabled ?? feedbackWidgetEnabled;

  final Widget child;
  final bool enabled;

  /// Source of the PHI-safe page context. Defaults to the app-wide singleton.
  final FeedbackContextController? contextController;

  /// Override for tests. Defaults to a fresh [SonaApiClient].
  final SonaApiClient? apiClient;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return Stack(
      children: [
        Positioned.fill(child: child),
        Positioned(
          right: 16,
          bottom: 80,
          child: _FeedbackButton(onTap: () => _open(context)),
        ),
      ],
    );
  }

  Future<void> _open(BuildContext context) async {
    final size = MediaQuery.of(context).size;
    final messenger = ScaffoldMessenger.of(context);
    final draft = await showModalBottomSheet<_FeedbackDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SonaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: const _FeedbackPanel(),
      ),
    );
    if (draft == null) return;
    await _submit(draft, size, messenger);
  }

  Future<void> _submit(
    _FeedbackDraft draft,
    Size size,
    ScaffoldMessengerState messenger,
  ) async {
    final ctx = (contextController ?? feedbackPageContext).current;
    final api = apiClient ?? SonaApiClient();
    try {
      await api.submitFeedback(
        type: draft.type,
        comment: draft.comment,
        severity: draft.severity,
        route: ctx.routeName,
        role: ctx.role,
        journeyStage: ctx.journeyStage,
        tenantId: ctx.tenantId,
        buildSha: kFeedbackBuildSha,
        appEnv: kFeedbackEnv,
        viewport: '${size.width.round()}x${size.height.round()}',
        locale: WidgetsBinding.instance.platformDispatcher.locale
            .toLanguageTag(),
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text('Thanks — feedback sent from ${ctx.routeName}.'),
        ),
      );
    } catch (_) {
      // Never surface raw errors to a tester; offer a simple retry message.
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not send feedback. Please try again.'),
        ),
      );
    }
  }
}

/// The floating affordance — compact and low-emphasis so it does not compete
/// with the page content.
class _FeedbackButton extends StatelessWidget {
  const _FeedbackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Send feedback',
      child: Material(
        key: const Key('feedback-fab'),
        color: SonaColors.primary,
        shape: const StadiumBorder(),
        elevation: 3,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chat_bubble_outline, size: 18, color: Colors.white),
                SizedBox(width: 6),
                Text(
                  'Feedback',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What the tester typed. Returned from the panel via Navigator.pop so the
/// overlay can submit asynchronously (panel closes immediately — non-blocking).
class _FeedbackDraft {
  _FeedbackDraft({required this.type, required this.comment, this.severity});

  final String type;
  final String comment;
  final String? severity;
}

const _types = <({String value, String label})>[
  (value: 'bug', label: '🐞 Bug'),
  (value: 'confusing', label: '😕 Confusing'),
  (value: 'idea', label: '💡 Idea'),
  (value: 'praise', label: '👍 Works well'),
];

const _severities = <({String value, String label})>[
  (value: 'blocker', label: 'Blocker'),
  (value: 'annoying', label: 'Annoying'),
  (value: 'minor', label: 'Minor'),
];

class _FeedbackPanel extends StatefulWidget {
  const _FeedbackPanel();

  @override
  State<_FeedbackPanel> createState() => _FeedbackPanelState();
}

class _FeedbackPanelState extends State<_FeedbackPanel> {
  String _type = 'bug';
  String? _severity;
  final _controller = TextEditingController();
  bool _showCommentError = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final comment = _controller.text.trim();
    if (comment.isEmpty) {
      setState(() => _showCommentError = true);
      return;
    }
    Navigator.of(context).pop(
      _FeedbackDraft(
        type: _type,
        comment: comment,
        severity: _type == 'bug' ? _severity : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Send feedback',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                for (final t in _types)
                  ChoiceChip(
                    label: Text(t.label),
                    selected: _type == t.value,
                    onSelected: (_) => setState(() => _type = t.value),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('feedback-comment'),
              controller: _controller,
              minLines: 3,
              maxLines: 6,
              maxLength: 4000,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: 'What happened, or what would make this better?',
                border: const OutlineInputBorder(),
                errorText: _showCommentError ? 'Please add a comment.' : null,
              ),
              onChanged: (_) {
                if (_showCommentError) {
                  setState(() => _showCommentError = false);
                }
              },
            ),
            if (_type == 'bug') ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: [
                  for (final s in _severities)
                    ChoiceChip(
                      label: Text(s.label),
                      selected: _severity == s.value,
                      onSelected: (sel) =>
                          setState(() => _severity = sel ? s.value : null),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            const Text(
              'Please don’t include real patient details.',
              style: TextStyle(fontSize: 12, color: SonaColors.textMuted),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('feedback-send'),
                onPressed: _send,
                child: const Text('Send'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
