// Скриншоты: карты 4 и 5 — должны быть named creatures (Зрячий, Жор)
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

  for (const mapId of ['mossy_lowlands', 'rotten_swamps']) {
    const prev = await p.evaluate(() => (window.gameHUD || {}).region || '');
    await p.evaluate((id) => { if (window.gameTestGotoMap) window.gameTestGotoMap(id); }, mapId);
    for (let k = 0; k < 24; k++) { await sleep(500); const r = await p.evaluate(() => (window.gameHUD || {}).region || ''); if (r && r !== prev && r !== '?') break; }
    await sleep(1500);
    // Снять сцены с разными named creatures
    const monsters = await p.evaluate(() => (window.gameMonsterStates || []).map(m => ({id: m.id, name: m.name})));
    console.log(mapId, 'monsters:', JSON.stringify(monsters.filter(m => m.id !== 'question' && m.id !== 'exclamation').slice(0,5)));
    // Скриншот ДО clearRegion — чтобы видеть существ
    await p.screenshot({ path: `D:/Projects/BOOKWAR/tests/screenshots/named_creatures_${mapId}.png` });
  }
  await b.close();
})();
