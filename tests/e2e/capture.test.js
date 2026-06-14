const godot = require('./helpers/godot_page');
const gameActions = require('./helpers/game_actions');

// Capture screenshots of every key game state for Vision-MCP analysis.
describe('Screenshot Capture', () => {
  jest.setTimeout(120000);

  beforeAll(async () => {
    await godot.loadGame();
    await gameActions.waitForGameLoad();
  });

  afterAll(async () => {
    await godot.closeBrowser();
  });

  test('01_main_menu', async () => {
    await godot.takeScreenshot('01_main_menu');
    await godot.takeCanvasScreenshot('01_main_menu');
  });

  test('02_world_spawn', async () => {
    await gameActions.startNewGame();
    await godot.waitMs(3000);
    await godot.takeScreenshot('02_world_spawn');
    await godot.takeCanvasScreenshot('02_world_spawn');
  });

  test('03_world_with_letters', async () => {
    // give a few letters so inventory has content
    await gameActions.testAddLetter('А');
    await gameActions.testAddLetter('Б');
    await gameActions.testAddLetter('О');
    await gameActions.testAddLetter('Ь');
    await gameActions.testAddLetter('А'); // level 2
    await godot.waitFrames(15);
    await godot.takeCanvasScreenshot('03_world_with_letters');
  });

  test('04_inventory_cards', async () => {
    await gameActions.openInventory();
    await godot.waitMs(800);
    await godot.takeScreenshot('04_inventory_cards');
    await godot.takeCanvasScreenshot('04_inventory_cards');
    await gameActions.closeInventory();
  });

  test('05_dialogue', async () => {
    await gameActions.testAddDots(3);
    await godot.waitFrames(10);
    await gameActions.testStartDialogue();
    await godot.waitFrames(20);
    await godot.takeScreenshot('05_dialogue');
    await godot.takeCanvasScreenshot('05_dialogue');
  });

  test('06_combat', async () => {
    await gameActions.startTestCombat('TestFoe', 100, ['Б']);
    await gameActions.waitForCombat();
    await godot.waitMs(800);
    await godot.takeScreenshot('06_combat');
    await godot.takeCanvasScreenshot('06_combat');
  });

  test('07_combat_played', async () => {
    await gameActions.selectBattleCard('А');
    await godot.waitMs(500);
    await godot.takeCanvasScreenshot('07_combat_played');
    await gameActions.fleeBattle();
    await gameActions.waitForWorld();
  });
});
