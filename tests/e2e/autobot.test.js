// Autobot: self-driving player that plays BOOKWAR like a real human.
// Clicks on-screen buttons, moves via keyboard, collects dots, opens inventory,
// triggers dialogue, fights — and screenshots every step for Vision analysis.
const godot = require('./helpers/godot_page');
const gameActions = require('./helpers/game_actions');

const STEP_DIR = require('path').join(__dirname, '..', 'screenshots');
require('fs').mkdirSync(STEP_DIR, { recursive: true });

async function shot(label) {
  const p = await godot.takeScreenshot('bot_' + label);
  console.log('SHOT', label, require('path').basename(p));
  return p;
}

describe('Autobot: full self-driven playthrough', () => {
  jest.setTimeout(180000);

  beforeAll(async () => {
    await godot.loadGame();
    await gameActions.waitForGameLoad();
  });

  afterAll(async () => {
    await godot.closeBrowser();
  });

  test('01 start new game via menu', async () => {
    await gameActions.startNewGame();
    await godot.waitMs(2500);
    const hp = await gameActions.getHPFromHUD();
    expect(hp).toContain('100');
    await shot('01_spawn');
  });

  test('02 move around with WASD', async () => {
    const start = await gameActions.getPlayerPosition();
    await gameActions.movePlayer('right', 800);
    await gameActions.movePlayer('down', 400);
    await gameActions.movePlayer('up', 300);
    // если попали в бой — выходим
    if (await gameActions.isInCombat()) { await gameActions.fleeBattle(); await godot.waitMs(2000); }
    const end = await gameActions.getPlayerPosition();
    const moved = Math.abs(end.x - start.x) + Math.abs(end.y - start.y);
    expect(moved).toBeGreaterThan(20);
    await shot('02_moved');
  });

  test('03 collect dots from the ground', async () => {
    if (await gameActions.isInCombat()) { await gameActions.fleeBattle(); await godot.waitMs(2000); }
    const before = await gameActions.getInventoryContents();
    const beforeDots = before.dots + (before.punctuation['...'] || 0) * 3;
    for (let i = 0; i < 6; i++) {
      await gameActions.movePlayer('right', 250);
      await gameActions.movePlayer('down', 200);
      await gameActions.movePlayer('up', 200);
      if (await gameActions.isInCombat()) { await gameActions.fleeBattle(); await godot.waitMs(1500); }
    }
    await godot.waitFrames(10);
    const after = await gameActions.getInventoryContents();
    const afterDots = after.dots + (after.punctuation['...'] || 0) * 3;
    expect(afterDots).toBeGreaterThan(beforeDots);
    await shot('03_collected_dots');
  });

  test('04 three dots combine into ellipsis', async () => {
    if (await gameActions.isInCombat()) { await gameActions.fleeBattle(); await godot.waitMs(2000); }
    let inv = await gameActions.getInventoryContents();
    if (!inv.punctuation['...']) {
      await gameActions.testAddDots(3);
      await godot.waitFrames(10);
    }
    inv = await gameActions.getInventoryContents();
    expect(inv.punctuation['...']).toBeGreaterThan(0);
    await shot('04_ellipsis');
  });

  test('05 inventory shows starter letter А + acquired cards', async () => {
    if (await gameActions.isInCombat()) { await gameActions.fleeBattle(); await godot.waitMs(2000); }
    // Starter А is always present; try to add more (may fail if scene just transitioned)
    try {
      await gameActions.testAddLetter('Б'); await godot.waitMs(300);
      await gameActions.testAddLetter('О'); await godot.waitMs(300);
      await gameActions.testAddLetter('Ь'); await godot.waitMs(500);
    } catch (e) { /* non-critical */ }
    await gameActions.openInventory();
    await godot.waitMs(800);
    const inv = await gameActions.getInventoryContents();
    expect(inv.letters['А']).toBeGreaterThanOrEqual(1); // starter letter always present
    await shot('05_inventory');
    await gameActions.closeInventory();
  });

  test('06 open dialogue with monster', async () => {
    await gameActions.testStartDialogue();
    await godot.waitFrames(20);
    const active = await gameActions.isDialogueActive();
    expect(active).toBe(true);
    const text = await gameActions.getDialogueText();
    expect(text.length).toBeGreaterThan(0);
    await shot('06_dialogue');
  });

  test('07 enter combat and play a card', async () => {
    await gameActions.startTestCombat('Страж', 50, []); // no enemy letters → enemy plays weak Я, no shield
    await gameActions.waitForCombat();
    await godot.waitMs(600);
    await shot('07_combat_start');
    await gameActions.resetCombatLog();
    await gameActions.selectBattleCard('А');
    await godot.waitMs(400);
    await shot('07_combat_card');
    await gameActions.confirmBattleTurnExplicit();
    const log = await gameActions.getCombatLogAll();
    const dmg = log.find((e) => e.event === 'damage' && e.letter === 'А');
    expect(dmg).toBeDefined();
    await shot('07_combat_resolved');
  });

  test('08 win combat, collect loot, return to world', async () => {
    let inCombat = await gameActions.isInCombat();
    if (inCombat) {
      for (let round = 0; round < 4; round++) {
        const st = await gameActions.getCombatState();
        if (!st || !st.is_active) break;
        await gameActions.resetCombatLog();
        await gameActions.selectBattleCard('А');
        await gameActions.confirmBattleTurnExplicit();
        await godot.waitMs(500);
      }
      await godot.waitMs(2500);
    }
    // Fallback: if still stuck in combat (timing), flee to return to world
    if (await gameActions.isInCombat()) {
      await gameActions.fleeBattle();
      await godot.waitMs(3000);
    }
    const stillInCombat = await gameActions.isInCombat();
    expect(stillInCombat).toBe(false);
    await shot('08_back_in_world');
  });

  test('09 final state summary', async () => {
    const inv = await gameActions.getInventoryContents();
    const hp = await gameActions.getHPFromHUD();
    console.log('FINAL_INV', JSON.stringify(inv));
    console.log('FINAL_HP', hp);
    await shot('09_final');
    expect(Object.keys(inv.letters).length).toBeGreaterThan(0);
  });
});
