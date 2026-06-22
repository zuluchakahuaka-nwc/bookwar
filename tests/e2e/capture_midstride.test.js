// Capture hero MID-STRIDE: screenshot while the movement key is still held,
// so the wobble tilt is caught at a non-zero phase.
const godot = require('./helpers/godot_page');
const game = require('./helpers/game_actions');

describe('Mid-stride wobble capture', () => {
  jest.setTimeout(120000);
  beforeAll(async () => { await godot.loadGame(); await game.waitForGameLoad(); });
  afterAll(async () => { await godot.closeBrowser(); });

  test('hero tilted while walking', async () => {
    await game.startNewGame();
    await godot.waitMs(2000);
    const page = godot.getPage();
    const canvas = await page.$('canvas');
    // focus canvas
    if (canvas) { const b = await canvas.boundingBox(); if (b) await page.mouse.click(b.x + 5, b.y + 5); }
    await godot.waitMs(200);

    // Walk right continuously; snapshot while the key is HELD DOWN (hero in motion).
    for (let i = 0; i < 6; i++) {
      await page.keyboard.down('KeyD');
      await godot.waitMs(180);          // mid-stride
      await godot.takeScreenshot('midstride_valley_' + i);
      await page.keyboard.up('KeyD');
      await godot.waitMs(60);
    }

    // Also capture an enemy mid-stride (a '?' / '!' monster patrols). Move toward one.
    await page.keyboard.down('KeyD');
    await godot.waitMs(1500);
    await godot.takeScreenshot('midstride_enemies');
    await page.keyboard.up('KeyD');
  });
});
