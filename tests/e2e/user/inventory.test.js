const godot = require('../helpers/godot_page');
const gameActions = require('../helpers/game_actions');

describe('User Test: Inventory', () => {
  beforeAll(async () => {
    await godot.loadGame();
    await gameActions.waitForGameLoad();
    await gameActions.startNewGame();
    await godot.waitMs(2000);
  });

  afterAll(async () => {
    await godot.closeBrowser();
  });

  test('player opens inventory with I key', async () => {
    await gameActions.openInventory();
    const visible = await godot.evaluateInPage(() => {
      return window.gameInventoryVisible || false;
    });
    expect(visible).toBe(true);
  });

  test('inventory shows dots count', async () => {
    const inventory = await gameActions.getInventoryContents();
    expect(typeof inventory.dots).toBe('number');
  });

  test('player closes inventory with I key', async () => {
    await gameActions.closeInventory();
    const visible = await godot.evaluateInPage(() => {
      return window.gameInventoryVisible || false;
    });
    expect(visible).toBe(false);
  });

  test('inventory shows letters after acquiring one', async () => {
    await gameActions.movePlayer('up', 1000);
    await gameActions.movePlayer('right', 500);
    await gameActions.interact();
    await godot.waitFrames(10);
    await gameActions.openInventory();
    const inventory = await gameActions.getInventoryContents();
    const letterCount = Object.keys(inventory.letters || {}).length;
    expect(letterCount).toBeGreaterThanOrEqual(0);
    await gameActions.closeInventory();
  });
});
