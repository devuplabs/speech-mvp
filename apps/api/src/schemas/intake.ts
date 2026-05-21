import { z } from "zod";

const shortText = z.string().trim().max(500);
const longText = z.string().trim().max(8000);
const optionalShort = z.union([shortText, z.literal("")]).optional();
const optionalLong = z.union([longText, z.literal("")]).optional();
const optionalEmail = z
  .union([z.string().trim().email().max(320), z.literal("")])
  .optional();

const yesNo = z.union([z.enum(["yes", "no"]), z.literal("")]).optional();

export const difficultyOption = z.enum([
  "Speech sounds",
  "Saying longer words",
  "Expressing ideas clearly",
  "Understanding what is said to them",
  "Following directions/instructions",
  "Sitting or standing still",
  "Staying on task",
  "Maintaining focus",
  "Ignoring distractions appropriately",
  "Overly sensitive to sounds/noises",
  "Maintaining eye contact",
  "Turn taking",
  "Sharing",
  "Playing with others appropriately",
  "Staying on topic of conversation",
  "Reading between the lines",
  "Maintaining interest in story books",
  "Understanding stories and answering questions",
  "Reading and spelling words",
  "Letter/number formation",
  "Writing stories",
]);

/** Validated intake payload — no PHI in logs; validate at boundary only. */
export const intakeAnswersSchema = z
  .object({
    version: z.number().int().min(1).max(1).optional().default(1),
    email: optionalEmail,
    childName: shortText.optional(),
    dateOfBirth: shortText.optional(),
    ageAtReferral: shortText.optional(),
    childAddress: shortText.optional(),
    motherName: shortText.optional(),
    motherAddress: optionalShort,
    motherMobile: shortText.optional(),
    motherEmail: optionalEmail,
    fatherName: optionalShort,
    fatherAddress: optionalShort,
    fatherMobile: shortText.optional(),
    fatherEmail: optionalEmail,
    gpPractice: shortText.optional(),
    gpAddress: longText.optional(),
    gpPhone: shortText.optional(),
    referredBy: shortText.optional(),
    heardAbout: shortText.optional(),
    mainConcern: longText.optional(),
    difficulties: z.array(difficultyOption).max(21).optional(),
    assessedByOthers: yesNo,
    assessedByOthersDetails: optionalLong,
    receivingTherapy: yesNo,
    therapyDetails: optionalLong,
    languagesExposed: longText.optional(),
    parentLanguages: longText.optional(),
    childLanguages: longText.optional(),
    familyHistory: yesNo,
    familyHistoryDetails: optionalLong,
    pregnancyHealth: longText.optional(),
    prematureDetails: longText.optional(),
    birthWeight: shortText.optional(),
    birthComplications: longText.optional(),
    afterBirthComplications: longText.optional(),
    earlyIllnesses: longText.optional(),
    generalHealth: longText.optional(),
    diagnosis: longText.optional(),
    medications: longText.optional(),
    hospitalised: longText.optional(),
    hearingTested: longText.optional(),
    earInfections: longText.optional(),
    entInvolvement: longText.optional(),
    visionTested: longText.optional(),
    respondsToName: yesNo,
    ageFirstWords: shortText.optional(),
    ageTwoWordPhrases: shortText.optional(),
    attentionListening: longText.optional(),
    sentenceExamples: longText.optional(),
    showsUnderstanding: longText.optional(),
    temperament: longText.optional(),
    socialSkills: longText.optional(),
    peerInteraction: longText.optional(),
    favouritePlay: longText.optional(),
    communicationAwareness: longText.optional(),
    schoolNameAddress: longText.optional(),
    nurseryDays: optionalLong,
    senPlan: longText.optional(),
    anythingElse: optionalLong,
    photoConsent: yesNo,
    completedBy: shortText.optional(),
    completionDate: shortText.optional(),
    formStep: z.number().int().min(1).max(8).optional(),
    consentGuardian: z.boolean().optional(),
    consentPrivacy: z.boolean().optional(),
    consentAccurate: z.boolean().optional(),
  });

export type IntakeAnswers = z.infer<typeof intakeAnswersSchema>;

export const saveIntakeDraftBody = z.object({
  answers: intakeAnswersSchema,
  parentEmail: z.string().trim().email().max(320).nullish(),
  childDisplayName: z.string().trim().max(128).nullish(),
});

export const submitIntakeBody = z.object({
  answers: intakeAnswersSchema,
  consentVersion: z.string().max(64).optional(),
  parentEmail: z.string().trim().email().max(320).nullish(),
  childDisplayName: z.string().trim().max(128).nullish(),
});
