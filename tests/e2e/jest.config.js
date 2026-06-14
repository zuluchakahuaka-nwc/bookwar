module.exports = {
  testEnvironment: 'node',
  testMatch: ['**/*.test.js'],
  testTimeout: 120000,
  globals: {
    GODOT_URL: 'http://localhost:3000'
  }
};
