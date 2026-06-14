const godot = require('../helpers/godot_page');
const gameActions = require('../helpers/game_actions');

describe('User Test: Player Movement', () => {
  beforeAll(async () => {
    await godot.loadGame();
    await gameActions.waitForGameLoad();
    await gameActions.startNewGame();
    await godot.waitMs(2000);
  });

  afterAll(async () => {
    await godot.closeBrowser();
  });

  test('player moves right when D is held', async () => {
    const startPos = await gameActions.getPlayerPosition();
    await gameActions.movePlayer('right', 500);
    const endPos = await gameActions.getPlayerPosition();
    expect(endPos.x).toBeGreaterThan(startPos.x);
  });

  test('player moves left when A is held', async () => {
    const startPos = await gameActions.getPlayerPosition();
    await gameActions.movePlayer('left', 500);
    const endPos = await gameActions.getPlayerPosition();
    expect(endPos.x).toBeLessThan(startPos.x);
  });

  test('player moves up when W is held', async () => {
    const startPos = await gameActions.getPlayerPosition();
    await gameActions.movePlayer('up', 500);
    const endPos = await gameActions.getPlayerPosition();
    expect(endPos.y).toBeLessThan(startPos.y);
  });

  test('player moves down when S is held', async () => {
    const startPos = await gameActions.getPlayerPosition();
    await gameActions.movePlayer('down', 500);
    const endPos = await gameActions.getPlayerPosition();
    expect(endPos.y).toBeGreaterThan(startPos.y);
  });

  test('player does not move with no input', async () => {
    const startPos = await gameActions.getPlayerPosition();
    await godot.waitMs(500);
    const endPos = await gameActions.getPlayerPosition();
    expect(Math.abs(endPos.x - startPos.x)).toBeLessThan(5);
    expect(Math.abs(endPos.y - startPos.y)).toBeLessThan(5);
  });
});
