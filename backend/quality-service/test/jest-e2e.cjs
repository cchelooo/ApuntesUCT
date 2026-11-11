module.exports = {
  ...require('../jest.config.cjs'),
  displayName: 'quality-service-e2e',
  testMatch: ['<rootDir>/test/**/*.e2e-spec.ts'],
  testTimeout: 15000,
  coverageDirectory: '<rootDir>/coverage-e2e',
};
