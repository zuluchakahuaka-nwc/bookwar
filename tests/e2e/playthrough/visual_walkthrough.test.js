const godot = require('../helpers/godot_page');
const gameActions = require('../helpers/game_actions');

describe('Visual Walkthrough Bot — Светлая Долина', () => {
  jest.setTimeout(180000);

  beforeAll(async () => {
    await godot.loadGame();
    await gameActions.waitForGameLoad();
    await gameActions.startNewGame();
    await godot.waitMs(3000);
  });

  afterAll(async () => {
    await godot.closeBrowser();
  });

  async function step(num, label, actionFn, waitMs = 2000) {
    if (actionFn) await actionFn();
    if (waitMs > 0) await godot.waitMs(waitMs);
    await godot.takeScreenshot('vb_' + String(num).padStart(2, '0') + '_' + label);
    const state = await godot.evaluateInPage(() => ({
      hp: window.gameHUD?.hp || '',
      dots: window.gameHUD?.dots || '',
      region: window.gameHUD?.region || '',
      dialogueActive: window.gameDialogueActive || false,
      dialogueText: window.gameDialogueText || '',
      inCombat: window.gameInCombat || false,
      inventoryVisible: window.gameInventoryVisible || false,
      monsters: (window.gameMonsterStates || []).map(m => ({
        id: m.id, state: m.state, allegiance: m.allegiance, hp: m.hp
      })),
      pos: window.gamePlayerPos || {}
    }));
    console.log(`[VB ${String(num).padStart(2,'0')}] ${label}`, JSON.stringify(state));
    return state;
  }

  test('full visual walkthrough', async () => {
    // 01: Spawn point
    await step(1, 'spawn', null, 1000);

    // 02: Move right toward nearest monster (?)
    await step(2, 'move_right', () => gameActions.movePlayer('right', 1500), 500);

    // 03: Continue moving to approach ? monster
    await step(3, 'approach_monster', () => gameActions.movePlayer('right', 2000), 1000);

    // 04: Start dialogue with nearest monster
    await step(4, 'dialogue_start', async () => {
      await gameActions.testAddDots(3);
      await godot.waitFrames(5);
      await gameActions.testStartDialogue();
    }, 1000);

    // 05: Dialogue active — screenshot
    const dlgState = await step(5, 'dialogue_active', null, 500);
    console.log('  dialogue active:', dlgState.dialogueActive, 'text:', dlgState.dialogueText);

    // 06: Close dialogue (press E)
    await step(6, 'dialogue_close', async () => {
      await gameActions.interact();
    }, 1500);

    // 07: Open inventory
    await step(7, 'inventory_open', async () => {
      await gameActions.openInventory();
    }, 500);

    // 08: Close inventory
    await step(8, 'inventory_close', async () => {
      await gameActions.closeInventory();
    }, 500);

    // 09: Move toward danger zone (further right)
    await step(9, 'danger_zone', () => gameActions.movePlayer('right', 3000), 1000);

    // 10: Move back to safety
    await step(10, 'retreat', async () => {
      await gameActions.movePlayer('left', 2000);
      await gameActions.movePlayer('up', 1000);
    }, 500);

    // 11: Add letters and start test combat
    await step(11, 'combat_prep', async () => {
      await gameActions.testAddLetter('А');
      await gameActions.testAddLetter('Б');
      await godot.waitFrames(10);
    }, 500);

    // 12: Start combat
    await step(12, 'combat_start', async () => {
      await gameActions.startTestCombat('Тестовый Враг', 50, ['Я']);
    }, 2000);

    // 13: Select card and attack
    await step(13, 'combat_attack', async () => {
      await gameActions.selectBattleCard('А');
      await gameActions.confirmBattleTurnExplicit();
    }, 1500);

    // 14: Screenshot combat result
    await step(14, 'combat_result', null, 500);

    // 15: Flee battle
    await step(15, 'combat_flee', async () => {
      await gameActions.fleeBattle();
    }, 2000);

    // 16: Back in world — final state
    const finalState = await step(16, 'final', null, 1000);
    console.log('\n=== ИТОГ ВИЗУАЛЬНОГО ПРОХОЖДЕНИЯ ===');
    console.log('HP:', finalState.hp);
    console.log('Точки:', finalState.dots);
    console.log('Регион:', finalState.region);
    console.log('Позиция:', JSON.stringify(finalState.pos));
    console.log('Монстров видно:', finalState.monsters.length);
    console.log('Аллегиансы:', finalState.monsters.map(m => `${m.id}:${m.allegiance}`).join(', '));
  });
});
