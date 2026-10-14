// Solo Node.js; sin paquetes adicionales. El relleno forma parte de un stream PDF.
const { mkdirSync, writeFileSync } = require('node:fs');
const { join } = require('node:path');

function buildPdf(padding) {
  const content =
    'BT /F1 12 Tf 72 720 Td (Fixture E2E: exactamente 15 MiB) Tj ET\n' + ' '.repeat(padding);
  const objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] ' +
      '/Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    `<< /Length ${Buffer.byteLength(content)} >>\nstream\n${content}\nendstream`,
  ];
  let text = '%PDF-1.4\n';
  const offsets = [];
  objects.forEach((object, i) => {
    offsets.push(Buffer.byteLength(text));
    text += `${i + 1} 0 obj\n${object}\nendobj\n`;
  });
  const xrefOffset = Buffer.byteLength(text);
  text += `xref\n0 ${objects.length + 1}\n0000000000 65535 f \n`;
  for (const offset of offsets) text += `${String(offset).padStart(10, '0')} 00000 n \n`;
  text +=
    `trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\n` +
    `startxref\n${xrefOffset}\n%%EOF\n`;
  return Buffer.from(text, 'ascii');
}

const target = 15 * 1024 * 1024;
let padding = target - buildPdf(0).length;
let pdf;
for (let attempt = 0; attempt < 10; attempt++) {
  pdf = buildPdf(padding);
  if (pdf.length === target) break;
  padding += target - pdf.length;
}
if (!pdf || pdf.length !== target) throw new Error('No se pudo generar el tamaño exacto.');
// El script vive en test/scripts: subir un nivel conduce a test.
const directory = join(__dirname, '..', 'fixtures');
mkdirSync(directory, { recursive: true });
const filename = join(directory, 'valid-exact-15mb.pdf');
writeFileSync(filename, pdf);
console.log(`Generado: ${filename} (${pdf.length} bytes)`);
