const godot = require('../helpers/godot_page');
const gameActions = require('../helpers/game_actions');

// Wait until the world TestBridge is live (gameTestGotoMap registered), with a hard timeout.
async function waitForWorldBridge(timeoutMs = 20000) {
  await godot.waitForCondition(
    () => godot.evaluateInPage(() => typeof window.gameTestGotoMap === 'function'),
    timeoutMs,
    400
  );
}

async function snapshotAfterSwitch(mapId, label) {
  await godot.evaluateInPage((m) => { window.gameTestGotoMap(m); }, mapId);
  await godot.waitMs(4000); // scene reload + deferred spawn + state push
  const data = await godot.evaluateInPage(() => ({
    total: window.gameTotalMonsters || 0,
    monsters: window.gameMonsterStates || [],
  }));
  await godot.takeScreenshot('levels_' + label);
  return data;
}

describe('Regression: 33-level progression system', () => {
  jest.setTimeout(120000);

  beforeAll(async () => {
    await godot.loadGame();
    await gameActions.waitForGameLoad();
    await gameActions.startNewGame();
    await waitForWorldBridge();
  });

  afterAll(async () => {
    await godot.closeBrowser();
  });

  test('level 1 (light_valley) spawns monsters', async () => {
    const total = await godot.evaluateInPage(() => window.gameTotalMonsters || 0);
    expect(total).toBeGreaterThanOrEqual(1);
  });

  test('mid level 15 (ice_pincers) loads via generic spawner', async () => {
    const data = await snapshotAfterSwitch('ice_pincers', 'lv15');
    expect(data.total).toBeGreaterThanOrEqual(20);
    expect(await godot.getConsoleLog()).not.toContain('[PAGE_ERROR]');
  });

  test('final level 33 (well_of_letters) is a mass battle with boss + lieutenants', async () => {
    const data = await snapshotAfterSwitch('well_of_letters', 'lv33_final');
    expect(data.total).toBeGreaterThanOrEqual(40);
    const ids = data.monsters.map((m) => m.id);
    expect(ids).toContain('keeper_of_ban');
    expect(ids).toContain('znak');
    expect(ids).toContain('zvuk');
    expect(ids).toContain('question');
    const boss = data.monsters.find((m) => m.id === 'keeper_of_ban');
    expect(boss.max_hp).toBeGreaterThanOrEqual(400);
    expect(await godot.getConsoleLog()).not.toContain('[PAGE_ERROR]');
  });
});
