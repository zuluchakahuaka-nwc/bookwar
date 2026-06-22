// Demo bot: Level 1 corridor → Level 2 → boss fight (Двуязыкий / two_tongue).
const godot = require('./helpers/godot_page');
const gameActions = require('./helpers/game_actions');

async function shot(label) {
  const p = await godot.takeScreenshot('demo_' + label);
  console.log('SHOT', label, require('path').basename(p));
}

describe('Demo: corridor L1→L2 + boss', () => {
  jest.setTimeout(240000);
  beforeAll(async () => { await godot.loadGame(); await gameActions.waitForGameLoad(); });
  afterAll(async () => { await godot.closeBrowser(); });

  test('L1 cleared → portal → L2 → boss', async () => {
    await gameActions.startNewGame();
    await godot.waitMs(2500);
    await shot('l1_start');

    // Clear level 1 (neutralize all hostiles) → triggers victory + portal
    await godot.evaluateInPage(() => { if (typeof window.gameClearRegion === 'function') window.gameClearRegion(); });
    // wait for portal to spawn
    await godot.waitForCondition(async () => {
      return await godot.evaluateInPage(() => !!window.gamePortalSpawned);
    }, 12000);
    await shot('l1_portal_spawned');

    // Walk north into the portal (portal is ~800px north of start)
    for (let i = 0; i < 10; i++) {
      const inL2 = await godot.evaluateInPage(() => (window.gameHUD && window.gameHUD.region) || '');
      if (inL2.includes('Лес') || inL2.includes('лес')) break;
      await gameActions.movePlayer('up', 700);
      await godot.waitMs(200);
    }
    await godot.waitMs(2500);
    const hud = await gameActions.getHUDText();
    console.log('After portal region:', hud.region);
    await shot('l2_arrived');

    // Find the boss (two_tongue) among monsters
    await godot.waitMs(500);
    const monsters = await gameActions.getMonsterStates();
    const boss = monsters.find((m) => m.id === 'two_tongue');
    console.log('Boss present:', !!boss, boss ? JSON.stringify({id: boss.id, name: boss.name, hp: boss.hp}) : '');
    await shot('l2_boss_on_map');

    // Give a strong arsenal and fight the boss via test combat using boss stats
    for (const l of ['А', 'Б', 'О', 'М', 'В', 'К', 'Е', 'Р']) { await gameActions.testAddLetter(l); await godot.waitMs(100); }
    const bossHp = boss ? boss.hp : 120;
    await gameActions.startTestCombat('Двуязыкий', bossHp, ['А', 'Е', 'Б', 'В', 'Г']);
    await gameActions.waitForCombat(12000);
    await godot.waitMs(500);
    await shot('boss_combat_start');

    // Auto-battle the boss
    await godot.evaluateInPage(() => {
      window.gameAutoRounds = 0;
      if (typeof window.gameAutoBattle === 'function') window.gameAutoBattle();
    });
    await gameActions.waitForCombatEnd(60000);
    await godot.waitMs(2500);
    const inCombat = await gameActions.isInCombat();
    expect(inCombat).toBe(false);
    await shot('boss_combat_done');
    console.log('BOSS FIGHT DONE');
  });
});
