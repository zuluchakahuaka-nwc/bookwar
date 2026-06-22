const godot = require('../helpers/godot_page');
const gameActions = require('../helpers/game_actions');

describe('L1: Intro legend slideshow', () => {
  jest.setTimeout(120000);

  beforeAll(async () => {
    await godot.loadGame();
    await gameActions.waitForGameLoad();
  });

  afterAll(async () => {
    await godot.closeBrowser();
  });

  test('intro plays 7 scenes and advances to world', async () => {
    // Launch intro from main menu via JS hook
    await godot.evaluateInPage(() => {
      if (typeof window.gameClickLegend === 'function') window.gameClickLegend();
    });
    await godot.waitMs(1500);

    // Should be in intro
    let introActive = await godot.evaluateInPage(() => !!window.gameIntroActive);
    expect(introActive).toBe(true);

    let idx = await godot.evaluateInPage(() => window.gameIntroIndex || 0);
    expect(idx).toBe(0);
    await godot.takeScreenshot('l1_intro_scene1');

    // Advance through panels 1..6 via JS bridge (avoids pressKey's canvas click double-advance)
    for (let i = 0; i < 6; i++) {
      await godot.evaluateInPage(() => {
        if (typeof window.gameAdvanceIntro === 'function') window.gameAdvanceIntro();
      });
      await godot.waitMs(500);
      idx = await godot.evaluateInPage(() => window.gameIntroIndex || 0);
      expect(idx).toBe(i + 1);
    }
    await godot.takeScreenshot('l1_intro_scene7');

    // Final advance → transition to world
    await godot.evaluateInPage(() => {
      if (typeof window.gameAdvanceIntro === 'function') window.gameAdvanceIntro();
    });
    await godot.waitMs(2500);

    // Intro should be done and we should be in the world (not menu)
    introActive = await godot.evaluateInPage(() => !!window.gameIntroActive);
    expect(introActive).toBe(false);
    const menuVisible = await gameActions.isMenuVisible();
    expect(menuVisible).toBe(false);
  });
});
