import { ConfigService } from '@nestjs/config';

export function readMinioConfig(config: ConfigService) {
  const required = (name: string): string => {
    const value = config.get<string>(name);
    if (!value?.trim()) throw new Error(`Falta configurar ${name}.`);
    return value;
  };
  const endPoint = required('MINIO_ENDPOINT');
  if (!/^[a-zA-Z0-9.-]+$/.test(endPoint)) {
    throw new Error('MINIO_ENDPOINT debe ser un hostname sin protocolo ni ruta.');
  }
  const portText = config.get<string>('MINIO_PORT') ?? '9000';
  const port = Number(portText);
  if (!/^\d+$/.test(portText) || port < 1 || port > 65535) {
    throw new Error('MINIO_PORT debe ser un entero entre 1 y 65535.');
  }
  const ssl = config.get<string>('MINIO_USE_SSL') ?? 'false';
  if (ssl !== 'true' && ssl !== 'false') {
    throw new Error('MINIO_USE_SSL debe ser true o false.');
  }
  const bucket = required('MINIO_BUCKET');
  if (
    !/^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$/.test(bucket) ||
    /\.\.|\.-|-\./.test(bucket) ||
    /^\d+\.\d+\.\d+\.\d+$/.test(bucket)
  ) {
    throw new Error('MINIO_BUCKET debe ser un nombre de bucket S3 válido.');
  }
  return {
    bucket,
    client: {
      endPoint,
      port,
      useSSL: ssl === 'true',
      accessKey: required('MINIO_ACCESS_KEY'),
      secretKey: required('MINIO_SECRET_KEY'),
    },
  };
}
