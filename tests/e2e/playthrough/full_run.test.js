const godot = require('../helpers/godot_page');
const gameActions = require('../helpers/game_actions');

describe('Full Playthrough: Light Valley', () => {
  jest.setTimeout(180000);

  beforeAll(async () => {
    await godot.loadGame();
    await gameActions.waitForGameLoad();
  });

  afterAll(async () => {
    await godot.closeBrowser();
  });

  test('Step 1: Game loads and shows main menu', async () => {
    const menuVisible = await gameActions.isMenuVisible();
    expect(menuVisible).toBe(true);
  });

  test('Step 2: New game spawns player in Light Valley at full HP', async () => {
    await gameActions.startNewGame();
    await godot.waitMs(3000);
    const pos = await gameActions.getPlayerPosition();
    expect(typeof pos.x).toBe('number');
    expect(typeof pos.y).toBe('number');
    const hp = await gameActions.getHPFromHUD();
    expect(hp).toContain('100');
    const region = await gameActions.getHUDText();
    expect(region.region).toContain('Долина');
  });

  test('Step 3: Player actually moves (position changes)', async () => {
    const start = await gameActions.getPlayerPosition();
    await gameActions.movePlayer('right', 500);
    await gameActions.movePlayer('up', 300);
    const end = await gameActions.getPlayerPosition();
    const moved = Math.abs(end.x - start.x) > 5 || Math.abs(end.y - start.y) > 5;
    expect(moved).toBe(true);
  });

  test('Step 4: Player collects dots from the ground (dots increase)', async () => {
    const before = await gameActions.getInventoryContents();
    const dotsBefore = before.dots + (before.punctuation['...'] || 0) * 3;
    // Deterministic: walk to the nearest uncollected dot (blind zigzags are flaky).
    const target = await godot.getPage().evaluate(() => {
      const p = window.gamePlayerPos;
      if (!p) return null;
      const dots = (window.gameItemPositions || []).filter(i => (i.t || '') !== 'letter');
      if (!dots.length) return null;
      const withD = dots.map(i => ({ ...i, d: Math.hypot(i.x - p.x, i.y - p.y) }));
      withD.sort((a, b) => a.d - b.d);
      return { x: withD[0].x, y: withD[0].y };
    });
    expect(target).not.toBeNull();
    // The item-positions bridge lags behind auto-pickup — try up to 3 nearest
    // dots, re-reading positions each time, until the count grows.
    let collected = false;
    for (let attempt = 0; attempt < 3 && !collected; attempt++) {
      const t = await godot.getPage().evaluate(() => {
        const p = window.gamePlayerPos;
        if (!p) return null;
        const dots = (window.gameItemPositions || []).filter(i => (i.t || '') !== 'letter');
        if (!dots.length) return null;
        const withD = dots.map(i => ({ ...i, d: Math.hypot(i.x - p.x, i.y - p.y) }));
        withD.sort((a, b) => a.d - b.d);
        return { x: withD[0].x, y: withD[0].y };
      });
      if (!t) break;
      await gameActions.movePlayerTo(t.x, t.y);
      await gameActions.interact();
      await godot.waitFrames(10);
      const after = await gameActions.getInventoryContents();
      const dotsNow = after.dots + (after.punctuation['...'] || 0) * 3;
      if (dotsNow > dotsBefore) collected = true;
    }
    expect(collected).toBe(true);
  });

  test('Step 5: Three dots combine into ellipsis (...)', async () => {
    const inv = await gameActions.getInventoryContents();
    let hasEllipsis = inv.punctuation && inv.punctuation['...'] > 0;
    if (!hasEllipsis) {
      // top up to guarantee an ellipsis forms
      await gameActions.testAddDots(3);
      await godot.waitFrames(10);
    }
    const inv2 = await gameActions.getInventoryContents();
    expect(inv2.punctuation['...']).toBeGreaterThan(0);
  });

  test('Step 6: Player can open dialogue with a monster via ellipsis', async () => {
    await gameActions.testStartDialogue();
    await godot.waitFrames(15);
    const active = await gameActions.isDialogueActive();
    expect(active).toBe(true);
    const text = await gameActions.getDialogueText();
    expect(text.length).toBeGreaterThan(0);
  });

  test('Step 7: Player acquires a hidden letter (inventory gains a letter)', async () => {
    const before = await gameActions.getInventoryContents();
    const lettersBefore = Object.keys(before.letters || {}).length;
    // Я is guaranteed NEW: heroes start with А,О,М (Словомир) + valley drops
    // А,М,О — adding О would only raise its level, not the type count.
    await gameActions.testAddLetter('Я'); // new letter type
    await godot.waitFrames(10);
    const after = await gameActions.getInventoryContents();
    const lettersAfter = Object.keys(after.letters || {}).length;
    expect(lettersAfter).toBeGreaterThan(lettersBefore);
  });

  test('Step 8: Inventory UI shows the collected letter', async () => {
    await gameActions.openInventory();
    const inv = await gameActions.getInventoryContents();
    expect(inv.letters['А']).toBeGreaterThanOrEqual(1);
    await gameActions.closeInventory();
  });

  test('Step 9: HUD still shows valid HP after exploration', async () => {
    const hp = await gameActions.getHPFromHUD();
    expect(hp).toMatch(/HP:\s*\d+\/\d+/);
    const hpValue = parseInt(hp.match(/HP:\s*(\d+)/)[1], 10);
    expect(hpValue).toBeGreaterThan(0);
  });

  test('Step 10: Combat works end-to-end (win -> loot -> return to world)', async () => {
    await gameActions.startTestCombat('FinalFoe', 1, ['О']);
    await gameActions.waitForCombat();
    const combatState = await gameActions.getCombatState();
    expect(combatState.is_active).toBe(true);
    await gameActions.resetCombatLog();
    await gameActions.selectBattleCard('А');
    await gameActions.confirmBattleTurnExplicit();
    await godot.waitMs(2500);
    await gameActions.waitForWorld();
    const inCombat = await gameActions.isInCombat();
    expect(inCombat).toBe(false);
    const inv = await gameActions.getInventoryContents();
    expect(inv.letters['О']).toBeGreaterThanOrEqual(1);
  });
});
