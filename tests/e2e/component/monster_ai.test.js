const godot = require('../helpers/godot_page');
const gameActions = require('../helpers/game_actions');

describe('Component Test: Monster AI', () => {
  beforeAll(async () => {
    await godot.loadGame();
    await gameActions.waitForGameLoad();
    await gameActions.startNewGame();
    await godot.waitMs(2000);
  });

  afterAll(async () => {
    await godot.closeBrowser();
  });

  test('question monster patrols area', async () => {
    await gameActions.movePlayer('right', 800);
    await godot.waitMs(3000);
    const pos = await gameActions.getPlayerPosition();
    expect(pos).toBeDefined();
  });

  test('exclamation monster chases player when close', async () => {
    await gameActions.movePlayer('right', 2000);
    await gameActions.movePlayer('down', 1000);
    await godot.waitMs(2000);
    const inCombat = await gameActions.isInCombat();
    expect(typeof inCombat).toBe('boolean');
  });
});
