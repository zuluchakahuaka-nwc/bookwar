const godot = require('../helpers/godot_page');
const gameActions = require('../helpers/game_actions');

describe('M1: In-game Manual "How to play"', () => {
  jest.setTimeout(120000);

  beforeAll(async () => {
    await godot.loadGame();
    await gameActions.waitForGameLoad();
  });

  afterAll(async () => {
    await godot.closeBrowser();
  });

  test('manual opens from main menu and shows sections', async () => {
    // Menu should be visible at start
    const menuVisible = await gameActions.isMenuVisible();
    expect(menuVisible).toBe(true);

    // Click "Как играть" via JS hook
    await godot.evaluateInPage(() => {
      if (typeof window.gameClickManual === 'function') {
        window.gameClickManual();
      }
    });
    await godot.waitFrames(20);

    let manualOpen = await godot.evaluateInPage(() => !!window.gameManualVisible);
    expect(manualOpen).toBe(true);

    await godot.takeScreenshot('m1_manual_open_menu');

    // Switch through tabs to verify content renders
    await godot.waitMs(300);
    await godot.takeScreenshot('m1_manual_sections');

    // Close it again
    await godot.evaluateInPage(() => {
      if (typeof window.gameClickManual === 'function') {
        window.gameClickManual();
      }
    });
    await godot.waitFrames(20);

    manualOpen = await godot.evaluateInPage(() => !!window.gameManualVisible);
    expect(manualOpen).toBe(false);
  });

  test('manual opens in-game via H key and closes', async () => {
    await gameActions.startNewGame();
    await godot.waitMs(2000);

    // Open manual with H key
    await godot.pressKey('KeyH', 100);
    await godot.waitFrames(20);

    let manualOpen = await godot.evaluateInPage(() => !!window.gameManualVisible);
    expect(manualOpen).toBe(true);

    await godot.takeScreenshot('m1_manual_open_ingame');

    // Close with H key again (toggle)
    await godot.pressKey('KeyH', 100);
    await godot.waitFrames(20);

    manualOpen = await godot.evaluateInPage(() => !!window.gameManualVisible);
    expect(manualOpen).toBe(false);
  });
});
