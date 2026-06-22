const godot = require('../helpers/godot_page');
const gameActions = require('../helpers/game_actions');

describe('Combat: each letter once PER BATTLE', () => {
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

  test('same letter not replayable in same turn; different letters OK', async () => {
    await gameActions.testAddLetter('А');
    await gameActions.testAddLetter('Б');
    await gameActions.startTestCombat('OncePerBattle', 999, ['Я']);
    await gameActions.waitForCombat(10000);
    await godot.waitMs(500);

    await gameActions.resetCombatLog();
    await gameActions.selectBattleCard('А');
    await godot.waitFrames(8);
    let st = await gameActions.getCombatState();
    expect(st.played_letters).toContain('А');

    // Same А again in same turn → rejected (played_letters unchanged)
    await gameActions.selectBattleCard('А');
    await godot.waitFrames(8);
    st = await gameActions.getCombatState();
    expect(st.played_letters).toEqual(['А']);

    const log = await gameActions.getCombatLogAll();
    const rejected = log.find((e) => e.event === 'play_card_fail' && e.reason === 'already_played_this_battle');
    expect(rejected).toBeDefined();

    // Different letter Б allowed
    await gameActions.selectBattleCard('Б');
    await godot.waitFrames(8);
    st = await gameActions.getCombatState();
    expect(st.played_letters).toEqual(['А', 'Б']);

    await gameActions.fleeBattle();
    await gameActions.waitForWorld();
  });

  test('used letter stays unavailable in the NEXT turn of the same battle', async () => {
    await gameActions.startTestCombat('RationFoe', 999, ['Я']);
    await gameActions.waitForCombat(10000);
    await godot.waitMs(500);

    // Turn 1: play А and resolve
    await gameActions.selectBattleCard('А');
    await gameActions.confirmBattleTurnExplicit();
    await godot.waitMs(1000);

    let st = await gameActions.getCombatState();
    expect(st.played_letters).toContain('А');

    // Turn 2: А must STILL be unavailable
    await gameActions.resetCombatLog();
    await gameActions.selectBattleCard('А');
    await godot.waitFrames(8);
    st = await gameActions.getCombatState();
    expect(st.played_letters).toEqual(['А']); // unchanged

    const log = await gameActions.getCombatLogAll();
    const rejected = log.find((e) => e.event === 'play_card_fail' && e.reason === 'already_played_this_battle');
    expect(rejected).toBeDefined();

    await gameActions.fleeBattle();
    await gameActions.waitForWorld();
  });

  test('a NEW battle resets letter usage', async () => {
    await gameActions.startTestCombat('FreshBattle', 999, ['Я']);
    await gameActions.waitForCombat(10000);
    await godot.waitMs(500);

    // In a brand-new battle, played_letters is empty and А is playable
    let st = await gameActions.getCombatState();
    expect(st.played_letters).toEqual([]);

    await gameActions.selectBattleCard('А');
    await godot.waitFrames(8);
    st = await gameActions.getCombatState();
    expect(st.played_letters).toContain('А');

    await gameActions.fleeBattle();
    await gameActions.waitForWorld();
  });
});
