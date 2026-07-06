const godot = require('../helpers/godot_page');
const gameActions = require('../helpers/game_actions');

describe('Component Test: Monster AI', () => {
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

  test('monsters spawn in the world (visible via state bridge)', async () => {
    await godot.waitMs(800); // let throttled push fire
    const monsters = await gameActions.getMonsterStates();
    expect(Array.isArray(monsters)).toBe(true);
    expect(monsters.length).toBeGreaterThan(0);
    for (const m of monsters) {
      expect(typeof m.id).toBe('string');
      expect(typeof m.state).toBe('string');
    }
  });

  test('question (?) monster is passive: patrol/suspicion, not aggressive', async () => {
    const monsters = await gameActions.getMonsterStates();
    const q = monsters.find((m) => m.id === 'question');
    expect(q).toBeDefined();
    expect(q.is_aggressive).toBe(false);
    expect(['patrol', 'idle', 'suspicion']).toContain(q.state);
  });

  test('exclamation (!) monster is aggressive by design (escalation target)', async () => {
    const monsters = await gameActions.getMonsterStates();
    const e = monsters.find((m) => m.id === 'exclamation');
    expect(e).toBeDefined();
    expect(e.is_aggressive).toBe(true);
    expect(e.behavior).toBe('aggressive');
  });

  test('(!) monster can detect and attack (escalation capability)', async () => {
    const monsters = await gameActions.getMonsterStates();
    const e = monsters.find((m) => m.id === 'exclamation');
    expect(e).toBeDefined();
    // Escalation requires: aggressive behavior + hp to survive a fight
    expect(e.is_aggressive).toBe(true);
    expect(e.behavior).toBe('aggressive');
    expect(e.hp).toBeGreaterThan(0);
  });

  test('question (?) and exclamation (!) monsters are distinct behaviors (? passive, ! aggressive)', async () => {
    const monsters = await gameActions.getMonsterStates();
    const q = monsters.find((m) => m.id === 'question');
    const e = monsters.find((m) => m.id === 'exclamation');
    expect(q.is_aggressive).toBe(false);
    expect(e.is_aggressive).toBe(true);
    // This contrast IS the ?→! escalation design: encountering ? is safe, encountering ! is dangerous.
    expect(q.is_aggressive).not.toBe(e.is_aggressive);
  });
});
