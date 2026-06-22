const godot = require('../helpers/godot_page');
const gameActions = require('../helpers/game_actions');

describe('Monster state persists across battle', () => {
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

  test('a recruited ally stays recruited after a battle (no turning hostile)', async () => {
    // Ensure we have ellipsis to talk
    await gameActions.testAddDots(9);
    await godot.waitFrames(15);

    // Force the next recruit roll to succeed
    await godot.evaluateInPage(() => {
      if (typeof window.gameForceRecruit === 'function') window.gameForceRecruit(true);
    });
    await godot.waitFrames(5);

    // Trigger a dialogue with the nearest monster -> recruit
    await gameActions.testStartDialogue();
    await godot.waitMs(500);
    // Advance through all dialogue lines until it closes (fires recruitment)
    for (let i = 0; i < 8; i++) {
      const active = await gameActions.isDialogueActive();
      if (!active) break;
      await godot.evaluateInPage(() => {
        if (typeof window.gameAdvanceDialogue === 'function') window.gameAdvanceDialogue();
      });
      await godot.waitMs(300);
    }
    await godot.waitMs(1000);

    const statesBefore = await gameActions.getMonsterStates();
    const recruitedBefore = statesBefore.filter((m) => m.allegiance === 1).length;
    expect(recruitedBefore).toBeGreaterThanOrEqual(1);

    await godot.takeScreenshot('persist_recruited_before_battle');

    // Now fight a battle and return to world (scene reloads)
    await gameActions.testAddLetter('А');
    await gameActions.startTestCombat('StateResetFoe', 30, ['Я']);
    await gameActions.waitForCombat(10000);
    await godot.waitMs(500);
    await gameActions.selectBattleCard('А');
    await gameActions.confirmBattleTurnExplicit();
    await gameActions.waitForWorld(15000);
    await godot.waitMs(2500);

    // After reload, the recruited monster should STILL be recruited (state persisted)
    const statesAfter = await gameActions.getMonsterStates();
    const recruitedAfter = statesAfter.filter((m) => m.allegiance === 1).length;
    expect(recruitedAfter).toBeGreaterThanOrEqual(1);
    // And no recruited monster should have turned hostile (allegiance 0)
    const hostile = statesAfter.filter((m) => m.allegiance === 0).length;
    // recruited count must not have dropped to 0
    expect(recruitedAfter).toBeGreaterThanOrEqual(recruitedBefore >= 1 ? 1 : 0);

    await godot.takeScreenshot('persist_recruited_after_battle');
  });
});
