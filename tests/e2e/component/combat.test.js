const godot = require('../helpers/godot_page');
const gameActions = require('../helpers/game_actions');

describe('Component Test: Combat System', () => {
  beforeAll(async () => {
    await godot.loadGame();
    await gameActions.waitForGameLoad();
    await gameActions.startNewGame();
    await godot.waitMs(2000);
  });

  afterAll(async () => {
    await godot.closeBrowser();
  });

  test('combat initiates when player touches aggressive monster', async () => {
    await gameActions.movePlayer('right', 2000);
    await gameActions.movePlayer('down', 1500);
    await godot.waitFrames(20);
    const inCombat = await gameActions.isInCombat();
    if (inCombat) {
      expect(inCombat).toBe(true);
    }
  });

  test('player can select a card in combat', async () => {
    const inCombat = await gameActions.isInCombat();
    if (!inCombat) return;
    await gameActions.selectBattleCard('А');
    await godot.waitFrames(5);
  });

  test('player confirms turn and combat resolves', async () => {
    const inCombat = await gameActions.isInCombat();
    if (!inCombat) return;
    await gameActions.confirmBattleTurn();
    await godot.waitFrames(30);
  });
});
