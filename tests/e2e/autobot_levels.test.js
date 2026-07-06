// Autobot: plays Level 1 (Light Valley) and Level 2 (Two-Letter Forest) end-to-end.
// Uses the in-combat AUTO-BATTLE feature (picks unused letters each round).
const godot = require('./helpers/godot_page');
const gameActions = require('./helpers/game_actions');

async function shot(label) {
  const p = await godot.takeScreenshot('autobot_' + label);
  console.log('SHOT', label, require('path').basename(p));
}

async function autoWinCombat(timeoutMs) {
  // Enable auto-battle and wait for combat to resolve (win/lose) then return to world
  await godot.evaluateInPage(() => {
    window.gameAutoRounds = 0;
    if (typeof window.gameAutoBattle === 'function') window.gameAutoBattle();
  });
  // wait for combat to end
  const ended = await gameActions.waitForCombatEnd(timeoutMs || 45000);
  await godot.waitMs(2500); // return-to-world transition
  return ended;
}

describe('Autobot: Level 1 + Level 2', () => {
  jest.setTimeout(240000);

  beforeAll(async () => {
    await godot.loadGame();
    await gameActions.waitForGameLoad();
  });
  afterAll(async () => { await godot.closeBrowser(); });

  test('LEVEL 1 — Светлая Долина', async () => {
    await gameActions.startNewGame();
    await godot.waitMs(2500);

    let hud = await gameActions.getHUDText();
    console.log('L1 region:', hud.region);
    expect(hud.region).toContain('Долина');
    await shot('l1_01_spawn');

    // Give a small letter set so auto-battle can win
    for (const l of ['А', 'Б', 'О', 'М']) { await gameActions.testAddLetter(l); await godot.waitMs(120); }
    // Collect some dots
    await gameActions.testAddDots(6);
    await godot.waitMs(400);
    await shot('l1_02_prepared');

    // Fight a Light Valley exclamation monster via test combat, AUTO-BATTLE
    await gameActions.startTestCombat('Страж Долины', 60, ['Я']);
    const inC1 = await gameActions.waitForCombat(12000);
    expect(inC1).toBe(true);
    await shot('l1_03_combat_start');
    await autoWinCombat(45000);
    const stillInC = await gameActions.isInCombat();
    expect(stillInC).toBe(false);
    await shot('l1_04_after_battle');

    console.log('L1 DONE');
  });

  test('LEVEL 2 — Лес Двубуквия', async () => {
    // Switch to level 2 map
    await godot.evaluateInPage(() => {
      if (typeof window.gameTestGotoMap === 'function') window.gameTestGotoMap('two_letter_forest');
    });
    await godot.waitMs(3500); // scene reload

    let hud = await gameActions.getHUDText();
    console.log('L2 region:', hud.region);
    await shot('l2_01_spawn');

    // Verify level 2 actually loaded: monsters present
    await godot.waitMs(500);
    const monsters = await gameActions.getMonsterStates();
    console.log('L2 monster count:', monsters.length);
    expect(monsters.length).toBeGreaterThan(0);

    // Give a stronger letter set for forest foes
    for (const l of ['А', 'Б', 'О', 'М', 'В', 'К']) { await gameActions.testAddLetter(l); await godot.waitMs(120); }
    await shot('l2_02_prepared');

    // Fight a forest monster (Тенелюд-style) via test combat, AUTO-BATTLE
    await gameActions.startTestCombat('Лесной Страж', 90, ['А', 'К']);
    const inC2 = await gameActions.waitForCombat(12000);
    expect(inC2).toBe(true);
    await shot('l2_03_combat_start');
    await autoWinCombat(45000);
    const stillInC2 = await gameActions.isInCombat();
    expect(stillInC2).toBe(false);
    await shot('l2_04_after_battle');

    console.log('L2 DONE');
  });
});
