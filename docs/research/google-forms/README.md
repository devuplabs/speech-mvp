# Google Forms — build instructions

Two survey versions are generated from one Apps Script, both derived from
[`../market-survey-questionnaire.md`](../market-survey-questionnaire.md):

| Version | Function | Length | Use for |
|---|---|---|---|
| **Short screener** | `createShortScreener()` | ~20 ★ questions, ~5–8 min | Wide, cold distribution (forums, newsletters, social). Maximise completion + recruit interviews. |
| **Full survey** | `createFullSurvey()` | Full instrument, ~12–15 min | Engaged respondents — people who said "yes" to the screener, warm intros, SIG members. |

## Live forms

| Version | Published URL |
|---|---|
| **Full survey** | <https://forms.gle/JTQKnvXBqUbYy8AFA> |
| **Short screener** | <https://forms.gle/Ne2Dc1UAGgGa9e9G6> |

## Build the forms

1. Open <https://script.google.com> → **New project**.
2. Delete the placeholder, paste all of [`build-forms.gs`](build-forms.gs), **Save**.
3. From the function dropdown pick `createShortScreener`, click **Run**, and
   authorise the script when prompted (it only creates a Form in your Drive).
4. Open **View → Logs** (or the Execution log) to get the form's **Edit** and
   **Published** URLs. Repeat for `createFullSurvey`.
5. The forms land in your Google Drive root — move them wherever you like and
   tweak copy/order in the Forms editor before sending.

## After generating — do these by hand in the Forms editor

Google Forms can't express everything via the API, so finish these manually:

- **Screen-out branching.** On Q0.1 and Q0.2, use the **⋮ → Go to section based
  on answer** option so "No / Student / Retired" jumps to a polite end screen.
- **"Limit to 3" on Q1.4 / Q6.2.** Forms has no max-select; either add a
  response-validation note or just leave it as guidance in the title.
- **Q2.2 point-allocation.** The script renders it as a time grid (good enough).
  If you want true 100-point allocation, that needs a third-party add-on.
- **"Other" boxes.** Every question with an "Other" choice is generated with
  Google Forms' native "Other …" fill-in, so a text box appears inline when a
  respondent picks it — no extra setup needed. (One exception: Q2.2 is a grid,
  which can't carry an "Other" fill-in; its "Other" is a plain row.)
- **Conditional sub-questions** (labelled "(if …)" / "(only if …)") are plain
  optional questions. If you want them hidden until relevant, split them into
  their own sections and branch — only worth it for Q3.3a/3.3b and Q5.3a/5.3b.
- **Email field (Q9.1a).** Keep `setCollectEmail(false)` (already set) so the
  survey stays anonymous; the optional follow-up email is a separate free-text
  field, stored alongside answers — mention in your intro that it's optional and
  used only to arrange a paid interview.

## Distribution checklist

- Field the **screener** first; invite "Yes/Maybe" follow-up respondents to the
  **full** survey or a 30-min call.
- Over-sample non-paediatric/adult/AAC/dysphagia and non-UK respondents — those
  are the segments the current product under-serves (see the analysis plan at the
  bottom of the questionnaire).
- Offer a small incentive for the full survey / interview (prize draw or paid
  30-min slot) — response quality on the long version depends on it.
