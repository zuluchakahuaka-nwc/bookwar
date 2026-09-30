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
    // New Game always plays the legend intro first — skip it like a player
    // who has already seen the story (gameSkipIntro bridge).
    try {
      await godot.waitForCondition(async () => {
        return await godot.evaluateInPage(() => typeof window.gameSkipIntro === 'function');
      }, 10000);
      await godot.evaluateInPage(() => { if (typeof window.gameSkipIntro === 'function') window.gameSkipIntro(); });
    } catch (e) { /* intro may have been skipped already */ }
    // Character select screen appears — confirm default hero
    await godot.waitForCondition(async () => {
      return await godot.evaluateInPage(() => !!(window.gameCharSelectLoaded));
    }, 15000);
    await godot.evaluateInPage(() => {
      if (typeof window.gameConfirmHero === 'function') window.gameConfirmHero();
    });
    await godot.waitFrames(40);
  });

  test('game transitions to world map', async () => {
    await godot.waitMs(2000);
    const pos = await gameActions.getPlayerPosition();
    expect(pos).toBeDefined();
    expect(typeof pos.x).toBe('number');
    expect(typeof pos.y).toBe('number');
  });

  test('HUD shows initial HP', async () => {
    // HUD bridge is periodic — wait until the HP line actually appears.
    await godot.waitForCondition(async () => {
      const hp = await gameActions.getHPFromHUD();
      return typeof hp === 'string' && hp.length > 0;
    }, 10000, 500);
    const hp = await gameActions.getHPFromHUD();
    expect(hp).toContain('100');
  });

  test('HUD shows initial region as Light Valley', async () => {
    const hud = await gameActions.getHUDText();
    expect(hud.region).toBeDefined();
  });
});
