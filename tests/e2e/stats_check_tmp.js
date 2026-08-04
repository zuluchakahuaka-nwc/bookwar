const puppeteer = require('puppeteer');
const sleep = ms => new Promise(r => setTimeout(r, ms));
(async () => {
  const b = await puppeteer.launch({ headless: true, args: ['--no-sandbox','--disable-web-security','--disable-features=ntlm-auth'] });
  const p = await b.newPage();
  await p.setViewport({ width: 1280, height: 720 });
  await p.goto('http://localhost:3000', { waitUntil: 'domcontentloaded', timeout: 60000 });
  await p.waitForSelector('canvas', { timeout: 30000 });
  await sleep(5000);
  const c = await p.$('canvas'); const bx = await c.boundingBox();
  await p.mouse.click(bx.x + bx.width/2, bx.y + bx.height/2);
  await sleep(500);
  await p.evaluate(() => window.gameClickNewGame && window.gameClickNewGame());
  await sleep(2000);
  await p.evaluate(() => window.gameSkipIntro && window.gameSkipIntro());
  await sleep(1500);
  for (let i = 0; i < 14; i++) { await p.evaluate(() => window.gameAdvanceIntro && window.gameAdvanceIntro()); await sleep(150); }
  await sleep(500);
  await p.evaluate(() => { if (window.gameSelectHeroByIndex) window.gameSelectHeroByIndex(0); });
  await sleep(400);
  await p.evaluate(() => { if (window.gameConfirmHero) window.gameConfirmHero(); });
  await sleep(3000);
  // Open stats
  await p.evaluate(() => window.gameToggleStats && window.gameToggleStats());
  await sleep(1500);
  const visible = await p.evaluate(() => window.gameStatsVisible);
  console.log('stats visible:', visible);
  await p.screenshot({ path: 'D:/Projects/BOOKWAR/tests/screenshots/stats_screen_bestiary.png' });
  await b.close();
  process.exit(visible ? 0 : 1);
})();
