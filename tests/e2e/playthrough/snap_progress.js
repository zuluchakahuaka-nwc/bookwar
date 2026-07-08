const puppeteer = require('puppeteer');
const sleep = ms => new Promise(r => setTimeout(r, ms));
(async () => {
  const b = await puppeteer.launch({ headless: true, args: ['--no-sandbox','--disable-web-security','--disable-features=ntlm-auth'] });
  const p = await b.newPage();
  await p.setViewport({ width: 1280, height: 720 });
  await p.goto('http://localhost:3000', { waitUntil: 'domcontentloaded', timeout: 60000 });
  await p.waitForSelector('canvas', { timeout: 30000 });
  const c = await p.$('canvas');
  if (c) { const bx = await c.boundingBox(); if (bx) await p.mouse.click(bx.x+5, bx.y+5); }
  await sleep(3500);
  await p.evaluate(() => window.gameClickNewGame && window.gameClickNewGame());
  await sleep(2000);
  await p.evaluate(() => window.gameSkipIntro && window.gameSkipIntro());
  await sleep(1500);
  for (let i = 0; i < 12; i++) { await p.evaluate(() => window.gameAdvanceIntro && window.gameAdvanceIntro()); await sleep(300); }
  await sleep(800);
  await p.evaluate(() => { if (window.gameSelectHeroByIndex) window.gameSelectHeroByIndex(0); });
  await sleep(500);
  await p.evaluate(() => { if (window.gameConfirmHero) window.gameConfirmHero(); });
  await sleep(3500);
  // Карта 1 — progress должен быть 0% в начале
  let prog1 = await p.evaluate(() => window.gameLevelProgress || 0);
  console.log('progress at start:', prog1);
  await p.screenshot({ path: 'D:/Projects/BOOKWAR/tests/screenshots/progress_bar_start.png' });
  // Нейтрализовать всех → 100%
  await p.evaluate(() => { if (window.gameClearRegion) window.gameClearRegion(); });
  await sleep(2500);
  let prog2 = await p.evaluate(() => window.gameLevelProgress || 0);
  console.log('progress after clearRegion:', prog2);
  await p.screenshot({ path: 'D:/Projects/BOOKWAR/tests/screenshots/progress_bar_full.png' });
  await b.close();
})();
