const godot = require('../helpers/godot_page');
const gameActions = require('../helpers/game_actions');

describe('User Test: Item Pickup', () => {
  beforeAll(async () => {
    await godot.loadGame();
    await gameActions.waitForGameLoad();
    await gameActions.startNewGame();
    await godot.waitMs(2000);
  });

  afterAll(async () => {
    await godot.closeBrowser();
  });

  test('player walks to a dot and picks it up', async () => {
    const initialInv = await gameActions.getInventoryContents();
    const initialDots = initialInv.dots;
    const initialEllipsis = (initialInv.punctuation && initialInv.punctuation['...']) || 0;
    await gameActions.movePlayer('right', 800);
    await gameActions.interact();
    await godot.waitFrames(10);
    const newInv = await gameActions.getInventoryContents();
    const newDots = newInv.dots;
    const newEllipsis = (newInv.punctuation && newInv.punctuation['...']) || 0;
    const changed = newDots !== initialDots || newEllipsis !== initialEllipsis;
    expect(changed).toBe(true);
  });

  test('dot appears in inventory after pickup', async () => {
    await gameActions.openInventory();
    const inventory = await gameActions.getInventoryContents();
    const hasDotsOrEllipsis = inventory.dots > 0 || (inventory.punctuation && inventory.punctuation['...'] > 0);
    expect(hasDotsOrEllipsis).toBe(true);
    await gameActions.closeInventory();
  });
});
