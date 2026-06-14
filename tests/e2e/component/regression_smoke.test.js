const godot = require('../helpers/godot_page');
const gameActions = require('../helpers/game_actions');

describe('Regression Smoke: Core functionality', () => {
  jest.setTimeout(120000);

  beforeAll(async () => {
    await godot.loadGame();
    await gameActions.waitForGameLoad();
  });

  afterAll(async () => {
    await godot.takeScreenshot('regression_smoke_final');
    await godot.closeBrowser();
  });

  test('game loads without JS errors', async () => {
    const log = await godot.getConsoleLog();
    expect(log).not.toContain('[PAGE_ERROR]');
    await godot.takeScreenshot('regression_load');
  });

  test('main menu renders with buttons', async () => {
    const menuVisible = await gameActions.isMenuVisible();
    expect(menuVisible).toBe(true);
  });

  test('new game starts without crash', async () => {
    await gameActions.startNewGame();
    await godot.waitMs(2000);
    await godot.takeScreenshot('regression_after_newgame');
    const log = await godot.getConsoleLog();
    expect(log).not.toContain('[PAGE_ERROR]');
  });

  test('player exists and has position', async () => {
    const pos = await gameActions.getPlayerPosition();
    expect(pos).toBeDefined();
    expect(typeof pos.x).toBe('number');
    expect(typeof pos.y).toBe('number');
  });

  test('HUD shows HP 100/100', async () => {
    const hp = await gameActions.getHPFromHUD();
    expect(hp).toContain('100');
  });

  test('movement works in all 4 directions', async () => {
    const start = await gameActions.getPlayerPosition();
    await gameActions.movePlayer('right', 300);
    const afterRight = await gameActions.getPlayerPosition();
    await gameActions.movePlayer('left', 300);
    const afterLeft = await gameActions.getPlayerPosition();
    await gameActions.movePlayer('up', 300);
    const afterUp = await gameActions.getPlayerPosition();
    await gameActions.movePlayer('down', 300);
    const afterDown = await gameActions.getPlayerPosition();
    expect(afterRight.x).not.toBeCloseTo(start.x, -1);
    expect(afterLeft.x).toBeLessThan(afterRight.x);
    expect(afterUp.y).toBeLessThan(start.y);
    expect(afterDown.y).toBeGreaterThan(afterUp.y);
    await godot.takeScreenshot('regression_movement');
  });

  test('inventory opens and closes', async () => {
    await gameActions.openInventory();
    const state1 = await godot.getGameState();
    expect(state1.inventoryVisible).toBe(true);
    await gameActions.closeInventory();
    const state2 = await godot.getGameState();
    expect(state2.inventoryVisible).toBe(false);
  });

  test('no JS errors after all operations', async () => {
    const log = await godot.getConsoleLog();
    expect(log).not.toContain('[PAGE_ERROR]');
  });
});
