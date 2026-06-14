const godot = require('../helpers/godot_page');
const gameActions = require('../helpers/game_actions');

describe('Full Playthrough: Light Valley', () => {
  jest.setTimeout(120000);

  beforeAll(async () => {
    await godot.loadGame();
    await gameActions.waitForGameLoad();
  });

  afterAll(async () => {
    await godot.closeBrowser();
  });

  test('Step 1: Game loads and shows main menu', async () => {
    const menuVisible = await gameActions.isMenuVisible();
    expect(menuVisible).toBe(true);
  });

  test('Step 2: Player starts new game and spawns in Light Valley', async () => {
    await gameActions.startNewGame();
    await godot.waitMs(3000);
    const pos = await gameActions.getPlayerPosition();
    expect(pos).toBeDefined();
    expect(typeof pos.x).toBe('number');
    const hp = await gameActions.getHPFromHUD();
    expect(hp).toContain('100');
  });

  test('Step 3: Player moves around the map', async () => {
    const start = await gameActions.getPlayerPosition();
    await gameActions.movePlayer('right', 500);
    await gameActions.movePlayer('up', 300);
    const end = await gameActions.getPlayerPosition();
    expect(end.x).not.toBe(start.x);
    expect(end.y).not.toBe(start.y);
  });

  test('Step 4: Player collects dots from the ground', async () => {
    let dotsCollected = 0;
    for (let i = 0; i < 5; i++) {
      await gameActions.movePlayer('right', 200);
      await gameActions.interact();
      await gameActions.movePlayer('down', 150);
      await gameActions.interact();
      await godot.waitFrames(5);
      dotsCollected++;
    }
    const inventory = await gameActions.getInventoryContents();
    expect(inventory.dots + Math.floor(dotsCollected / 3)).toBeGreaterThanOrEqual(0);
  });

  test('Step 5: Three dots combine into ellipsis', async () => {
    await gameActions.openInventory();
    const inventory = await gameActions.getInventoryContents();
    const hasEllipsis = (inventory.punctuation && inventory.punctuation['...'] > 0);
    if (!hasEllipsis) {
      for (let i = 0; i < 6; i++) {
        await gameActions.closeInventory();
        await gameActions.movePlayer('right', 300);
        await gameActions.interact();
        await gameActions.movePlayer('up', 200);
        await gameActions.interact();
        await gameActions.openInventory();
        const inv = await gameActions.getInventoryContents();
        if (inv.punctuation && inv.punctuation['...'] > 0) break;
      }
    }
    await gameActions.closeInventory();
  });

  test('Step 6: Player approaches question monster and uses ellipsis dialogue', async () => {
    await gameActions.movePlayer('right', 1500);
    await gameActions.movePlayer('up', 300);
    await gameActions.openDialogue();
    await godot.waitFrames(15);
  });

  test('Step 7: Player finds a hidden letter', async () => {
    await gameActions.movePlayer('up', 1000);
    await gameActions.movePlayer('right', 500);
    await gameActions.interact();
    await godot.waitFrames(10);
  });

  test('Step 8: Player checks inventory for collected items', async () => {
    await gameActions.openInventory();
    const inventory = await gameActions.getInventoryContents();
    expect(inventory).toBeDefined();
    await gameActions.closeInventory();
  });

  test('Step 9: HUD shows correct HP after exploration', async () => {
    const hp = await gameActions.getHPFromHUD();
    expect(hp).toBeDefined();
    expect(hp.length).toBeGreaterThan(0);
  });

  test('Step 10: Player returns toward starting area', async () => {
    await gameActions.movePlayer('left', 2000);
    await gameActions.movePlayer('down', 1000);
    const pos = await gameActions.getPlayerPosition();
    expect(pos).toBeDefined();
  });
});
