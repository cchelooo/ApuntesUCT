import { ConfigService } from '@nestjs/config';
import { UnauthorizedException } from '@nestjs/common';
import { MaterialAuthorProvider } from './material-author.provider';

describe('MaterialAuthorProvider local', () => {
  const settings = {
    NODE_ENV: 'development',
    MATERIAL_LOCAL_AUTHOR_ENABLED: 'true',
    MATERIAL_LOCAL_UPLOADER_ID: '11111111-1111-4111-8111-111111111111',
  };
  it('resuelve solo el autor configurado explícitamente en desarrollo', () => {
    expect(new MaterialAuthorProvider(new ConfigService(settings)).resolve()).toEqual({
      id: settings.MATERIAL_LOCAL_UPLOADER_ID,
      universityId: null,
    });
  });
  it.each([
    { NODE_ENV: 'production' },
    { NODE_ENV: 'test' },
    { NODE_ENV: '' },
    { MATERIAL_LOCAL_AUTHOR_ENABLED: 'false' },
    { MATERIAL_LOCAL_UPLOADER_ID: '' },
    { MATERIAL_LOCAL_UPLOADER_ID: 'not-a-uuid' },
  ])('rechaza configuración sin autorización local: %j', (override) => {
    expect(() =>
      new MaterialAuthorProvider(new ConfigService({ ...settings, ...override })).resolve(),
    ).toThrow(UnauthorizedException);
  });
});
