/** PHI stays in DB/prompt only — never log this object. */
export function buildIntakeContextForLlm(answers: Record<string, unknown>): string {
  const pick = (key: string) => {
    const v = answers[key];
    if (v == null || v === "") return null;
    if (Array.isArray(v)) return v.join(", ");
    return String(v);
  };

  const lines: string[] = [];
  const fields = [
    ["Child", pick("childName")],
    ["DOB", pick("dateOfBirth")],
    ["Main concern", pick("mainConcern")],
    ["Difficulties", pick("difficulties")],
    ["Languages", pick("childLanguages")],
    ["Hearing", pick("hearingTestedDetails") ?? pick("hearingTested")],
    ["Milestones — first words", pick("ageFirstWords")],
    ["Milestones — two-word phrases", pick("ageTwoWordPhrases")],
    ["Sentence examples", pick("sentenceExamples")],
    ["School / nursery", pick("schoolNameAddress")],
    ["SEN / EHCP", pick("senPlan")],
    ["Temperament", pick("temperament")],
    ["Anything else", pick("anythingElse")],
  ] as const;

  for (const [label, value] of fields) {
    if (value) lines.push(`${label}: ${value}`);
  }
  return lines.join("\n");
}
