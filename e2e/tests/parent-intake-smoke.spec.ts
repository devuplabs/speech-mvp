import { test, expect } from "@playwright/test";
import { getStarted, openParentIntake } from "../helpers/intake-flow.js";

test.describe("Parent intake smoke", () => {
  test("Get started bootstraps tenant and opens step 1 without API errors", async ({
    page,
  }) => {
    test.setTimeout(300_000);
    const errors: string[] = [];
    page.on("pageerror", (e) => errors.push(e.message));
    page.on("console", (msg) => {
      if (msg.type() === "error") errors.push(msg.text());
    });

    await openParentIntake(page);
    await getStarted(page);

    await expect(page.getByText("Step 1 of 8")).toBeVisible();
    expect(errors.join("\n")).not.toMatch(/SonaApiException\(200\)/);
  });
});
