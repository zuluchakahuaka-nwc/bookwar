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
  await sleep(3000);
  // Debug: что открыто?
  const debug = await p.evaluate(() => ({
    menuVisible: window.gameMenuVisible,
    introActive: window.gameIntroActive,
    charLoaded: window.gameCharSelectLoaded,
    heroConfirmed: window.gameHeroConfirmed,
    hudKeys: Object.keys(window.gameHUD || {}),
    inventoryVisible: window.gameInventoryVisible,
  }));
  console.log('debug state:', JSON.stringify(debug));
  const monsters = await p.evaluate(() => (window.gameMonsterStates || []));
  console.log('all monsters:', monsters.map(m => ({id: m.id, name: m.name})));
  const smith = monsters.find(m => m.id === 'wordsmith');
  console.log('wordsmith:', smith);
  if (smith) {
    // Телепортировать к нему и попытаться говорить
    await p.evaluate((x, y) => { if (window.gameTestTeleport) window.gameTestTeleport(x + 60, y); }, smith.position.x, smith.position.y);
    await sleep(800);
    await p.screenshot({ path: 'D:/Projects/BOOKWAR/tests/screenshots/wordsmith_pre.png' });
    // T для диалога
    const canvas = await p.$('canvas');
    if (canvas) { const box = await canvas.boundingBox(); if (box) await p.mouse.click(box.x + box.width/2, box.y + box.height/2); }
    await p.keyboard.press('KeyT');
    await sleep(1500);
    const craftOpen = await p.evaluate(() => !!window.gameCraftVisible);
    console.log('craft open after T near smith:', craftOpen);
    await p.screenshot({ path: 'D:/Projects/BOOKWAR/tests/screenshots/wordsmith_craft.png' });
  }
  await b.close();
})();
