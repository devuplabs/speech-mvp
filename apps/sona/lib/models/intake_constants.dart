/// Intake checklist options — must match docs/intake-form-spec.md and API schema.
abstract final class IntakeConstants {
  static const consentVersion = 'mvp-v1';

  static const difficultySections = [
    (
      title: 'SPEECH & LANGUAGE',
      options: [
        'Speech sounds',
        'Saying longer words',
        'Expressing ideas clearly',
        'Understanding what is said to them',
        'Following directions/instructions',
      ],
    ),
    (
      title: 'ATTENTION & LISTENING',
      options: [
        'Sitting or standing still',
        'Staying on task',
        'Maintaining focus',
        'Ignoring distractions appropriately',
        'Overly sensitive to sounds/noises',
      ],
    ),
    (
      title: 'SOCIAL SKILLS',
      options: [
        'Maintaining eye contact',
        'Turn taking',
        'Sharing',
        'Playing with others appropriately',
        'Staying on topic of conversation',
        'Reading between the lines',
      ],
    ),
    (
      title: 'READING & WRITING',
      options: [
        'Maintaining interest in story books',
        'Understanding stories and answering questions',
        'Reading and spelling words',
        'Letter/number formation',
        'Writing stories',
      ],
    ),
  ];

  static List<String> get allDifficulties =>
      difficultySections.expand((s) => s.options).toList(growable: false);
}
