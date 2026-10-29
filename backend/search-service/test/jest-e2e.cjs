const { resolve } = require('node:path');

module.exports = {
  ...require('../../jest.config.base.cjs'),
  rootDir: resolve(__dirname, '..'),
  displayName: 'search-service-e2e',
  testMatch: ['<rootDir>/test/**/*.e2e-spec.ts'],
  transform: {
    '^.+\\.ts$': ['ts-jest', { tsconfig: '<rootDir>/tsconfig.json' }],
  },
  // Se verifica el timeout REAL de producción (5 s), sin acortarlo en tests.
  testTimeout: 15000,
  coverageDirectory: '<rootDir>/coverage-e2e',
};
