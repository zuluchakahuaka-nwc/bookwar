const godot = require('../helpers/godot_page');
const gameActions = require('../helpers/game_actions');

// Combat formulas:
//   damage(vowel) = base_power * level * VOWEL_MULTIPLIER(1.0)
//   shield(consonant) = base_power * level * CONSONANT_MULTIPLIER(1.0)
//   sign buff = SIGN_MULTIPLIER(1.5)
//   turn order: speed desc (33 -> 1)
describe('Component Test: Combat System', () => {
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

  test('vowel А at level 1 deals 33 damage in combat log', async () => {
    await gameActions.testAddLetter('А');
    await gameActions.startTestCombat('TestVowel', 100, ['Б']);
    await gameActions.waitForCombat();
    await gameActions.resetCombatLog();
    await gameActions.selectBattleCard('А');
    await gameActions.confirmBattleTurnExplicit();
    const log = await gameActions.getCombatLogAll();
    const dmg = log.find((e) => e.event === 'damage' && e.letter === 'А');
    expect(dmg).toBeDefined();
    expect(dmg.damage).toBeGreaterThanOrEqual(33); // 33 base * 1 level
    await gameActions.fleeBattle();
    await gameActions.waitForWorld();
  });

  test('consonant creates shield (not damage) when played', async () => {
    await gameActions.testAddLetter('Б');
    await gameActions.startTestCombat('TestShield', 100, ['А']);
    await gameActions.waitForCombat();
    await gameActions.resetCombatLog();
    await gameActions.selectBattleCard('Б');
    await gameActions.confirmBattleTurnExplicit();
    const log = await gameActions.getCombatLogAll();
    const shield = log.find((e) => e.event === 'shield' && e.letter === 'Б');
    expect(shield).toBeDefined();
    expect(shield.amount).toBeGreaterThanOrEqual(32); // Б base 32 * 1 level
    await gameActions.fleeBattle();
    await gameActions.waitForWorld();
  });

  test('level scaling: А level 3 deals 99 damage', async () => {
    await gameActions.testAddLetter('А');
    await gameActions.testAddLetter('А'); // now level 3
    await gameActions.startTestCombat('TestScale', 300, ['Б']);
    await gameActions.waitForCombat();
    await gameActions.resetCombatLog();
    await gameActions.selectBattleCard('А');
    await gameActions.confirmBattleTurnExplicit();
    const log = await gameActions.getCombatLogAll();
    const dmg = log.find((e) => e.event === 'damage' && e.letter === 'А');
    expect(dmg).toBeDefined();
    expect(dmg.damage).toBeGreaterThanOrEqual(99); // 33 * 3
    await gameActions.fleeBattle();
    await gameActions.waitForWorld();
  });

  test('turn order resolved fastest-first (Я before А)', async () => {
    await gameActions.testAddLetter('Я');
    await gameActions.testAddLetter('А');
    await gameActions.startTestCombat('TestOrder', 500, []);
    await gameActions.waitForCombat();
    await gameActions.resetCombatLog();
    await gameActions.selectBattleCard('А');
    await gameActions.selectBattleCard('Я');
    await gameActions.confirmBattleTurnExplicit();
    const order = await gameActions.getCombatTurnOrder();
    expect(order).toBeTruthy();
    expect(order.length).toBeGreaterThanOrEqual(2);
    // First in resolved order must be the faster card (Я speed 33)
    expect(order[0].char).toBe('Я');
    await gameActions.fleeBattle();
    await gameActions.waitForWorld();
  });

  test('Ь sign applies ×1.5 attack buff to next vowel', async () => {
    await gameActions.testAddLetter('Ь');
    await gameActions.testAddLetter('Е'); // vowel base 28
    await gameActions.startTestCombat('TestBuff', 500, []);
    await gameActions.waitForCombat();
    await gameActions.resetCombatLog();
    await gameActions.selectBattleCard('Ь');
    await gameActions.selectBattleCard('Е');
    await gameActions.confirmBattleTurnExplicit();
    const log = await gameActions.getCombatLogAll();
    const buff = log.find((e) => e.event === 'buff' && e.letter === 'Ь');
    expect(buff).toBeDefined();
    expect(buff.multiplier).toBeCloseTo(1.5, 5);
    const dmg = log.find((e) => e.event === 'damage' && e.letter === 'Е');
    expect(dmg).toBeDefined();
    expect(dmg.buff_mult).toBeCloseTo(1.5, 5);
    await gameActions.fleeBattle();
    await gameActions.waitForWorld();
  });

  test('loot: winning combat grants letters to inventory', async () => {
    await gameActions.testAddLetter('А');
    const beforeInv = await gameActions.getInventoryContents();
    const beforeCount = Object.keys(beforeInv.letters || {}).reduce(
      (s, k) => s + beforeInv.letters[k], 0
    );
    await gameActions.startTestCombat('WeakFoe', 1, ['О']); // 1 HP enemy -> one-shot
    await gameActions.waitForCombat();
    await gameActions.resetCombatLog();
    await gameActions.selectBattleCard('А');
    await gameActions.confirmBattleTurnExplicit();
    await godot.waitMs(2500); // wait for loot + return-to-world
    await gameActions.waitForWorld();
    const afterInv = await gameActions.getInventoryContents();
    const afterCount = Object.keys(afterInv.letters || {}).reduce(
      (s, k) => s + afterInv.letters[k], 0
    );
    expect(afterCount).toBeGreaterThan(beforeCount);
  });
});
