// Targeted capture: hero mid-stride (wobble tilt) + Dark Oaks landscape + forest.
const godot = require('./helpers/godot_page');
const game = require('./helpers/game_actions');

describe('Wobble + landscape capture', () => {
  jest.setTimeout(120000);
  beforeAll(async () => { await godot.loadGame(); await game.waitForGameLoad(); });
  afterAll(async () => { await godot.closeBrowser(); });

  test('capture hero wobble + maps', async () => {
    await game.startNewGame();
    await godot.waitMs(2000);

    // --- Light Valley: walk right continuously, grab 3 mid-stride frames ---
    const canvas = await godot.getPage().$('canvas');
    for (let i = 0; i < 3; i++) {
      await godot.holdKey('KeyD', 300);
      await godot.takeScreenshot('wobble_valley_' + i);
    }

    // --- Forest (level 2): switch + walk ---
    await godot.evaluateInPage(() => { if (typeof window.gameTestGotoMap === 'function') window.gameTestGotoMap('two_letter_forest'); });
    await godot.waitMs(3000);
    await godot.takeScreenshot('landscape_forest');
    for (let i = 0; i < 3; i++) {
      await godot.holdKey('KeyD', 300);
      await godot.takeScreenshot('wobble_forest_' + i);
    }

    // --- Dark Oaks (level 3): new dark generator + ambient + Знак/Звук ---
    await godot.evaluateInPage(() => { if (typeof window.gameTestGotoMap === 'function') window.gameTestGotoMap('dark_oaks'); });
    await godot.waitMs(3000);
    await godot.takeScreenshot('landscape_dark_oaks');
    await godot.holdKey('KeyD', 400);
    await godot.takeScreenshot('wobble_dark_oaks');

    // --- Verify Знак on level 2 via the snapshot taken earlier (re-switch briefly) ---
    await godot.evaluateInPage(() => { if (typeof window.gameTestGotoMap === 'function') window.gameTestGotoMap('two_letter_forest'); });
    await godot.waitMs(3000);
    const monsters = await game.getMonsterStates();
    const znak = monsters.filter(m => m.id === 'znak');
    console.log('FOREST znak count:', znak.length, '| total monsters:', monsters.length);
    await godot.takeScreenshot('forest_znak_check');

    // --- Dark Oaks Знак+Звук ---
    await godot.evaluateInPage(() => { if (typeof window.gameTestGotoMap === 'function') window.gameTestGotoMap('dark_oaks'); });
    await godot.waitMs(3000);
    const m2 = await game.getMonsterStates();
    const zn = m2.filter(m => m.id === 'znak');
    const zv = m2.filter(m => m.id === 'zvuk');
    console.log('DARK_OAKS znak:', zn.length, 'zvuk:', zv.length, '| total:', m2.length);
    expect(zn.length).toBeGreaterThanOrEqual(1);
    expect(zv.length).toBeGreaterThanOrEqual(1);
    expect(znak.length).toBeGreaterThanOrEqual(1);
  });
});
