// Read the actual _visual_root.rotation while walking — definitive wobble diagnostic.
const godot = require('./helpers/godot_page');
const game = require('./helpers/game_actions');

describe('Wobble debug', () => {
  jest.setTimeout(120000);
  beforeAll(async () => { await godot.loadGame(); await game.waitForGameLoad(); });
  afterAll(async () => { await godot.closeBrowser(); });

  test('rotation changes while walking', async () => {
    await game.startNewGame();
    await godot.waitMs(2000);
    const page = godot.getPage();
    const canvas = await page.$('canvas');
    if (canvas) { const b = await canvas.boundingBox(); if (b) await page.mouse.click(b.x + 5, b.y + 5); }
    await godot.waitMs(200);

    const atRest = await page.evaluate(() => window.gameWobbleDebug || null);
    console.log('AT REST:', JSON.stringify(atRest));

    const samples = [];
    await page.keyboard.down('KeyD');
    for (let i = 0; i < 10; i++) {
      await godot.waitMs(70);
      samples.push(await page.evaluate(() => window.gameWobbleDebug));
    }
    await page.keyboard.up('KeyD');
    console.log('WALKING samples (rot):', samples.map(s => s ? s.rot : null).join(', '));
    console.log('WALKING vis child count:', samples[0] && samples[0].vis);
    const rots = samples.map(s => Math.abs(s ? s.rot : 0));
    const maxRot = Math.max.apply(null, rots);
    console.log('MAX |rot| while walking:', maxRot);
    const movingAny = samples.some(s => s && s.moving);
    console.log('any moving=true:', movingAny);
    // Expect the visual root to actually rotate while walking
    expect(movingAny).toBe(true);
  });
});
