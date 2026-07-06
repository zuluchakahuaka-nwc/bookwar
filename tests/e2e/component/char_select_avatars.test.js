// Test: select different heroes via JS bridge + verify avatars render
const godot = require('../helpers/godot_page');
const gameActions = require('../helpers/game_actions');

describe('Character Select — Hero Avatars', () => {
  jest.setTimeout(90000);

  beforeAll(async () => {
    await godot.loadGame();
    await gameActions.waitForGameLoad();
  });

  afterAll(async () => {
    await godot.closeBrowser();
  });

  test('01 char select loads with 50 heroes', async () => {
    await godot.clickButton('Новая игра');
    await godot.waitForCondition(async () => {
      return await godot.evaluateInPage(() => !!(window.gameCharSelectLoaded));
    }, 10000);
    await godot.waitMs(1000);
    const count = await godot.evaluateInPage(() => window.gameHeroCount || 0);
    console.log('Hero count:', count);
    expect(count).toBe(50);
    await godot.takeScreenshot('charselect_01_loaded');
  });

  test('02 select hero index 5 (Дубослав)', async () => {
    await gameActions.selectHeroByIndex(5);
    await godot.waitMs(500);
    const name = await godot.evaluateInPage(() => window.gameSelectedHeroName || '');
    const idx = await godot.evaluateInPage(() => window.gameSelectedHeroIndex ?? -1);
    console.log('Selected index 5:', name, idx);
    expect(idx).toBe(5);
    expect(name).toBe('Дубослав');
    await godot.takeScreenshot('charselect_02_idx5');
  });

  test('03 select hero index 10 (Ратибор)', async () => {
    await gameActions.selectHeroByIndex(10);
    await godot.waitMs(500);
    const name = await godot.evaluateInPage(() => window.gameSelectedHeroName || '');
    const idx = await godot.evaluateInPage(() => window.gameSelectedHeroIndex ?? -1);
    console.log('Selected index 10:', name, idx);
    expect(idx).toBe(10);
    expect(name).toBe('Ратибор');
    await godot.takeScreenshot('charselect_03_idx10');
  });

  test('04 select hero index 24 (Щитомир)', async () => {
    await gameActions.selectHeroByIndex(24);
    await godot.waitMs(500);
    const name = await godot.evaluateInPage(() => window.gameSelectedHeroName || '');
    console.log('Selected index 24:', name);
    expect(name).toBe('Щитомир');
    await godot.takeScreenshot('charselect_04_idx24');
  });

  test('05 confirm hero and enter game world', async () => {
    // Select a specific hero then confirm
    await gameActions.selectHeroByIndex(2);
    await godot.waitMs(300);
    const nameBefore = await godot.evaluateInPage(() => window.gameSelectedHeroName || '');
    console.log('Confirming hero:', nameBefore);
    await gameActions.confirmHero();
    await godot.waitMs(3000);
    // Should be in game world now
    const pos = await gameActions.getPlayerPosition();
    console.log('Player position after confirm:', pos);
    expect(pos).toBeDefined();
    expect(typeof pos.x).toBe('number');
    await godot.takeScreenshot('charselect_05_in_game');
  });
});
