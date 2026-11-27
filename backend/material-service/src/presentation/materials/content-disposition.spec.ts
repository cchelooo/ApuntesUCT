import { asciiFilename, buildContentDisposition, extendedFilename } from './content-disposition';

describe('buildContentDisposition', () => {
  it.each([
    [
      'cálculo.pdf',
      `attachment; filename="calculo.pdf"; filename*=UTF-8''c%C3%A1lculo.pdf`,
    ],
    ['niño.pdf', `attachment; filename="nino.pdf"; filename*=UTF-8''ni%C3%B1o.pdf`],
    [
      'guía de cálculo.pdf',
      `attachment; filename="guia de calculo.pdf"; filename*=UTF-8''gu%C3%ADa%20de%20c%C3%A1lculo.pdf`,
    ],
    [
      'apunte "final".pdf',
      `attachment; filename="apunte _final_.pdf"; filename*=UTF-8''apunte%20%22final%22.pdf`,
    ],
    [
      '中文.pdf',
      `attachment; filename="__.pdf"; filename*=UTF-8''%E4%B8%AD%E6%96%87.pdf`,
    ],
  ])('conserva %s como filename* UTF-8 y una alternativa ASCII', (name, expected) => {
    expect(buildContentDisposition(name)).toBe(expected);
  });

  it.each(['/srv/private/apunte.pdf', '../../apunte.pdf', 'C:\\private\\apunte.pdf'])(
    'elimina rutas internas de %s', (name) => {
      expect(buildContentDisposition(name)).toBe(
        `attachment; filename="apunte.pdf"; filename*=UTF-8''apunte.pdf`,
      );
    },
  );

  it.each(['.', '..', '/private/', 'C:\\private\\'])(
    'usa fallback para nombres sin archivo: %s', (name) => {
      expect(asciiFilename(name)).toBe('material');
      expect(extendedFilename(name)).toBe('material');
    },
  );

  it('tolera sustitutos Unicode aislados y quita controles bidireccionales', () => {
    expect(extendedFilename('a\ud800\u202epdf')).toBe('a_pdf');
  });

  it('escapa los caracteres que RFC 5987 no admite sin codificar en filename*', () => {
    expect(extendedFilename("a'b(c)d*e.pdf")).toBe('a%27b%28c%29d%2Ae.pdf');
  });

  it.each([undefined, '', '   '])(
    'usa el nombre de respaldo cuando el original es %p',
    (name) => {
      expect(buildContentDisposition(name)).toBe(
        `attachment; filename="material"; filename*=UTF-8''material`,
      );
    },
  );

  describe('protección contra inyección de cabeceras', () => {
    const malicious = 'informe".pdf\r\nX-Injected: yes';

    it('no incluye CR, LF ni su codificación en el valor', () => {
      const header = buildContentDisposition(malicious);
      expect(header).not.toMatch(/[\r\n]/);
      expect(header.toLowerCase()).not.toContain('%0d');
      expect(header.toLowerCase()).not.toContain('%0a');
    });

    it('neutraliza las comillas dejando solo los delimitadores del filename', () => {
      const header = buildContentDisposition(malicious);
      expect(header.match(/"/g)).toHaveLength(2);
      expect(asciiFilename(malicious)).toBe('informe_.pdfX-Injected: yes');
    });
  });
});
