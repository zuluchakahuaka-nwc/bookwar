const godot = require('../helpers/godot_page');
const gameActions = require('../helpers/game_actions');

describe('Regression: Data Integrity', () => {
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

  test('alphabet bridge exposes exactly 33 letters', async () => {
    const alphabet = await gameActions.getAlphabet();
    expect(Array.isArray(alphabet)).toBe(true);
    expect(alphabet.length).toBe(33);
  });

  test('letter А is position 1, base_power 1, speed 1, vowel attack (§20 inverted)', async () => {
    const alphabet = await gameActions.getAlphabet();
    const a = alphabet.find((l) => l.char === 'А');
    expect(a).toBeDefined();
    expect(a.position).toBe(1);
    expect(a.base_power).toBe(1);  // §20: base_power = position (was 33 pre-inversion)
    expect(a.speed).toBe(1);
    expect(a.type).toBe('vowel');
    expect(a.role).toBe('attack');
  });

  test('letter Я is position 33, base_power 33, speed 33 (strongest)', async () => {
    const alphabet = await gameActions.getAlphabet();
    const ya = alphabet.find((l) => l.char === 'Я');
    expect(ya).toBeDefined();
    expect(ya.position).toBe(33);
    expect(ya.base_power).toBe(33);  // §20: base_power = position (was 1 pre-inversion)
    expect(ya.speed).toBe(33);
  });

  test('§20: base_power == position and speed == position for every letter', async () => {
    const alphabet = await gameActions.getAlphabet();
    for (const l of alphabet) {
      expect(l.base_power).toBe(l.position);  // §20 inverted
      expect(l.speed).toBe(l.position);
    }
  });

  test('type distribution: 10 vowels, 21 consonants, 2 signs (Ъ defense, Ь attack)', async () => {
    const alphabet = await gameActions.getAlphabet();
    const vowels = alphabet.filter((l) => l.type === 'vowel');
    const consonants = alphabet.filter((l) => l.type === 'consonant');
    const signs = alphabet.filter((l) => l.type === 'sign');
    expect(vowels.length).toBe(10);
    expect(consonants.length).toBe(21);
    expect(signs.length).toBe(2);
    const hard = alphabet.find((l) => l.char === 'Ъ');
    const soft = alphabet.find((l) => l.char === 'Ь');
    expect(hard.role).toBe('defense_buff');
    expect(soft.role).toBe('attack_buff');
  });

  test('inventory starts with the starter letter А (player can fight from spawn)', async () => {
    const inv = await gameActions.getInventoryContents();
    // Per gameplay fix: А auto-collected on spawn so the player always has a weapon.
    expect(inv.letters['А']).toBeGreaterThanOrEqual(1);
    expect(typeof inv.dots).toBe('number');
    expect(inv.dots).toBeGreaterThanOrEqual(0);
  });
});
