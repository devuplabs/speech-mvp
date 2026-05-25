/** Minimal single-page PDF (no external deps) for MVP clinical report export. */

export type ClinicalReportPdfInput = {
  title: string;
  childDisplayName: string;
  sections: { heading: string; body: string }[];
  disclaimer: string;
};

function escapePdfText(value: string): string {
  return value.replace(/\\/g, "\\\\").replace(/\(/g, "\\(").replace(/\)/g, "\\)");
}

function wrapLine(line: string, maxLen: number): string[] {
  if (line.length <= maxLen) return [line];
  const words = line.split(/\s+/);
  const out: string[] = [];
  let current = "";
  for (const word of words) {
    const next = current ? `${current} ${word}` : word;
    if (next.length > maxLen) {
      if (current) out.push(current);
      current = word.length > maxLen ? word.slice(0, maxLen) : word;
    } else {
      current = next;
    }
  }
  if (current) out.push(current);
  return out.length > 0 ? out : [""];
}

export function renderClinicalReportPdf(input: ClinicalReportPdfInput): Uint8Array {
  const rawLines: string[] = [
    input.title,
    `Patient: ${input.childDisplayName}`,
    "",
    ...input.sections.flatMap((s) => [s.heading, s.body, ""]),
    input.disclaimer,
  ];

  const lines: string[] = [];
  for (const raw of rawLines) {
    lines.push(...wrapLine(raw, 88));
  }

  const commands: string[] = ["BT", "/F1 11 Tf"];
  let y = 760;
  for (const line of lines) {
    if (y < 48) break;
    commands.push(`50 ${y} Td (${escapePdfText(line)}) Tj`);
    y -= 14;
  }
  commands.push("ET");
  const stream = `${commands.join("\n")}\n`;
  const streamLen = Buffer.byteLength(stream, "utf8");

  const objects: string[] = [];
  objects.push("1 0 obj<< /Type /Catalog /Pages 2 0 R >>endobj");
  objects.push("2 0 obj<< /Type /Pages /Kids [3 0 R] /Count 1 >>endobj");
  objects.push(
    "3 0 obj<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R /Resources<< /Font<< /F1 5 0 R >> >> >>endobj",
  );
  objects.push(`4 0 obj<< /Length ${streamLen} >>stream\n${stream}endstream\nendobj`);
  objects.push("5 0 obj<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>endobj");

  let body = "%PDF-1.4\n";
  const offsets: number[] = [0];
  for (const obj of objects) {
    offsets.push(Buffer.byteLength(body, "utf8"));
    body += `${obj}\n`;
  }

  const xrefStart = Buffer.byteLength(body, "utf8");
  body += `xref\n0 ${objects.length + 1}\n`;
  body += "0000000000 65535 f \n";
  for (let i = 1; i <= objects.length; i++) {
    const off = String(offsets[i]).padStart(10, "0");
    body += `${off} 00000 n \n`;
  }
  body += `trailer<< /Size ${objects.length + 1} /Root 1 0 R >>\n`;
  body += `startxref\n${xrefStart}\n%%EOF\n`;

  return new Uint8Array(Buffer.from(body, "utf8"));
}
