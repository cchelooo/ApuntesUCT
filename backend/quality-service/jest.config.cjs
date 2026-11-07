module.exports = {
  moduleFileExtensions: ['js', 'json', 'ts'],
  rootDir: __dirname,
  displayName: 'quality-service',
  testEnvironment: 'node',
  testMatch: ['<rootDir>/src/**/*.spec.ts'],
  transform: { '^.+\\.ts$': ['ts-jest', { tsconfig: '<rootDir>/tsconfig.json' }] },
  clearMocks: true,
  restoreMocks: true,
  collectCoverageFrom: ['src/**/*.ts', '!src/**/*.spec.ts', '!src/main.ts', '!src/**/*.module.ts'],
  coverageDirectory: '<rootDir>/coverage',
  coverageReporters: ['text', 'lcov', 'html'],
};
