const godot = require('../helpers/godot_page');
const gameActions = require('../helpers/game_actions');

describe('Regression: UI System', () => {
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

  test('HUD is visible and shows data', async () => {
    const hud = await gameActions.getHUDText();
    expect(hud.hp).toBeDefined();
    expect(hud.dots).toBeDefined();
    await godot.takeScreenshot('regression_hud');
  });

  test('inventory toggle works multiple times', async () => {
    for (let i = 0; i < 3; i++) {
      await gameActions.openInventory();
      const open = await godot.getGameState();
      expect(open.inventoryVisible).toBe(true);
      await gameActions.closeInventory();
      const closed = await godot.getGameState();
      expect(closed.inventoryVisible).toBe(false);
    }
  });

  test('screenshots can be taken without error', async () => {
    const path = await godot.takeScreenshot('regression_screenshot_test');
    expect(path).toContain('.png');
  });

  test('canvas screenshot works', async () => {
    const path = await godot.takeCanvasScreenshot('regression_canvas_test');
    expect(path).toContain('.png');
  });
});
