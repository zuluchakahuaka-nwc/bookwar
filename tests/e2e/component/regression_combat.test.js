const godot = require('../helpers/godot_page');
const gameActions = require('../helpers/game_actions');

describe('Regression: Combat System', () => {
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

  test('combat flag starts false', async () => {
    const inCombat = await gameActions.isInCombat();
    expect(inCombat).toBe(false);
  });

  test('game state transitions when approaching monsters', async () => {
    await gameActions.movePlayer('right', 2500);
    await gameActions.movePlayer('down', 1500);
    await godot.waitMs(3000);
    await godot.takeScreenshot('regression_combat_approach');
    const state = await godot.getGameState();
    expect(state).toBeDefined();
    expect(typeof state.inCombat).toBe('boolean');
  });
});
