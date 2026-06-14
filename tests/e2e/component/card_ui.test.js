const godot = require('../helpers/godot_page');
const gameActions = require('../helpers/game_actions');

describe('Component Test: Card UI', () => {
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

  test('letter cards appear in inventory after acquiring letters', async () => {
    await gameActions.testAddLetter('А');
    await gameActions.testAddLetter('Б');
    await gameActions.testAddLetter('Ь');
    await gameActions.openInventory();
    const inv = await gameActions.getInventoryContents();
    expect(inv.letters).toBeDefined();
    expect(inv.letters['А']).toBeGreaterThanOrEqual(1); // А is the starter letter
    expect(inv.letters['Б']).toBe(1);
    expect(inv.letters['Ь']).toBe(1);
    await gameActions.closeInventory();
  });

  test('inventory reflects letter level after multiple copies', async () => {
    await gameActions.testAddLetter('А');
    await gameActions.testAddLetter('А'); // level 3 now (1 from previous test + 2)
    await gameActions.openInventory();
    const inv = await gameActions.getInventoryContents();
    expect(inv.letters['А']).toBeGreaterThanOrEqual(3);
    await gameActions.closeInventory();
  });

  test('alphabet data classifies each held letter with a valid type', async () => {
    const alphabet = await gameActions.getAlphabet();
    const inv = await gameActions.getInventoryContents();
    for (const letter of Object.keys(inv.letters || {})) {
      const data = alphabet.find((l) => l.char === letter);
      expect(data).toBeDefined();
      expect(['vowel', 'consonant', 'sign']).toContain(data.type);
    }
  });
});
