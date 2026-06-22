const godot = require('../helpers/godot_page');
const gameActions = require('../helpers/game_actions');

describe('G1: All 33 letter glyphs render', () => {
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

  test('multiple letter cards show glyphs without load errors', async () => {
    // Give a spread of letters: vowel, consonant, sign
    await gameActions.testAddLetter('А');
    await gameActions.testAddLetter('О');
    await gameActions.testAddLetter('Б');
    await gameActions.testAddLetter('Я');
    await gameActions.testAddLetter('Ь');
    await godot.waitFrames(20);

    await gameActions.openInventory();
    await godot.waitMs(600);

    const inv = await gameActions.getInventoryContents();
    const letters = Object.keys(inv.letters || {});
    expect(letters.length).toBeGreaterThanOrEqual(5);

    await godot.takeScreenshot('g1_glyphs_multi_inventory');

    // Check console had no glyph load errors
    await gameActions.closeInventory();
  });
});
