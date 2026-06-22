const godot = require('../helpers/godot_page');
const gameActions = require('../helpers/game_actions');

const MIN_X = 80, MAX_X = 2480, MIN_Y = 80, MAX_Y = 1840;

describe('Gray Zone Fix — Bounds Check', () => {
  afterEach(async () => {
    await godot.closeBrowser();
  });

  test('all items within green map bounds', async () => {
    await godot.loadGame();
    await gameActions.waitForGameLoad();
    await gameActions.startNewGame();
    await godot.waitMs(3000);

    const items = await godot.evaluateInPage(() => window.gameItemPositions || []);
    let outOfBounds = 0;
    for (const item of items) {
      if (item.x < MIN_X || item.x > MAX_X || item.y < MIN_Y || item.y > MAX_Y) {
        outOfBounds++;
        console.log('  OUT OF BOUNDS:', JSON.stringify(item));
      }
    }
    console.log('Items total:', items.length, '| out of bounds:', outOfBounds);
    expect(outOfBounds).toBe(0);
    expect(items.length).toBeGreaterThan(0);
  }, 60000);

  test('all monsters within green map bounds', async () => {
    await godot.loadGame();
    await gameActions.waitForGameLoad();
    await gameActions.startNewGame();
    await godot.waitMs(3000);

    const monsters = await godot.evaluateInPage(() => window.gameMonsterStates || []);
    let outOfBounds = 0;
    for (const m of monsters) {
      const pos = m.position || {};
      // Map edge = 2560×1920, allow half-tile margin
      if (pos.x < 16 || pos.x > 2544 || pos.y < 16 || pos.y > 1904) {
        outOfBounds++;
        console.log('  MONSTER OUT:', m.name, JSON.stringify(pos));
      }
    }
    console.log('Monsters total:', monsters.length, '| out of bounds:', outOfBounds);
    expect(outOfBounds).toBe(0);
    expect(monsters.length).toBeGreaterThan(0);
  }, 60000);

  test('screenshot for Vision — all green map', async () => {
    await godot.loadGame();
    await gameActions.waitForGameLoad();
    await gameActions.startNewGame();
    await godot.waitMs(3000);
    const ss = await godot.takeScreenshot('gray_zone_all_green');
    console.log('Screenshot:', ss);
    expect(ss).toBeTruthy();
  }, 60000);
});
