import { isSafeExternalLink, publicExternalLink } from './external-link';

describe('Política de enlaces externos', () => {
  it.each([
    'https://example.com/apunte.pdf',
    'http://example.com/material?q=álgebra#tema',
    'https://drive.google.com/file/d/xyz/view',
    'HTTPS://EXAMPLE.COM/material',
  ])('acepta %s', (url) => {
    expect(isSafeExternalLink(url)).toBe(true);
    expect(publicExternalLink(url)).toBe(url);
  });

  it.each([
    undefined,
    null,
    123,
    '',
    'javascript:alert(1)',
    'data:text/html,test',
    'file:///etc/passwd',
    'ftp://example.com/file',
    '//example.com/file',
    'https://user:secret@example.com/file',
    'https://user@example.com',
    'https://localhost',
    'http://minio:9000/bucket',
    'http://minio.internal/file',
    'https://host.local/file',
    'https://host.localhost./file',
    'https://host.home.arpa/file',
    'http://127.0.0.1',
    'http://10.0.0.1',
    'http://172.16.0.1',
    'http://192.168.1.1',
    'http://169.254.169.254/latest',
    'http://2130706433',
    'http://0x7f000001',
    'http://0177.0.0.1',
    'http://[::1]',
    'http://[::ffff:127.0.0.1]',
    'https://example.com/\nfile',
    ' https://example.com',
    'https://example.com/file?X-Amz-Credential=secret',
    'https://example.com/file?X-Amz-Signature=secret',
    'https://example.com/file?AWSAccessKeyId=secret',
  ])('rechaza %p y oculta enlaces históricos inseguros', (url) => {
    expect(isSafeExternalLink(url)).toBe(false);
    expect(publicExternalLink(url)).toBeNull();
  });
});
