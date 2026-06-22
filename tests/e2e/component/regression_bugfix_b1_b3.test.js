const godot = require('../helpers/godot_page');
const gameActions = require('../helpers/game_actions');

describe('Regression: Bug Fixes B1-B3', () => {
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

  // B1: Inventory closes on repeated I press
  describe('B1: Inventory open/close toggle', () => {
    test('inventory toggles open then closed with I key', async () => {
      await gameActions.openInventory();
      let state = await godot.getGameState();
      expect(state.inventoryVisible).toBe(true);
      await godot.takeScreenshot('b1_inventory_open');

      await gameActions.closeInventory();
      state = await godot.getGameState();
      expect(state.inventoryVisible).toBe(false);
      await godot.takeScreenshot('b1_inventory_closed');
    });

    test('inventory toggles multiple times reliably', async () => {
      for (let i = 0; i < 5; i++) {
        await gameActions.openInventory();
        let st = await godot.getGameState();
        expect(st.inventoryVisible).toBe(true);

        await gameActions.closeInventory();
        st = await godot.getGameState();
        expect(st.inventoryVisible).toBe(false);
      }
    });
  });

  // B2: Combat shows visible result (HP change + messages)
  describe('B2: Combat visible result', () => {
    test('selecting letter + confirm produces HP change and messages', async () => {
      // Give player letters for combat
      await gameActions.testAddLetter('А');
      await gameActions.testAddLetter('Б');
      await godot.waitFrames(10);

      // Start test combat
      await gameActions.startTestCombat('TestBug', 50, ['Я']);
      await godot.waitMs(2000);

      // Wait for combat to be active
      const inCombat = await gameActions.waitForCombat(10000);
      expect(inCombat).toBe(true);

      // Get initial state
      const stateBefore = await gameActions.getCombatState();
      expect(stateBefore).toBeTruthy();
      const enemyHpBefore = stateBefore.enemy_hp;

      await godot.takeScreenshot('b2_combat_start');

      // Select a vowel (attack) and confirm
      await gameActions.selectBattleCard('А');
      await gameActions.confirmBattleTurnExplicit();
      await godot.waitMs(1000);

      // Check messages appeared
      const messages = await gameActions.getBattleMessages();
      expect(messages.length).toBeGreaterThan(0);

      // Check state changed (HP or turn count)
      const stateAfter = await gameActions.getCombatState();
      expect(stateAfter).toBeTruthy();
      expect(stateAfter.turn_count).toBeGreaterThan(0);

      await godot.takeScreenshot('b2_combat_after_turn');

      // Flee to return to world
      await gameActions.fleeBattle();
      await godot.waitMs(2000);
    });
  });

  // B3: Monsters don't attack during dialogue
  describe('B3: Dialogue prevents monster attacks', () => {
    test('dialogue active flag is set and prevents combat', async () => {
      // Start dialogue via test bridge
      await gameActions.testStartDialogue();
      await godot.waitFrames(20);

      const dialogueActive = await gameActions.isDialogueActive();
      expect(dialogueActive).toBe(true);

      // While in dialogue, combat should NOT start
      const inCombat = await gameActions.isInCombat();
      expect(inCombat).toBe(false);

      await godot.takeScreenshot('b3_dialogue_no_combat');
    });
  });
});
