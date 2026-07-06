// Verify recruit-fail shows the explicit "не подкупился" notification.
const godot = require('./helpers/godot_page');
const game = require('./helpers/game_actions');

describe('Recruit fail notification', () => {
  jest.setTimeout(120000);
  beforeAll(async () => { await godot.loadGame(); await game.waitForGameLoad(); });
  afterAll(async () => { await godot.closeBrowser(); });

  test('failed recruit shows on-screen notice', async () => {
    await game.startNewGame();
    await godot.waitMs(2000);
    await game.testAddDots(3);
    await godot.waitFrames(10);
    // Force the NEXT recruit roll to FAIL
    await godot.evaluateInPage(() => { if (typeof window.gameForceRecruit === 'function') window.gameForceRecruit(false); });
    // Start dialogue with nearest ?-monster, then advance through all lines to close it
    await game.testStartDialogue();
    await godot.waitFrames(20);
    for (let i = 0; i < 6; i++) {
      await godot.evaluateInPage(() => { if (typeof window.gameAdvanceDialogue === 'function') window.gameAdvanceDialogue(); });
      await godot.waitMs(300);
    }
    await godot.waitMs(1200);
    const msg = await godot.evaluateInPage(() => window.gameRecruitMsg || '');
    console.log('RECRUIT MSG:', JSON.stringify(msg));
    const ok = /ПРОВАЛ|не подкупился|потрачены/i.test(msg);
    expect(ok).toBe(true);
    await godot.takeScreenshot('recruit_fail_notice');
  });
});
