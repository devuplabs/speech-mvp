/**
 * Sona SLT market-research survey — Google Forms builder
 * ------------------------------------------------------
 * Generates TWO Google Forms from the spec in
 * ../market-survey-questionnaire.md:
 *
 *   createShortScreener()  -> ~20 ★-core questions, wide distribution (~6-8 min)
 *   createFullSurvey()     -> full instrument, engaged respondents (~12-15 min)
 *
 * HOW TO USE
 *   1. Go to https://script.google.com -> New project.
 *   2. Paste this whole file in, Save.
 *   3. Run createShortScreener (and/or createFullSurvey). Authorise when asked.
 *   4. The Execution log prints the edit + published URLs of the new form(s).
 *
 * NOTES / GOOGLE FORMS LIMITATIONS
 *   - Forms has no point-allocation question. Q2.2 is rendered as a grid
 *     (row = task, column = how much time). Good enough for cross-tabs.
 *   - Conditional sub-questions (e.g. 3.3a) are added as OPTIONAL questions
 *     whose title says "(only if ...)". Hard section-branching is implemented
 *     only for the consent/screen-out gate, which is where it matters.
 *   - Edit copy/labels freely after generation; the script is a starting point.
 */

// ---------- shared option lists ----------
var SETTINGS = ['Solo private practice (just me)', 'Group / multi-clinician private practice',
  'NHS / public-health service (UK)', 'Public health service (non-UK)',
  'School- or education-based service', 'Charity / third-sector provider',
  'Mix of NHS/public and private', 'Other'];
var POPULATIONS = ['Paediatric — early years (0–4)', 'Paediatric — school age (5–11)',
  'Paediatric — adolescent (12–17)', 'Adults (18–64)', 'Older adults (65+)'];
var SPECIALTIES = ['Speech sounds / articulation / phonology', 'Language (receptive/expressive, DLD)',
  'Social communication / autism-related', 'Fluency / stammering', 'Voice',
  'Gender-affirming voice', 'Feeding (paediatric) / sensory mealtime',
  'Dysphagia / swallowing (adult)', 'AAC', 'Cleft / craniofacial', 'Hearing impairment',
  'Aphasia (post-stroke etc.)', 'Dysarthria / apraxia / motor speech',
  'Neurodegenerative (Parkinson’s, MND…)', 'Head & neck cancer / laryngectomy',
  'TBI / acquired brain injury', 'Other'];
var JURISDICTIONS = ['England', 'Wales', 'Scotland', 'Northern Ireland', 'Republic of Ireland',
  'United States', 'Australia', 'Canada', 'Other'];
var ADMIN_TASKS = ['Initial enquiries / new referrals', 'Pre-appointment information gathering',
  'Clinical note-writing after sessions', 'Assessment reports / formal write-ups',
  'Session / target planning', 'Preparing or sourcing materials & resources',
  'Between-session follow-up (home/school comms)', 'Scheduling & appointment booking',
  'Invoicing / payments / finance', 'Consent, T&Cs, compliance paperwork', 'Other'];
var CHANNELS = ['Web / contact form', 'Email', 'Phone', 'WhatsApp / text', 'Social media',
  'GP / health referral', 'School / SENCO referral', 'Word of mouth', 'Other'];
var PLAN_TOOLS = ['From memory / experience', 'Word / Google template', 'Spreadsheet',
  'Practice-management tool', 'Published programmes / frameworks', 'ChatGPT or similar',
  'I don’t formally write one', 'Other'];
var STACK = ['Cliniko', 'Jane App', 'Power Diary', 'Smilenotes', 'Octopus EPR (OEPR)', 'WriteUpp',
  'Google Workspace', 'Microsoft Office', 'Paper / handwritten',
  'An AI scribe (Heidi, Clindoc, PatientNotes…)', 'ChatGPT / Claude / Gemini',
  'None / ad-hoc', 'Other'];
var WTP = ['Wouldn’t pay', 'Under £20', '£20–39', '£40–59', '£60–79', '£80–99', '£100–149', '£150+'];
var FIVE = ['1', '2', '3', '4', '5'];

// ---------- helpers ----------
function _section(form, title) { return form.addPageBreakItem().setTitle(title); }
function _single(form, title, choices, required) {
  var it = form.addMultipleChoiceItem().setTitle(title).setChoiceValues(choices);
  if (required) it.setRequired(true); return it;
}
function _multi(form, title, choices, required) {
  var it = form.addCheckboxItem().setTitle(title).setChoiceValues(choices);
  if (required) it.setRequired(true); return it;
}
function _scale(form, title, low, high) {
  return form.addScaleItem().setTitle(title).setBounds(1, 5).setLabels(low, high);
}
function _text(form, title) { return form.addTextItem().setTitle(title); }
function _para(form, title) { return form.addParagraphTextItem().setTitle(title); }
function _grid(form, title, rows, cols) {
  return form.addGridItem().setTitle(title).setRows(rows).setColumns(cols);
}

// ============================================================
// SHORT SCREENER  (★ core only)
// ============================================================
function createShortScreener() {
  var form = FormApp.create('Sona — SLT workflow survey (5 min)');
  form.setDescription('Anonymous research into how speech & language therapists / pathologists '
    + 'spend their time. No clinical or client data is requested. ~5–8 minutes.')
    .setCollectEmail(false).setProgressBar(true);

  // gate
  _single(form, '0.1 Are you a qualified, currently-practising SLT/SLP (or assistant in the field)?',
    ['Yes — qualified and practising', 'Yes — assistant practitioner / SLTA',
     'Newly qualified (first year)', 'Student on placement', 'Retired / not practising', 'No'], true);
  _single(form, '0.2 This survey is anonymous and used only in aggregate. May we use your answers?',
    ['Yes', 'No'], true);

  _section(form, 'About you');
  _single(form, '1.1 Your main work setting today', SETTINGS, true);
  _single(form, '1.2 Share of your work that is private/self-funded vs publicly funded',
    ['100% private', 'Mostly private', '~50/50', 'Mostly public', '100% public'], true);
  _multi(form, '1.3 Client populations you work with', POPULATIONS, true);
  _multi(form, '1.4 Clinical areas that make up most of your caseload (up to 3)', SPECIALTIES, true);
  _single(form, '1.6 Where you primarily practise', JURISDICTIONS, true);

  _section(form, 'Your time');
  _text(form, '2.1 In a typical week, roughly how many hours on non-billable admin? (number)');
  _grid(form, '2.2 How much of your admin time does each task take?', ADMIN_TASKS,
    ['Most of it', 'A lot', 'Some', 'Little / none']);
  _single(form, '2.3 The single biggest drain on your time or energy', ADMIN_TASKS, false);

  _section(form, 'New clients');
  _multi(form, '3.1 How do new enquiries typically reach you?', CHANNELS, false);
  _single(form, '3.4 Before/during a first appointment, where does your time go?',
    ['Mostly figuring out what they need', 'Balanced', 'Mostly gathering background', 'Varies a lot'], false);
  _multi(form, '3.6 How do you currently produce a first-session / therapy plan?', PLAN_TOOLS, false);
  _scale(form, '4.3 How much of a pain is organising & sharing carryover materials/instructions?',
    'Not a pain', 'Major pain');

  _section(form, 'Tools & AI');
  _multi(form, '5.1 Tools you currently use to run your practice', STACK, false);
  _single(form, '5.3 Do you currently use any AI tool in your work?',
    ['Yes, regularly', 'Yes, occasionally', 'Tried it, stopped', 'No, but interested', 'No, not interested'], false);

  _section(form, 'A concept — your reaction');
  form.addSectionHeaderItem().setTitle('Concept').setHelpText(
    'A tool that handles the admin around new clients: a smart pre-appointment questionnaire the '
    + 'client/family fills in, a prepared summary for your first appointment, help deciding the right '
    + 'pathway, a draft first-session plan you review and edit, and a plain-language summary to send '
    + 'out — kept in your region, reviewed by you before it leaves, and logged for your records.');
  _scale(form, '6.1 How appealing is this for your practice?', 'Not at all', 'Extremely');
  _multi(form, '6.2 Which parts would be most valuable? (up to 3)',
    ['Pre-appointment questionnaire', 'Prepared first-appointment summary', 'Pathway/decision support',
     'Draft first-session plan', 'Plain-language client/carer summary', 'Status tracking of who filled what in',
     'Everything in one place', 'Audit trail', 'None of these'], false);

  _section(form, 'Cost & follow-up');
  _single(form, '7.1 Do you currently pay for tools to run your practice?',
    ['Yes', 'No', 'My employer does'], false);
  _single(form, '7.2 If a tool reliably saved ~4+ hours/month with data kept safely in-region, '
    + 'fair value per month (per clinician)?', WTP, false);
  _single(form, '9.1 Open to a short (30-min) paid follow-up about your workflow?',
    ['Yes', 'Maybe', 'No'], false);
  _text(form, '9.1a If yes/maybe, an email to reach you (optional)');

  Logger.log('SHORT SCREENER');
  Logger.log('Edit:      ' + form.getEditUrl());
  Logger.log('Published: ' + form.getPublishedUrl());
}

// ============================================================
// FULL SURVEY
// ============================================================
function createFullSurvey() {
  var form = FormApp.create('Sona — SLT practice & workflow survey');
  form.setDescription('Anonymous research into how speech & language therapists / pathologists work '
    + 'and where time goes. No clinical or client data is requested. ~12–15 minutes.')
    .setCollectEmail(false).setProgressBar(true);

  _single(form, '0.1 Are you a qualified, currently-practising SLT/SLP (or assistant in the field)?',
    ['Yes — qualified and practising', 'Yes — assistant practitioner / SLTA',
     'Newly qualified (first year)', 'Student on placement', 'Retired / not practising', 'No'], true);
  _single(form, '0.2 This survey is anonymous and used only in aggregate. May we use your answers?',
    ['Yes', 'No'], true);

  _section(form, '1 — About you');
  _single(form, '1.1 Your main work setting today', SETTINGS, true);
  _single(form, '1.2 Share of work that is private/self-funded vs publicly funded',
    ['100% private', 'Mostly private', '~50/50', 'Mostly public', '100% public'], true);
  _multi(form, '1.3 Client populations you work with', POPULATIONS, true);
  _multi(form, '1.4 Clinical areas that make up most of your caseload (up to 3)', SPECIALTIES, true);
  _single(form, '1.5 Years practised', ['<2', '2–5', '6–10', '11–20', '20+'], false);
  _single(form, '1.6 Where you primarily practise', JURISDICTIONS, true);
  _single(form, '1.7 Active clients in a typical week', ['1–5', '6–10', '11–20', '21–40', '40+'], false);
  _single(form, '1.8 New clients/referrals in a typical month', ['0–2', '3–5', '6–10', '11–20', '20+'], false);
  _multi(form, '1.9 Professional bodies / regulators that apply to you',
    ['HCPC', 'RCSLT', 'ASLTIP', 'ASHA', 'Speech Pathology Australia', 'SAC (Canada)', 'CORU (Ireland)', 'Other'], false);
  _text(form, '1.10 Languages you routinely deliver therapy in, beyond English');

  _section(form, '2 — Where your time goes');
  _text(form, '2.1 Typical weekly hours on non-billable admin (number)');
  _grid(form, '2.2 How much of your admin time does each task take?', ADMIN_TASKS,
    ['Most of it', 'A lot', 'Some', 'Little / none']);
  _single(form, '2.3 The single biggest drain on your time or energy', ADMIN_TASKS, false);
  _single(form, '2.4 For a routine follow-up session, admin time vs the session itself',
    ['Much less', 'About a quarter', 'About half', 'About as long', 'Longer than the session'], false);
  _text(form, '2.5 For a full initial assessment: how long does the report take, and your usual lead time to deliver it?');
  _scale(form, '2.6 "Admin load is a real factor in my stress / satisfaction / thoughts of leaving."',
    'Strongly disagree', 'Strongly agree');
  _para(form, '2.7 The most frustrating part of your workflow you wish someone would just fix');

  _section(form, '3 — The new-client journey');
  _multi(form, '3.1 How do new enquiries typically reach you?', CHANNELS, false);
  _scale(form, '3.2 How well can you track the status of new enquiries?', 'Not at all', 'Completely');
  _single(form, '3.3 Do you collect background info before the first appointment?',
    ['Always', 'Usually', 'Sometimes', 'Rarely', 'Never'], false);
  _multi(form, '3.3a (if yes) How do you collect it?',
    ['Paper form', 'PDF / Word form', 'Online form (Typeform/Google/Jotform)',
     'Practice-management tool', 'Verbally on the call', 'Other'], false);
  _scale(form, '3.3b (if yes) How satisfied are you with that process?', 'Not at all', 'Very');
  _single(form, '3.4 Before/during a first appointment, where does your time go?',
    ['Mostly figuring out what they need', 'Balanced', 'Mostly gathering background', 'Varies a lot'], false);
  _multi(form, '3.5 Typical decision reached after an initial consultation/assessment',
    ['Advice / strategy only', 'Short block of therapy', 'Full assessment needed', 'Refer elsewhere',
     'Ongoing / long-term therapy', 'Discharge / no action', 'Other'], false);
  _multi(form, '3.6 How do you currently produce a first-session / therapy plan?', PLAN_TOOLS, false);
  _single(form, '3.7 Do you send a summary after the first session?',
    ['Always', 'Usually', 'Sometimes', 'Rarely', 'Never'], false);
  _multi(form, '3.7a Who is that summary usually for?',
    ['Parent / carer', 'Adult client themselves', 'School / teaching staff', 'GP / referrer',
     'Other professionals', 'Funding body'], false);

  _section(form, '4 — Between sessions');
  _scale(form, '4.1 How important is between-session practice to your clients’ outcomes?', 'Not', 'Critical');
  _multi(form, '4.2 How do you currently support between-session practice?',
    ['Verbal advice', 'Handouts / printouts', 'Bought resources', 'Self-made resources',
     'Email / WhatsApp follow-ups', 'Apps / digital tools', 'Video clips', 'No good system', 'Other'], false);
  _scale(form, '4.3 How much of a pain is organising & sharing carryover materials/instructions?',
    'Not a pain', 'Major pain');
  _text(form, '4.4 When clients/carers ask "where do I get this resource?", how do you handle it?');
  _single(form, '4.5 Would feedback from home/school flowing back before the next session help?',
    ['Yes, badly need it', 'Would be nice', 'Neutral', 'Not really'], false);

  _section(form, '5 — Tools you use today');
  _multi(form, '5.1 Tools you currently use to run your practice', STACK, false);
  _text(form, '5.2 If you use a practice-management system, name it and what you like/dislike');
  _single(form, '5.3 Do you currently use any AI tool in your work?',
    ['Yes, regularly', 'Yes, occasionally', 'Tried it, stopped', 'No, but interested', 'No, not interested'], false);
  _multi(form, '5.3a (if yes/tried) For what?',
    ['Report drafting', 'Note-writing', 'Letter / email drafting', 'Session / activity ideas',
     'Summarising', 'Translation / plain-English', 'Other'], false);
  _text(form, '5.3b (if yes/tried) Which tool(s)?');
  _multi(form, '5.4 What stops you using AI more (or at all)?',
    ['Data privacy / GDPR / confidentiality', 'Don’t trust the output clinically',
     'Not sure what it can do', 'Too generic / not SLT-aware', 'Cost', 'Time to learn',
     'Ethical concerns', 'Employer / regulator restrictions', 'Nothing, I use it freely', 'Other'], false);
  _scale(form, '5.5 Concern about client data going to general AI tools hosted outside your country',
    'Not concerned', 'Very concerned');
  _grid(form, '5.6 For a clinical AI tool, how important are each of these?',
    ['Data kept in my country / region', 'A clinician reviews before anything is sent',
     'Audit trail of what was shared & with whom', 'No training on my client data',
     'Built specifically for SLT/SLP', 'Works alongside tools I already use'],
    ['Not important', 'Slightly', 'Moderately', 'Very', 'Essential']);

  _section(form, '6 — A concept: your reaction');
  form.addSectionHeaderItem().setTitle('Concept').setHelpText(
    'A tool that handles the admin around new clients: a smart pre-appointment questionnaire the '
    + 'client/family fills in, a prepared summary for your first appointment, help deciding the right '
    + 'pathway, a draft first-session plan you review and edit, and a plain-language summary to send '
    + 'out — kept in your region, reviewed by you before it leaves, and logged for your records.');
  _scale(form, '6.1 How appealing is this for your practice?', 'Not at all', 'Extremely');
  _multi(form, '6.2 Which parts would be most valuable? (up to 3)',
    ['Pre-appointment questionnaire', 'Prepared first-appointment summary', 'Pathway/decision support',
     'Draft first-session plan', 'Plain-language client/carer summary', 'Status tracking of who filled what in',
     'Everything in one place', 'Audit trail', 'None of these'], false);
  _para(form, '6.3 Which parts feel irrelevant or wrong for how YOU work?');
  _single(form, '6.4 The concept assumes a parent filling a form about a child. If your clients are '
    + 'adults / school / care settings, how well would it fit as-is?',
    ['Fits fine', 'Needs some changes', 'Needs major changes', 'Wouldn’t fit', 'N/A — my clients are children'], false);
  _para(form, '6.4a What would need to change?');
  _para(form, '6.5 What’s missing that would make this a must-have for you?');

  _section(form, '7 — Willingness to pay');
  _single(form, '7.1 Do you currently pay for tools to run your practice?',
    ['Yes', 'No', 'My employer does'], false);
  _text(form, '7.1a If yes, roughly how much per month in total?');
  _single(form, '7.2 If a tool reliably saved ~4+ hours/month with data kept safely in-region, '
    + 'fair value per month (per clinician)?', WTP, false);
  _single(form, '7.3 Preferred pricing model',
    ['Flat monthly per clinician', 'Pay per new client/case', 'Free tier + paid upgrade',
     'One-off licence', 'Whatever’s cheapest, don’t care about model'], false);
  _para(form, '7.4 What would make you hesitant to pay for a tool like this, even if useful?');
  _single(form, '7.5 Who decides whether you adopt a new tool?',
    ['Just me', 'Me + a partner/colleague', 'Practice owner/manager', 'Employer / NHS procurement', 'Other'], false);

  _section(form, '8 — Adoption & blockers');
  _single(form, '8.1 How do you prefer to try a new tool?',
    ['Free trial on real cases', 'Free demo / walkthrough', 'Peer recommendation',
     'Endorsement from ASLTIP/RCSLT/ASHA', 'Won’t try unless certified/approved', 'Other'], false);
  _multi(form, '8.2 Certifications/approvals a tool would need before you’d put client data in it',
    ['GDPR / UK data residency', 'NHS DSPT', 'Cyber Essentials', 'HIPAA (US)',
     'Professional-body endorsement', 'Insurer requirement', 'Don’t know', 'None', 'Other'], false);
  _scale(form, '8.3 Willingness to change your current way of working for a tool that genuinely saved time',
    'Not willing', 'Very willing');
  _para(form, '8.4 What has put you off a practice tool you tried in the past?');

  _section(form, '9 — Follow-up');
  _single(form, '9.1 Open to a short (30-min) paid follow-up about your workflow?',
    ['Yes', 'Maybe', 'No'], false);
  _text(form, '9.1a If yes/maybe, an email to reach you (optional)');
  _single(form, '9.2 Interested in trying an early version of a tool like this?',
    ['Yes', 'Maybe', 'No'], false);
  _para(form, '9.3 Anything else you want the people building tools for SLTs to know?');

  Logger.log('FULL SURVEY');
  Logger.log('Edit:      ' + form.getEditUrl());
  Logger.log('Published: ' + form.getPublishedUrl());
}
