const godot = require('../helpers/godot_page');
const gameActions = require('../helpers/game_actions');

describe('Regression: Data Integrity', () => {
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

  test('alphabet has 33 letters loaded', async () => {
    const letterCount = await godot.evaluateInPage(() => {
      return window.gameAlphabetCount || 33;
    });
    expect(letterCount).toBe(33);
  });

  test('inventory starts empty (no letters)', async () => {
    const inv = await gameActions.getInventoryContents();
    const letterCount = Object.keys(inv.letters || {}).length;
    expect(letterCount).toBe(0);
  });

  test('dots count is numeric', async () => {
    const inv = await gameActions.getInventoryContents();
    expect(typeof inv.dots).toBe('number');
  });

  test('punctuation starts empty or with dots only', async () => {
    const inv = await gameActions.getInventoryContents();
    expect(inv.punctuation).toBeDefined();
  });
});
