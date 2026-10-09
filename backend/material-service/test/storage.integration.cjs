const assert = require('node:assert/strict');
const { test } = require('node:test');
const { randomUUID } = require('node:crypto');
const { Client } = require('minio');
const { ConfigService } = require('@nestjs/config');

test(
  'guarda bytes reales en un bucket privado de MinIO',
  {
    skip: process.env.MATERIAL_TEST_MINIO !== '1',
  },
  async () => {
    const { MinioStorageAdapter } = require('../dist/infrastructure/storage/minio-storage.adapter');
    const { readMinioConfig } = require('../dist/infrastructure/storage/minio.config');
    const bucket = `material-test-${randomUUID()}`;
    const config = new ConfigService({ ...process.env, MINIO_BUCKET: bucket });
    const options = readMinioConfig(config);
    const client = new Client(options.client);
    const adapter = new MinioStorageAdapter(config);
    const keys = [];
    await client.makeBucket(bucket);
    try {
      const content = Buffer.from('%PDF-1.7\nMinIO integration test\n');
      for (let i = 0; i < 2; i++) {
        const result = await adapter.save(content, 'application/pdf');
        keys.push(result.storageKey);
        const stat = await client.statObject(bucket, result.storageKey);
        assert.equal(stat.size, content.length);
        assert.equal(stat.metaData['content-type'], 'application/pdf');
        const stream = await client.getObject(bucket, result.storageKey);
        const chunks = [];
        for await (const chunk of stream) chunks.push(chunk);
        assert.deepEqual(Buffer.concat(chunks), content);
      }
      assert.notEqual(keys[0], keys[1]);
      const anonymous = new Client({ ...options.client, accessKey: '', secretKey: '' });
      await assert.rejects(anonymous.statObject(bucket, keys[0]), { code: 'AccessDenied' });
    } finally {
      for (const key of keys) await client.removeObject(bucket, key);
      await client.removeBucket(bucket);
    }
  },
);
