module.exports = {
  ...require('../jest.config.base.cjs'),
  rootDir: __dirname,
  displayName: 'material-service',
  testMatch: ['<rootDir>/src/**/*.spec.ts', '<rootDir>/test/**/*.e2e-spec.ts'],
};
