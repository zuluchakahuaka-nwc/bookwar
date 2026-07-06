const godot = require('../helpers/godot_page');
const gameActions = require('../helpers/game_actions');

describe('Component Test: HUD', () => {
  beforeAll(async () => {
    await godot.loadGame();
    await gameActions.waitForGameLoad();
    await gameActions.startNewGame();
    await godot.waitMs(2000);
  });

  afterAll(async () => {
    await godot.closeBrowser();
  });

  test('HUD displays HP on game start', async () => {
    const hp = await gameActions.getHPFromHUD();
    expect(hp).toBeDefined();
  });

  test('HUD displays dots count', async () => {
    const dots = await gameActions.getDotsFromHUD();
    expect(dots).toBeDefined();
  });

  test('HUD updates dots when player picks up a dot', async () => {
    const before = await gameActions.getDotsFromHUD();
    await gameActions.movePlayer('right', 500);
    await gameActions.interact();
    await godot.waitFrames(10);
    const after = await gameActions.getDotsFromHUD();
    expect(after).not.toBe(before);
  });
});
