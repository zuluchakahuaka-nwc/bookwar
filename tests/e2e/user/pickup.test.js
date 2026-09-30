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
    // Deterministic: walk to the NEAREST uncollected dot (auto-pickup grabs
    // items the player touches; E-interact covers the standing-next-to case).
    const target = await godot.getPage().evaluate(() => {
      const p = window.gamePlayerPos;
      if (!p) return null;
      const dots = (window.gameItemPositions || []).filter(i => (i.t || '') !== 'letter');
      if (!dots.length) return null;
      const withD = dots.map(i => ({ ...i, d: Math.hypot(i.x - p.x, i.y - p.y) }));
      withD.sort((a, b) => a.d - b.d);
      return { x: withD[0].x, y: withD[0].y, d: Math.round(withD[0].d) };
    });
    expect(target).not.toBeNull();
    await gameActions.movePlayerTo(target.x, target.y);
    await gameActions.interact();
    await godot.waitFrames(10);
    const newInv = await gameActions.getInventoryContents();
    const newDots = newInv.dots;
    const newEllipsis = (newInv.punctuation && newInv.punctuation['...']) || 0;
    const changed = newDots !== initialDots || newEllipsis !== initialEllipsis;
    if (!changed) await godot.takeScreenshot('pickup_walk_failed');
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
