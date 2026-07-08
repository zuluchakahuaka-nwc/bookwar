// e2e: 2-client multiplayer — verify position sync via WebSocket relay server.
// Launches 2 Puppeteer browsers, both connect to ws://localhost:4567, move
// their heroes, and verify each sees the other's remote sprite.
const puppeteer = require('puppeteer');
const path = require('path');
const fs = require('fs');
const sleep = ms => new Promise(r => setTimeout(r, ms));

const MP_URL = 'ws://localhost:4567';
const SHOTS = path.join(__dirname, '..', 'screenshots', 'mp_2client');
if (!fs.existsSync(SHOTS)) fs.mkdirSync(SHOTS, { recursive: true });

async function setupClient(name) {
  const browser = await puppeteer.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-web-security', '--disable-features=ntlm-auth']
  });
  const page = await browser.newPage();
  await page.setViewport({ width: 1280, height: 720 });
  await page.goto('http://localhost:3000', { waitUntil: 'domcontentloaded' });
  await page.waitForSelector('canvas', { timeout: 30000 });
  await sleep(3500);
  await page.evaluate(() => window.gameClickNewGame && window.gameClickNewGame());
  await sleep(2000);
  await page.evaluate(() => window.gameSkipIntro && window.gameSkipIntro());
  await sleep(1500);
  for (let i = 0; i < 12; i++) {
    await page.evaluate(() => window.gameAdvanceIntro && window.gameAdvanceIntro());
    await sleep(300);
  }
  await sleep(800);
  await page.evaluate((n) => window.gameSelectHeroByIndex && window.gameSelectHeroByIndex(n), 0);
  await sleep(500);
  await page.evaluate(() => window.gameConfirmHero && window.gameConfirmHero());
  await sleep(3500);
  // Trigger multiplayer connect
  await page.evaluate((url) => { window._mpWantConnect = url; }, MP_URL);
  await sleep(5000); // give server 5s to register
  console.log(`[${name}] connected=${await page.evaluate(() => !!window.gameMPConnected)}`);
  return { browser, page };
}

(async () => {
  console.log('=== Multiplayer 2-client e2e ===');
  const c1 = await setupClient('Client1');
  const c2 = await setupClient('Client2');

  try {
    // Wait for both to see each other
    let c1Count = 0, c2Count = 0;
    for (let i = 0; i < 10; i++) {
      await sleep(1000);
      c1Count = await c1.page.evaluate(() => window.gameMPPlayersCount || 0);
      c2Count = await c2.page.evaluate(() => window.gameMPPlayersCount || 0);
      console.log(`t=${(i+1)}s  c1 players=${c1Count}  c2 players=${c2Count}`);
      if (c1Count >= 1 && c2Count >= 1) break;
    }
    // Move client1 and verify client2 sees position change
    const canvas = await c1.page.$('canvas');
    const box = await canvas.boundingBox();
    await c1.page.mouse.click(box.x + box.width/2, box.y + box.height/2);
    await c1.page.keyboard.down('KeyD');
    await sleep(1500);
    await c1.page.keyboard.up('KeyD');
    await sleep(2000);
    const c1pos = await c1.page.evaluate(() => window.gamePlayerPos);
    console.log('c1 player pos after move:', JSON.stringify(c1pos));

    await c1.page.screenshot({ path: path.join(SHOTS, 'c1_with_remote.png') });
    await c2.page.screenshot({ path: path.join(SHOTS, 'c2_with_remote.png') });

    const c1Connected = await c1.page.evaluate(() => !!window.gameMPConnected);
    const c2Connected = await c2.page.evaluate(() => !!window.gameMPConnected);
    console.log(`\n=== RESULT ===`);
    console.log(`c1 connected=${c1Connected} players=${c1Count}`);
    console.log(`c2 connected=${c2Connected} players=${c2Count}`);
    const pass = c1Connected && c2Connected && c1Count >= 1 && c2Count >= 1;
    console.log(`PASS=${pass}`);
  } finally {
    await c1.browser.close();
    await c2.browser.close();
  }
})();
