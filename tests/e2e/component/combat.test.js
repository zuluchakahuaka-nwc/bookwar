const godot = require('../helpers/godot_page');
const gameActions = require('../helpers/game_actions');

// Combat formulas per AGENTS.md §2.3 + §20 inversion (base_power = position):
//   damage(vowel) = base_power * level * VOWEL_MULTIPLIER(1.0)
//   shield(consonant) = base_power * level * CONSONANT_MULTIPLIER(1.0)
//   sign buff = SIGN_MULTIPLIER(1.5)
//   turn order: speed desc (Я=33 -> А=1)
// Assert dynamically against window.gameAlphabet base_power — no hardcoded 33/32/28.
async function basePowerOf(letter) {
  return await godot.getPage().evaluate((l) => {
    const e = (window.gameAlphabet || []).find(a => a.char === l);
    return e ? e.base_power : 0;
  }, letter);
}
async function levelOf(letter) {
  return await godot.getPage().evaluate((l) => (window.gameInventory || {}).letters?.[l] || 0, letter);
}
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

  test('vowel А damage = base_power × level (combat log)', async () => {
    await gameActions.testAddLetter('А');
    const base = await basePowerOf('А');
    const lvl = await levelOf('А');
    expect(base).toBeGreaterThan(0);
    expect(lvl).toBeGreaterThan(0);
    await gameActions.startTestCombat('TestVowel', 100, ['Б']);
    await gameActions.waitForCombat();
    await gameActions.resetCombatLog();
    await gameActions.selectBattleCard('А');
    await gameActions.confirmBattleTurnExplicit();
    await godot.waitMs(1500); // resolve the turn (speed order: slow letters act late)
    const log = await gameActions.getCombatLogAll();
    const dmg = log.find((e) => e.event === 'damage' && e.letter === 'А');
    expect(dmg).toBeDefined();
    expect(dmg.damage).toBeGreaterThanOrEqual(base * lvl); // §20: base=position
    await gameActions.fleeBattle();
    await gameActions.waitForWorld();
  });

  test('consonant creates shield (not damage) when played', async () => {
    await gameActions.testAddLetter('Б');
    const base = await basePowerOf('Б');
    const lvl = await levelOf('Б');
    expect(base).toBeGreaterThan(0);
    expect(lvl).toBeGreaterThan(0);
    await gameActions.startTestCombat('TestShield', 100, ['А']);
    await gameActions.waitForCombat();
    await gameActions.resetCombatLog();
    await gameActions.selectBattleCard('Б');
    await gameActions.confirmBattleTurnExplicit();
    await godot.waitMs(1500); // resolve the turn (speed order: slow letters act late)
    const log = await gameActions.getCombatLogAll();
    const shield = log.find((e) => e.event === 'shield' && e.letter === 'Б');
    expect(shield).toBeDefined();
    expect(shield.amount).toBeGreaterThanOrEqual(base * lvl); // §20: base=position
    await gameActions.fleeBattle();
    await gameActions.waitForWorld();
  });

  test('level scaling: +2 levels doubles-triples damage', async () => {
    const lvlBefore = await levelOf('А');
    await gameActions.testAddLetter('А');
    await gameActions.testAddLetter('А');
    const base = await basePowerOf('А');
    const lvlAfter = await levelOf('А');
    expect(lvlAfter).toBeGreaterThanOrEqual(lvlBefore + 2);
    await gameActions.startTestCombat('TestScale', 300, ['Б']);
    await gameActions.waitForCombat();
    await gameActions.resetCombatLog();
    await gameActions.selectBattleCard('А');
    await gameActions.confirmBattleTurnExplicit();
    await godot.waitMs(1500); // resolve the turn (speed order: slow letters act late)
    const log = await gameActions.getCombatLogAll();
    const dmg = log.find((e) => e.event === 'damage' && e.letter === 'А');
    expect(dmg).toBeDefined();
    expect(dmg.damage).toBeGreaterThanOrEqual(base * lvlAfter); // scales with level
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
    await godot.waitMs(1500); // resolve the turn (speed order: slow letters act late)
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
