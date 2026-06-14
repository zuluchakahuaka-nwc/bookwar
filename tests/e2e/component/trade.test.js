const godot = require('../helpers/godot_page');
const gameActions = require('../helpers/game_actions');

describe('Component Test: Trade with NPC', () => {
  beforeAll(async () => {
    await godot.loadGame();
    await gameActions.waitForGameLoad();
    await gameActions.startNewGame();
    await godot.waitMs(2000);
  });

  afterAll(async () => {
    await godot.closeBrowser();
  });

  test('player can approach NPC and initiate dialogue', async () => {
    await gameActions.movePlayer('up', 500);
    await gameActions.movePlayer('left', 300);
    await gameActions.openDialogue();
    await godot.waitFrames(10);
  });
});
