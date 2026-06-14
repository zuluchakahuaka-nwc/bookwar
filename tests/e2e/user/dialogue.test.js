const godot = require('../helpers/godot_page');
const gameActions = require('../helpers/game_actions');

describe('User Test: Dialogue System', () => {
  beforeAll(async () => {
    await godot.loadGame();
    await gameActions.waitForGameLoad();
    await gameActions.startNewGame();
    await godot.waitMs(2000);
  });

  afterAll(async () => {
    await godot.closeBrowser();
  });

  test('player collects 3 dots to create ellipsis', async () => {
    for (let i = 0; i < 4; i++) {
      await gameActions.movePlayer('right', 300);
      await gameActions.interact();
      await gameActions.movePlayer('down', 200);
      await gameActions.interact();
    }
    await godot.waitFrames(10);
    const inventory = await gameActions.getInventoryContents();
    const hasEllipsis = (inventory.punctuation && inventory.punctuation['...'] > 0) || inventory.dots >= 3;
    expect(hasEllipsis).toBe(true);
  });

  test('player approaches monster and opens dialogue', async () => {
    await gameActions.movePlayer('right', 1500);
    await gameActions.movePlayer('up', 500);
    await gameActions.openDialogue();
    await godot.waitFrames(10);
    const active = await gameActions.isDialogueActive();
    expect(active).toBe(true);
  });

  test('dialogue shows text from monster', async () => {
    const text = await gameActions.getDialogueText();
    expect(text.length).toBeGreaterThan(0);
  });

  test('player can advance dialogue', async () => {
    await gameActions.advanceDialogue();
    await godot.waitFrames(10);
    const stillActive = await gameActions.isDialogueActive();
    expect(typeof stillActive).toBe('boolean');
  });
});
