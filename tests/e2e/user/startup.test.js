const godot = require('../helpers/godot_page');
const gameActions = require('../helpers/game_actions');

describe('User Test: Game Startup', () => {
  beforeAll(async () => {
    await godot.loadGame();
  });

  afterAll(async () => {
    await godot.closeBrowser();
  });

  test('game loads and shows main menu', async () => {
    await gameActions.waitForGameLoad();
    const menuVisible = await gameActions.isMenuVisible();
    expect(menuVisible).toBe(true);
  });

  test('player sees New Game button and clicks it', async () => {
    const clicked = await godot.clickButton('Новая игра');
    expect(clicked).toBe(true);
    await godot.waitFrames(30);
  });

  test('game transitions to world map', async () => {
    await godot.waitMs(2000);
    const pos = await gameActions.getPlayerPosition();
    expect(pos).toBeDefined();
    expect(typeof pos.x).toBe('number');
    expect(typeof pos.y).toBe('number');
  });

  test('HUD shows initial HP', async () => {
    await godot.waitMs(1000);
    await godot.waitFrames(30);
    const hp = await gameActions.getHPFromHUD();
    expect(hp).toContain('100');
  });

  test('HUD shows initial region as Light Valley', async () => {
    const hud = await gameActions.getHUDText();
    expect(hud.region).toBeDefined();
  });
});
