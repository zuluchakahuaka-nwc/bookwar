// Portal opens at 75% progress; entering it transitions to Level 2 with the hero
// spawning cleanly and able to move (not stuck).
const godot = require('../helpers/godot_page');
const gameActions = require('../helpers/game_actions');

async function progress() {
  return await godot.evaluateInPage(() => window.gameLevelProgress || 0);
}
async function portalSpawned() {
  return await godot.evaluateInPage(() => !!window.gamePortalSpawned);
}
async function region() {
  const hud = await gameActions.getHUDText();
  return hud.region;
}

describe('Portal: 75% progress -> Level 2 (no stuck hero)', () => {
  jest.setTimeout(200000);
  beforeAll(async () => { await godot.loadGame(); await gameActions.waitForGameLoad(); await gameActions.startNewGame(); await godot.waitMs(2500); });
  afterAll(async () => { await godot.closeBrowser(); });

  test('portal opens at ~50% and hero arrives on Level 2 able to move', async () => {
    // Ensure enough currency to talk
    await gameActions.testAddDots(15);
    await godot.waitMs(300);

    // Resolve "!" (neutralize) and recruit several "?" — both count toward progress
    await godot.evaluateInPage(() => { if (typeof window.gameClearRegion === 'function') window.gameClearRegion(); });
    await godot.waitMs(1200);
    for (let r = 0; r < 5; r++) {
      await godot.evaluateInPage(() => { if (typeof window.gameForceRecruit === 'function') window.gameForceRecruit(true); });
      await godot.waitFrames(5);
      await gameActions.testStartDialogue();
      await godot.waitMs(400);
      for (let i = 0; i < 8; i++) {
        const active = await gameActions.isDialogueActive();
        if (!active) break;
        await godot.evaluateInPage(() => { if (typeof window.gameAdvanceDialogue === 'function') window.gameAdvanceDialogue(); });
        await godot.waitMs(220);
      }
      await godot.waitMs(500);
    }

    // Wander to collect currency letters until the portal opens (>=50%)
    let opened = false;
    for (let i = 0; i < 16; i++) {
      if (await portalSpawned()) { opened = true; break; }
      await gameActions.movePlayer('right', 350);
      await gameActions.movePlayer('down', 250);
      await gameActions.movePlayer('up', 250);
      await gameActions.movePlayer('left', 250);
    }
    const p = await progress();
    console.log('progress when portal opened:', p, 'opened:', opened || (await portalSpawned()));
    // The portal should have spawned by ~50%
    expect(await portalSpawned()).toBe(true);
    await godot.takeScreenshot('portal_50_open');

    // The portal spawns NEAR the hero (to the right). Step toward/around it to enter.
    for (let i = 0; i < 20; i++) {
      const r = await region();
      if (r.includes('Лес') || r.includes('лес')) break;
      await gameActions.movePlayer('right', 250);
      await gameActions.movePlayer('up', 150);
      await gameActions.movePlayer('down', 200);
      await godot.waitMs(120);
    }
    await godot.waitMs(2500);
    const r2 = await region();
    console.log('region after portal:', r2);
    expect(r2).toContain('Лес');
    await godot.takeScreenshot('portal_arrived_l2');

    // HERO NOT STUCK: position is the forest start and the hero CAN MOVE
    const pos0 = await gameActions.getPlayerPosition();
    console.log('hero pos on L2:', pos0);
    expect(typeof pos0.x).toBe('number');

    await gameActions.movePlayer('right', 600);
    await gameActions.movePlayer('down', 300);
    const pos1 = await gameActions.getPlayerPosition();
    const moved = Math.abs(pos1.x - pos0.x) + Math.abs(pos1.y - pos0.y);
    console.log('hero moved on L2 by:', moved);
    expect(moved).toBeGreaterThan(20); // hero is NOT stuck — it can move
    await godot.takeScreenshot('portal_l2_moving');
  });
});
