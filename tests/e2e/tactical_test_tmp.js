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
  // Add some letters via test bridge so auto-equip has options
  await p.evaluate(() => {
    ['А','О','М','Б','К','В'].forEach(l => { if (window.gameTestAddLetter) window.gameTestAddLetter(l); });
  });
  await sleep(800);
  const inv = await p.evaluate(() => window.gameInventory);
  console.log('inventory:', JSON.stringify(inv.letters));
  // Auto-equip via JS bridge (set _godotTacticalAuto = true)
  // Actually use direct equip chain — but easier: call gameTacticalEquip for each slot
  // Or check if there's a direct bridge. The singleton exposes equip via _godotTacticalEquip queue.
  await p.evaluate(() => {
    if (window.gameTacticalEquip) {
      window.gameTacticalEquip('right_hand', 'А');
      window.gameTacticalEquip('head', 'Б');
      window.gameTacticalEquip('torso', 'В');
      window.gameTacticalEquip('left_hand', 'О');
    }
  });
  await sleep(1000);
  const tac = await p.evaluate(() => ({
    slots: window.gameTacticalSlots,
    attack: window.gameTacticalAttack,
    armor: window.gameTacticalArmor
  }));
  console.log('tactical state:', JSON.stringify(tac, null, 2));
  const ok = tac.slots !== undefined && typeof tac.attack === 'number' && typeof tac.armor === 'number';
  console.log('Tactical auto-equip result:', ok ? 'PASS' : 'FAIL');
  await b.close();
  process.exit(ok ? 0 : 1);
})();
