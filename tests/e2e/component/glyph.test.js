const godot = require('../helpers/godot_page');
const gameActions = require('../helpers/game_actions');

describe('G1: Letter glyph integration', () => {
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

  test('letter A card shows glyph in inventory', async () => {
    // Give player the letter А
    await gameActions.testAddLetter('А');
    await godot.waitFrames(20);

    // Open inventory — the LetterCard for А should render the glyph PNG
    await gameActions.openInventory();
    await godot.waitMs(500);

    const inv = await gameActions.getInventoryContents();
    expect(inv.letters).toHaveProperty('А');

    await godot.takeScreenshot('g1_glyph_A_inventory');
    await godot.takeCanvasScreenshot('g1_glyph_A_canvas');

    // Also start a combat to see the glyph on a battle card button area
    await gameActions.closeInventory();
    await gameActions.startTestCombat('GlyphShow', 60, ['Я']);
    await gameActions.waitForCombat(10000);
    await godot.waitMs(500);
    await godot.takeScreenshot('g1_glyph_A_combat');

    await gameActions.fleeBattle();
    await gameActions.waitForWorld();
  });
});
