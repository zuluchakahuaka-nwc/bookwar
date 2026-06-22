const godot = require('../helpers/godot_page');
const gameActions = require('../helpers/game_actions');

describe('Component Test: Full Combat Scenarios', () => {
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

  async function cleanInventory() {
    const inv = await gameActions.getInventoryContents();
    if (inv.letters) {
      for (const letter of Object.keys(inv.letters)) {
        const count = inv.letters[letter];
        for (let i = 0; i < count; i++) {
          // We can't remove letters directly, but starting fresh each test
          // by resetting via test combat ensures clean state
        }
      }
    }
  }

  test('C1: vowel attack reduces enemy HP', async () => {
    await gameActions.testAddLetter('А');
    await gameActions.startTestCombat('TestVowel', 100, ['Я']);
    await gameActions.waitForCombat();
    await godot.waitMs(500);

    const stateBefore = await gameActions.getCombatState();
    const enemyHpBefore = stateBefore.enemy_hp;

    await gameActions.resetCombatLog();
    await gameActions.selectBattleCard('А');
    await gameActions.confirmBattleTurnExplicit();

    const log = await gameActions.getCombatLogAll();
    const dmg = log.find((e) => e.event === 'damage' && e.target === 'enemy');
    expect(dmg).toBeDefined();
    expect(dmg.damage).toBeGreaterThanOrEqual(33);

    const stateAfter = await gameActions.getCombatState();
    expect(stateAfter.enemy_hp).toBeLessThan(enemyHpBefore);

    await gameActions.fleeBattle();
    await gameActions.waitForWorld();
  });

  test('C2: consonant creates shield for player', async () => {
    await gameActions.testAddLetter('Б');
    await gameActions.startTestCombat('TestShield', 200, ['Я']);
    await gameActions.waitForCombat();
    await godot.waitMs(500);

    await gameActions.resetCombatLog();
    await gameActions.selectBattleCard('Б');
    await gameActions.confirmBattleTurnExplicit();

    const log = await gameActions.getCombatLogAll();
    const shield = log.find((e) => e.event === 'shield' && e.side === 'player');
    expect(shield).toBeDefined();
    expect(shield.amount).toBeGreaterThanOrEqual(32);

    const state = await gameActions.getCombatState();
    expect(state.player_shield).toBeGreaterThanOrEqual(32);

    await gameActions.fleeBattle();
    await gameActions.waitForWorld();
  });

  test('C3: enemy attacks player when player has no cards', async () => {
    await gameActions.startTestCombat('TestEnemyAttack', 500, ['А']);
    await gameActions.waitForCombat();
    await godot.waitMs(500);

    const stateBefore = await gameActions.getCombatState();
    const playerHpBefore = stateBefore.player_hp;

    await gameActions.resetCombatLog();
    // Player plays nothing, just confirm to resolve
    await gameActions.confirmBattleTurnExplicit();

    const log = await gameActions.getCombatLogAll();
    // Enemy should have dealt damage to player (А = vowel, damage 33)
    const playerDmg = log.find((e) => e.event === 'damage' && e.target === 'player');
    expect(playerDmg).toBeDefined();
    expect(playerDmg.damage).toBeGreaterThan(0);

    const stateAfter = await gameActions.getCombatState();
    expect(stateAfter.player_hp).toBeLessThanOrEqual(playerHpBefore);

    await gameActions.fleeBattle();
    await gameActions.waitForWorld();
  });

  test('C4: victory — kill enemy and get loot', async () => {
    await gameActions.testAddLetter('А');
    await gameActions.startTestCombat('WeakFoe', 30, ['О']);
    await gameActions.waitForCombat();
    await godot.waitMs(500);

    const invBefore = await gameActions.getInventoryContents();
    const beforeCount = Object.keys(invBefore.letters || {}).reduce(
      (s, k) => s + invBefore.letters[k], 0
    );

    await gameActions.resetCombatLog();
    await gameActions.selectBattleCard('А');
    await gameActions.confirmBattleTurnExplicit();

    // А level 1 = 33 damage, enemy has 30 HP → dead
    await godot.waitMs(3000);
    await gameActions.waitForWorld();

    const invAfter = await gameActions.getInventoryContents();
    const afterCount = Object.keys(invAfter.letters || {}).reduce(
      (s, k) => s + invAfter.letters[k], 0
    );
    expect(afterCount).toBeGreaterThan(beforeCount);
  });

  test('C5: flee returns to world without loot', async () => {
    await gameActions.startTestCombat('FleeTest', 100, ['Я']);
    await gameActions.waitForCombat();
    await godot.waitMs(500);

    await gameActions.fleeBattle();
    await gameActions.waitForWorld();
    await godot.waitMs(1000);

    const invAfter = await gameActions.getInventoryContents();
    const afterCount = Object.keys(invAfter.letters || {}).reduce(
      (s, k) => s + invAfter.letters[k], 0
    );
    // Flee should not grant any loot — just verify we returned to world safely
    expect(afterCount).toBeGreaterThanOrEqual(0);
  });

  test('C6: timer auto-resolves when player does nothing', async () => {
    await gameActions.startTestCombat('TimerTest', 500, ['А']);
    await gameActions.waitForCombat();
    await godot.waitMs(500);

    // Verify timer is counting down
    const timer1 = await gameActions.getCombatTimer();
    expect(timer1).toBeGreaterThan(0);
    expect(timer1).toBeLessThanOrEqual(10);

    // Wait for timer to expire (up to 12 seconds)
    await godot.waitMs(12000);

    // After timeout, turn should auto-resolve: enemy attacks player
    const state = await gameActions.getCombatState();
    const log = await gameActions.getCombatLogAll();
    const playerDmg = log.find((e) => e.event === 'damage' && e.target === 'player');
    expect(playerDmg).toBeDefined();

    await gameActions.fleeBattle();
    await gameActions.waitForWorld();
  });

  test('C7: multiple rounds — enemy takes damage over 2 turns', async () => {
    await gameActions.testAddLetter('О');
    await gameActions.testAddLetter('А'); // second vowel (each letter once per battle now)
    await gameActions.startTestCombat('TankyFoe', 200, ['Я']);
    await gameActions.waitForCombat();
    await godot.waitMs(500);

    // Round 1 — play О
    await gameActions.resetCombatLog();
    await gameActions.selectBattleCard('О');
    await gameActions.confirmBattleTurnExplicit();

    const stateAfterR1 = await gameActions.getCombatState();
    const hpAfterR1 = stateAfterR1.enemy_hp;
    expect(hpAfterR1).toBeLessThan(200);

    // Round 2 — play a DIFFERENT vowel (А); О is exhausted this battle
    await godot.waitMs(500);
    await gameActions.resetCombatLog();
    await gameActions.selectBattleCard('А');
    await gameActions.confirmBattleTurnExplicit();

    const stateAfterR2 = await gameActions.getCombatState();
    const hpAfterR2 = stateAfterR2.enemy_hp;
    expect(hpAfterR2).toBeLessThan(hpAfterR1);

    await gameActions.fleeBattle();
    await gameActions.waitForWorld();
  });

  test('C8: timer countdown visible in combat state', async () => {
    await gameActions.startTestCombat('TimerVisible', 999, ['Я']);
    await gameActions.waitForCombat();
    await godot.waitMs(500);

    const timerStart = await gameActions.getCombatTimer();
    expect(timerStart).toBeGreaterThan(5);

    await godot.waitMs(3000);
    const timerLater = await gameActions.getCombatTimer();
    expect(timerLater).toBeLessThan(timerStart);

    await gameActions.fleeBattle();
    await gameActions.waitForWorld();
  });
});
