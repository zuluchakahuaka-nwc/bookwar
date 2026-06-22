const godot = require('../helpers/godot_page');
const gameActions = require('../helpers/game_actions');

async function openCharSelect() {
  await godot.clickButton('Новая игра');
  await godot.waitForCondition(async () => {
    return await godot.evaluateInPage(() => !!(window.gameCharSelectLoaded));
  }, 10000);
  await godot.waitFrames(10);
}

describe('Vision: Hero In-Game Screenshots', () => {
  afterEach(async () => {
    await godot.closeBrowser();
  });

  test('hero 7 (Огнеслав) — char select + in game', async () => {
    await godot.loadGame();
    await gameActions.waitForGameLoad();
    await openCharSelect();
    await gameActions.selectHeroByIndex(7);
    await godot.waitFrames(20);
    const ss1 = await godot.takeScreenshot('vision_hero7_select');
    console.log('Char select screenshot:', ss1);

    await gameActions.confirmHero();
    await godot.waitMs(4000);
    const ss2 = await godot.takeScreenshot('vision_hero7_ingame');
    console.log('In-game screenshot:', ss2);

    expect(ss2).toBeTruthy();
  }, 60000);

  test('hero 40 (Ъдеслав) — in game', async () => {
    await godot.loadGame();
    await gameActions.waitForGameLoad();
    await openCharSelect();
    await gameActions.selectHeroByIndex(40);
    await godot.waitFrames(20);
    const ss1 = await godot.takeScreenshot('vision_hero40_select');
    console.log('Char select screenshot:', ss1);

    await gameActions.confirmHero();
    await godot.waitMs(4000);
    const ss2 = await godot.takeScreenshot('vision_hero40_ingame');
    console.log('In-game screenshot:', ss2);

    expect(ss2).toBeTruthy();
  }, 60000);
});
