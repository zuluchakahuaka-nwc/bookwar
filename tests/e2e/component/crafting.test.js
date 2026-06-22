const godot = require('../helpers/godot_page');
const gameActions = require('../helpers/game_actions');

describe('C1: Letter crafting', () => {
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

  test('successful transform: Б + Ь → П', async () => {
    // Give source Б and modifier Ь
    await gameActions.testAddLetter('Б');
    await gameActions.testAddLetter('Б');  // Б level 2
    await gameActions.testAddLetter('Ь');  // Ь level 1
    await godot.waitFrames(15);

    let inv = await gameActions.getInventoryContents();
    const beBefore = inv.letters['Б'] || 0;
    const modBefore = inv.letters['Ь'] || 0;
    expect(beBefore).toBeGreaterThanOrEqual(2);
    expect(modBefore).toBeGreaterThanOrEqual(1);
    expect((inv.letters['П'] || 0)).toBe(0);

    // Force success
    await godot.evaluateInPage(() => {
      if (typeof window.gameCraftForce === 'function') window.gameCraftForce(true);
    });
    await godot.waitFrames(5);

    // Craft Б + Ь
    await godot.evaluateInPage((s, m) => {
      if (typeof window.gameCraft === 'function') window.gameCraft(s, m);
    }, 'Б', 'Ь');
    await godot.waitFrames(20);

    const result = await godot.evaluateInPage(() => window.gameCraftResult || null);
    expect(result).toBeTruthy();
    expect(result.success).toBe(true);
    expect(result.target).toBe('П');

    inv = await gameActions.getInventoryContents();
    // Ь modifier consumed
    expect((inv.letters['Ь'] || 0)).toBe(modBefore - 1);
    // П gained
    expect((inv.letters['П'] || 0)).toBeGreaterThanOrEqual(1);
  });

  test('failed transform: modifier lost, no target', async () => {
    await gameActions.testAddLetter('М');
    await gameActions.testAddLetter('Ь');
    await godot.waitFrames(15);

    let inv = await gameActions.getInventoryContents();
    const modBefore = inv.letters['Ь'] || 0;

    // Force failure
    await godot.evaluateInPage(() => {
      if (typeof window.gameCraftForce === 'function') window.gameCraftForce(false);
    });
    await godot.waitFrames(5);

    await godot.evaluateInPage((s, m) => {
      if (typeof window.gameCraft === 'function') window.gameCraft(s, m);
    }, 'М', 'Ь');
    await godot.waitFrames(20);

    const result = await godot.evaluateInPage(() => window.gameCraftResult || null);
    expect(result).toBeTruthy();
    expect(result.success).toBe(false);

    inv = await gameActions.getInventoryContents();
    // Ь consumed even on failure, Н NOT gained
    expect((inv.letters['Ь'] || 0)).toBe(modBefore - 1);
    expect((inv.letters['Н'] || 0)).toBe(0);

    // Reset craft force to random
    await godot.evaluateInPage(() => {
      if (typeof window.gameCraftForce === 'function') window.gameCraftForce(-1);
    });
  });

  test('crafting UI opens in inventory and shows section', async () => {
    await gameActions.openInventory();
    await godot.waitMs(400);
    await godot.takeScreenshot('c1_craft_inventory');
    await gameActions.closeInventory();
  });
});
