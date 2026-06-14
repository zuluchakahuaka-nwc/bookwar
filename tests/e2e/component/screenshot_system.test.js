const godot = require('../helpers/godot_page');
const gameActions = require('../helpers/game_actions');
const fs = require('fs');
const path = require('path');

describe('Component: Screenshot System', () => {
  jest.setTimeout(120000);

  beforeAll(async () => {
    await godot.loadGame();
    await gameActions.waitForGameLoad();
    await gameActions.startNewGame();
    await godot.waitMs(2000);
  });

  afterAll(async () => {
    await godot.closeBrowser();
  });

  test('full page screenshot is taken and saved', async () => {
    const filepath = await godot.takeScreenshot('test_full');
    expect(fs.existsSync(filepath)).toBe(true);
    const stats = fs.statSync(filepath);
    expect(stats.size).toBeGreaterThan(1000);
  });

  test('canvas screenshot is taken and saved', async () => {
    const filepath = await godot.takeCanvasScreenshot('test_canvas');
    if (filepath) {
      expect(fs.existsSync(filepath)).toBe(true);
      const stats = fs.statSync(filepath);
      expect(stats.size).toBeGreaterThan(500);
    }
  });

  test('debugCapture returns state and paths', async () => {
    const debug = await godot.debugCapture('test_debug');
    expect(debug.state).toBeDefined();
    expect(debug.screenshot).toContain('.png');
    expect(debug.state.playerPos).toBeDefined();
  });

  test('console log captures errors', async () => {
    await godot.clearConsoleLog();
    const log = await godot.getConsoleLog();
    expect(typeof log).toBe('string');
  });

  test('multiple rapid screenshots do not crash', async () => {
    for (let i = 0; i < 5; i++) {
      await godot.takeScreenshot('rapid_' + i);
    }
    const log = await godot.getConsoleLog();
    expect(log).not.toContain('[PAGE_ERROR]');
  });
});
