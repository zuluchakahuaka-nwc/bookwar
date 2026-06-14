const godot = require('../helpers/godot_page');
const gameActions = require('../helpers/game_actions');

describe('User Test: Dialogue System', () => {
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

  test('three dots combine into an ellipsis (.... -> ...)', async () => {
    await gameActions.testAddDots(3);
    await godot.waitFrames(10);
    const inv = await gameActions.getInventoryContents();
    const hasEllipsis = (inv.punctuation && inv.punctuation['...'] > 0);
    expect(hasEllipsis).toBe(true);
  });

  test('player opens dialogue with a monster via ellipsis', async () => {
    await gameActions.testStartDialogue();
    await godot.waitFrames(15);
    const active = await gameActions.isDialogueActive();
    expect(active).toBe(true);
  });

  test('dialogue shows non-empty text from the monster', async () => {
    const text = await gameActions.getDialogueText();
    expect(text.length).toBeGreaterThan(0);
  });
});
