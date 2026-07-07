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
  // Карта 3 (dark_oaks) — 1 квест, есть ? монстры
  const prev = await p.evaluate(() => (window.gameHUD || {}).region || '');
  await p.evaluate(() => window.gameTestGotoMap('dark_oaks'));
  for (let k = 0; k < 24; k++) { await sleep(500); const r = await p.evaluate(() => (window.gameHUD || {}).region || ''); if (r && r !== prev && r !== '?') break; }
  await sleep(1500);
  // Нейтрализовать ! монстров (чтобы не атаковали), ? оставить для маркера
  await p.evaluate(() => { if (window.gameClearRegion) window.gameClearRegion(); });
  await sleep(2000);
  await p.screenshot({ path: 'D:/Projects/BOOKWAR/tests/screenshots/quest_markers.png' });
  console.log('screenshot saved');
  await b.close();
})();
