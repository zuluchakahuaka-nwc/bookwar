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
  await sleep(2500);
  // Телепортировать игрока в дальний угол (подальше от монстров)
  await p.evaluate(() => { if (window.gameTestTeleport) window.gameTestTeleport(200, 200); });
  await sleep(1500);
  // Убедимся что мы в мире
  const inWorld = await p.evaluate(() => (window.gameHUD || {}).region !== '' && (window.gameHUD || {}).region !== '?');
  console.log('inWorld:', inWorld, 'region:', await p.evaluate(() => (window.gameHUD || {}).region));
  // Сделать 3 скриншота с разных точек карты
  await p.screenshot({ path: 'D:/Projects/BOOKWAR/tests/screenshots/decor_meadow.png' });
  await p.evaluate(() => { if (window.gameTestTeleport) window.gameTestTeleport(1200, 1600); });
  await sleep(800);
  await p.screenshot({ path: 'D:/Projects/BOOKWAR/tests/screenshots/decor_meadow_2.png' });
  console.log('2 screenshots saved');
  await b.close();
})();
