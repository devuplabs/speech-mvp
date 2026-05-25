import { describe, expect, it } from "vitest";
import { renderClinicalReportPdf } from "../services/clinical-report-pdf.js";

describe("renderClinicalReportPdf", () => {
  it("returns a minimal valid PDF document", () => {
    const pdf = renderClinicalReportPdf({
      title: "Clinical report",
      childDisplayName: "Aria",
      sections: [{ heading: "Summary", body: "Stub section body." }],
      disclaimer: "AI-drafted · clinician-reviewed",
    });
    const header = Buffer.from(pdf.slice(0, 8)).toString("utf8");
    expect(header).toBe("%PDF-1.4");
    const tail = Buffer.from(pdf.slice(-6)).toString("utf8");
    expect(tail).toContain("%%EOF");
  });
});
