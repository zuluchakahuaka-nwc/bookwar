// Recruiting a "?" must cost exactly 3 буквицы (one speech), not 3 per dialogue line.
const godot = require('../helpers/godot_page');
const gameActions = require('../helpers/game_actions');

async function bukvitsy() {
  const inv = await gameActions.getInventoryContents();
  return inv.dots;
}

describe('Recruit cost = exactly 3 буквицы', () => {
  jest.setTimeout(120000);
  beforeAll(async () => { await godot.loadGame(); await gameActions.waitForGameLoad(); await gameActions.startNewGame(); await godot.waitMs(2500); });
  afterAll(async () => { await godot.closeBrowser(); });

  test('one recruit consumes exactly 3 буквицы regardless of dialogue length', async () => {
    // Give exactly 6 буквицы
    await gameActions.testAddDots(6);
    await godot.waitFrames(10);
    const before = await bukvitsy();
    expect(before).toBe(6);

    // Force recruit + run through ALL dialogue lines of a "?" (multi-line)
    await godot.evaluateInPage(() => { if (typeof window.gameForceRecruit === 'function') window.gameForceRecruit(true); });
    await godot.waitFrames(5);
    await gameActions.testStartDialogue();
    await godot.waitMs(400);
    // Advance through every line until the dialogue closes
    for (let i = 0; i < 10; i++) {
      const active = await gameActions.isDialogueActive();
      if (!active) break;
      await godot.evaluateInPage(() => { if (typeof window.gameAdvanceDialogue === 'function') window.gameAdvanceDialogue(); });
      await godot.waitMs(220);
    }
    await godot.waitMs(800);

    const after = await bukvitsy();
    console.log('bukvitsy before/after:', before, after, 'spent:', before - after);
    expect(before - after).toBe(3); // exactly one speech (3 буквицы), not 3 per line
  });
});
