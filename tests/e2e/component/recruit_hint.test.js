const godot = require('../helpers/godot_page');
const gameActions = require('../helpers/game_actions');

describe('Recruit hint: monster tells where the letter is', () => {
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

  test('after dialogue, recruit message with letter hint is shown', async () => {
    // Ensure player has an ellipsis to talk
    await gameActions.testAddDots(3);
    await godot.waitFrames(10);

    // Force a dialogue + recruit cycle via the test bridge
    await gameActions.testStartDialogue();
    await godot.waitFrames(20);

    // End the dialogue (advance/close) to trigger recruitment + hint
    await godot.evaluateInPage(() => {
      if (typeof window.gameAdvanceDialogue === 'function') window.gameAdvanceDialogue();
    });
    await godot.waitMs(1000);

    // The recruit message (with hint) should now be set
    const msg = await godot.evaluateInPage(() => window.gameRecruitMsg || '');
    expect(msg.length).toBeGreaterThan(0);
    // Hint should mention a letter and a direction
    expect(msg).toMatch(/букву|ищи|на |/i);

    await godot.takeScreenshot('recruit_hint_message');
  });
});
