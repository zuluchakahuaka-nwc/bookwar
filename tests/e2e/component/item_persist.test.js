// Items (currency + letters) must NOT respawn after a battle.
const godot = require('../helpers/godot_page');
const gameActions = require('../helpers/game_actions');

async function itemCount() {
  return await godot.evaluateInPage(() => window.gameItemCount || 0);
}

describe('Items do not respawn after battle', () => {
  jest.setTimeout(150000);
  beforeAll(async () => { await godot.loadGame(); await gameActions.waitForGameLoad(); await gameActions.startNewGame(); await godot.waitMs(2500); });
  afterAll(async () => { await godot.closeBrowser(); });

  test('collected items stay collected after a battle', async () => {
    await godot.waitMs(800);
    const before = await itemCount();
    console.log('items before:', before);
    expect(before).toBeGreaterThan(0);

    // Wander to collect a bunch of currency letters
    const inv0 = await gameActions.getInventoryContents();
    const dots0 = inv0.dots;
    for (let i = 0; i < 8; i++) {
      await gameActions.movePlayer('right', 350);
      await gameActions.movePlayer('down', 250);
      await gameActions.movePlayer('up', 250);
      await gameActions.movePlayer('left', 200);
      if (await gameActions.isInCombat()) { await gameActions.fleeBattle(); await godot.waitMs(2000); }
    }
    await godot.waitMs(600);
    const mid = await itemCount();
    const inv1 = await gameActions.getInventoryContents();
    console.log('items after collecting:', mid, 'bukvitsy:', inv1.dots);
    expect(mid).toBeLessThan(before); // we picked some up
    expect(inv1.dots).toBeGreaterThan(dots0);

    await godot.takeScreenshot('items_before_battle');

    // Fight a battle and return to world (scene reloads)
    await gameActions.testAddLetter('А');
    await gameActions.startTestCombat('PickupFoe', 30, ['Я']);
    await gameActions.waitForCombat(12000);
    await godot.waitMs(400);
    await gameActions.selectBattleCard('А');
    await gameActions.confirmBattleTurnExplicit();
    await gameActions.waitForWorld(15000);
    await godot.waitMs(2500);

    // After reload: collected items must NOT have respawned
    const after = await itemCount();
    console.log('items after battle:', after);
    expect(after).toBe(mid); // same count as right before the battle (no respawn)

    // Буквицы preserved
    const inv2 = await gameActions.getInventoryContents();
    expect(inv2.dots).toBe(inv1.dots);

    await godot.takeScreenshot('items_after_battle');
  });
});
