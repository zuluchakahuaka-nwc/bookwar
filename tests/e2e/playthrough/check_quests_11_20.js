const puppeteer = require('puppeteer');
const sleep = ms => new Promise(r => setTimeout(r, ms));
const MAPS = ['forgotten_ruins','misty_grove','grey_forest','wind_pass','ice_pincers','mountain_caves','deep_mines','catacombs_silence','vaults_oblivion','underground_river'];
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

  let total = 0;
  for (const m of MAPS) {
    const prev = await p.evaluate(() => (window.gameHUD || {}).region || '');
    await p.evaluate((id) => { if (window.gameTestGotoMap) window.gameTestGotoMap(id); }, m);
    for (let k = 0; k < 24; k++) { await sleep(500); const r = await p.evaluate(() => (window.gameHUD || {}).region || ''); if (r && r !== prev && r !== '?') break; }
    await sleep(1000);
    const q = await p.evaluate(() => { try { return JSON.parse(window.gameQuests || '{}'); } catch(e){ return {}; } });
    const manual = (q.active || []).filter(x => !x.auto).length;
    const auto = (q.active || []).filter(x => x.auto).length;
    total += (q.active || []).length;
    console.log(`L${MAPS.indexOf(m)+11} ${m}: ${q.active?.length || 0} quests (manual ${manual}, auto ${auto})`);
  }
  console.log('TOTAL active across maps 11-20:', total);
  await b.close();
})();
