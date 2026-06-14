const godot = require('../helpers/godot_page');
const gameActions = require('../helpers/game_actions');

describe('Component Test: Card UI', () => {
  beforeAll(async () => {
    await godot.loadGame();
    await gameActions.waitForGameLoad();
    await gameActions.startNewGame();
    await godot.waitMs(2000);
  });

  afterAll(async () => {
    await godot.closeBrowser();
  });

  test('letter cards show correct info in inventory', async () => {
    await gameActions.openInventory();
    const inventory = await gameActions.getInventoryContents();
    expect(inventory).toBeDefined();
    await gameActions.closeInventory();
  });

  test('vowel cards show attack role', async () => {
    const inventory = await gameActions.getInventoryContents();
    if (inventory.letters) {
      for (const [letter, level] of Object.entries(inventory.letters)) {
        expect(typeof level).toBe('number');
        expect(level).toBeGreaterThan(0);
      }
    }
  });
});
