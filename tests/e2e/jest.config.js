module.exports = {
  testEnvironment: 'node',
  testMatch: ['**/*.test.js'],
  testTimeout: 120000,
  // E2E tests launch heavy headless Chromium + share the game server on :3000.
  // Running them in parallel overwhelms the machine → flaky timeouts.
  // Force sequential execution (1 worker).
  maxWorkers: 1,
  globals: {
    GODOT_URL: 'http://localhost:3000'
  }
};
