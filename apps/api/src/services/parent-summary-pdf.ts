import PDFDocument from "pdfkit";
import { buildParentSummaryText, type ParentSummaryOptions } from "./parent-summary.js";

/**
 * Server-side PDF render of the parent summary.
 *
 * Returns the PDF as a `Buffer` rather than streaming so the HTTP handler
 * stays simple. The text projection is reused so the PDF matches the HTML
 * preview section-for-section.
 *
 * Uses `pdfkit` — pure JS, no headless-Chrome dependency, no chromium runtime.
 */
export async function renderParentSummaryPdf(args: {
  childDisplayName: string | null;
  answers: Record<string, unknown>;
  sessionPlan: Parameters<typeof buildParentSummaryText>[0]["sessionPlan"];
  options: ParentSummaryOptions;
}): Promise<Buffer> {
  const projection = buildParentSummaryText(args);
  return new Promise((resolve, reject) => {
    const doc = new PDFDocument({ size: "A4", margin: 56 });
    const chunks: Buffer[] = [];
    doc.on("data", (b: Buffer) => chunks.push(b));
    doc.on("end", () => resolve(Buffer.concat(chunks)));
    doc.on("error", (e: unknown) =>
      reject(e instanceof Error ? e : new Error(String(e))),
    );

    // Title.
    doc
      .fontSize(20)
      .fillColor("#2D6A6E")
      .text(projection.title, { paragraphGap: 8 });

    doc
      .fontSize(11)
      .fillColor("#4A5B6B")
      .text(
        "Drafted by Sona, reviewed by your clinician.",
        { paragraphGap: 18 },
      );

    for (const section of projection.sections) {
      doc
        .moveDown(0.4)
        .fontSize(13)
        .fillColor("#2D6A6E")
        .text(section.heading, { paragraphGap: 6 });
      doc.fontSize(11).fillColor("#142433");
      for (const bullet of section.bullets) {
        doc.text(`•  ${bullet}`, {
          paragraphGap: 4,
          indent: 8,
        });
      }
    }

    if (projection.disclosure) {
      doc
        .moveDown(1.2)
        .fontSize(10)
        .fillColor("#A55727")
        .text("AI-drafted · clinician-reviewed", { paragraphGap: 4 });
      doc
        .fontSize(9)
        .fillColor("#4A5B6B")
        .text(projection.disclosure);
    }

    doc.end();
  });
}
