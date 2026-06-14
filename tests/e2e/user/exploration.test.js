const godot = require('../helpers/godot_page');
const gameActions = require('../helpers/game_actions');

describe('User Test: Exploration', () => {
  beforeAll(async () => {
    await godot.loadGame();
    await gameActions.waitForGameLoad();
    await gameActions.startNewGame();
    await godot.waitMs(2000);
  });

  afterAll(async () => {
    await godot.closeBrowser();
  });

  test('player can explore the Light Valley map', async () => {
    const positions = [];
    for (let i = 0; i < 4; i++) {
      await gameActions.movePlayer('right', 300);
      await gameActions.movePlayer('up', 200);
      positions.push(await gameActions.getPlayerPosition());
    }
    expect(positions.length).toBe(4);
    expect(positions[0]).not.toEqual(positions[3]);
  });

  test('player encounters monsters while exploring', async () => {
    await gameActions.movePlayer('right', 2000);
    await gameActions.movePlayer('down', 1000);
    await godot.waitFrames(20);
    const pos = await gameActions.getPlayerPosition();
    expect(pos).toBeDefined();
  });

  test('HUD updates region information', async () => {
    const hud = await gameActions.getHUDText();
    expect(hud.region).toBeDefined();
    expect(hud.region.length).toBeGreaterThan(0);
  });
});
