const godot = require('../helpers/godot_page');
const gameActions = require('../helpers/game_actions');

describe('F2: Visual battle — avatars, HP bars, damage popups', () => {
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

  test('battle shows avatars, HP bars, damage popups', async () => {
    await gameActions.testAddLetter('А');
    await gameActions.startTestCombat('VisualFoe', 40, ['Я']);
    await gameActions.waitForCombat(10000);
    await godot.waitMs(500);

    await godot.takeScreenshot('f2_battle_visual_start');

    const before = await gameActions.getCombatState();
    await gameActions.resetCombatLog();
    await gameActions.selectBattleCard('А');
    await gameActions.confirmBattleTurnExplicit();
    await godot.waitMs(800);

    await godot.takeScreenshot('f2_battle_visual_after_hit');

    const after = await gameActions.getCombatState();
    expect(after.turn_count).toBeGreaterThan(before.turn_count);

    await gameActions.fleeBattle();
    await gameActions.waitForWorld();
  });
});

describe('F1: Auto-battle (fresh session)', () => {
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

  test('auto-battle drives combat and resolves it', async () => {
    await gameActions.testAddLetter('А');
    await gameActions.testAddLetter('А');
    await gameActions.startTestCombat('AutoFoe', 30, ['Я']);
    await gameActions.waitForCombat(10000);
    await godot.waitMs(700);

    await godot.takeScreenshot('f1_autobattle_start');

    // Enable auto-battle
    await godot.evaluateInPage(() => {
      window.gameAutoRounds = 0;
      window.gameAutoDebug = '';
      if (typeof window.gameAutoBattle === 'function') window.gameAutoBattle();
    });

    // Poll for auto-battle to drive at least one round (resilient to harness timing)
    let rounds = 0;
    let debug = '';
    for (let i = 0; i < 30; i++) {
      await godot.waitMs(300);
      const info = await godot.evaluateInPage(() => ({ r: window.gameAutoRounds || 0, d: window.gameAutoDebug || '' }));
      rounds = info.r;
      debug = info.d;
      if (rounds >= 1) break;
    }
    expect(rounds).toBeGreaterThanOrEqual(1);

    // Combat should end (victory) — auto-battle plays rounds to completion
    await gameActions.waitForCombatEnd(45000);

    await godot.takeScreenshot('f1_autobattle_end');
    await godot.waitMs(2000);
    const inCombat = await gameActions.isInCombat();
    expect(inCombat).toBe(false);
  });
});
