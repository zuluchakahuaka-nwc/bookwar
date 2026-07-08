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
  // Switch to English
  await p.evaluate(() => { if (window.gameSetLocale) window.gameSetLocale('en'); });
  await sleep(800);
  const menuTexts = await p.evaluate(() => window.gameMenuTexts || {});
  console.log('en menu:', JSON.stringify(menuTexts));
  await p.screenshot({ path: 'D:/Projects/BOOKWAR/tests/screenshots/locale_en_menu.png' });
  // New game → map 1
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
  const hud = await p.evaluate(() => window.gameHUD || {});
  console.log('en hud:', JSON.stringify(hud));
  await p.screenshot({ path: 'D:/Projects/BOOKWAR/tests/screenshots/locale_en_game.png' });
  await b.close();
})();
