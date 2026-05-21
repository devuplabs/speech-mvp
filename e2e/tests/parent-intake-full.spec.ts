import { test, expect } from "@playwright/test";
import {
  continueStep,
  fillStep1,
  fillStep2,
  fillStep3,
  fillStep4,
  fillStep5,
  fillStep6,
  fillStep7,
  fillStep8,
  getStarted,
  openParentIntake,
  submitReview,
} from "../helpers/intake-flow.js";

test.describe("Parent intake full flow", () => {
  test("complete 8 steps, submit intake, land on welcome with success", async ({
    page,
  }) => {
    test.setTimeout(300_000);

    await openParentIntake(page);
    await getStarted(page);

    await fillStep1(page);
    await continueStep(page);
    await fillStep2(page);
    await continueStep(page);
    await fillStep3(page);
    await continueStep(page);
    await fillStep4(page);
    await continueStep(page);
    await fillStep5(page);
    await continueStep(page);
    await fillStep6(page);
    await continueStep(page);
    await fillStep7(page);
    await continueStep(page);
    await fillStep8(page);
    await continueStep(page);

    await expect(page.getByText("Review your answers")).toBeVisible();
    await submitReview(page);

    await expect(
      page.getByText(/Intake submitted successfully/i),
    ).toBeVisible({ timeout: 30_000 });
    await expect(page.getByRole("button", { name: "Get started" })).toBeVisible();
  });
});
