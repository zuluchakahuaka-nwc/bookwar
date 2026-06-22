// VISIBLE bot: goes to Level 2 and shows the REAL drawn enemy (Лесная Тварь),
// not just a "!" symbol. Watch the Chrome window.
const puppeteer = require('puppeteer');
const fs = require('fs');
const path = require('path');
const URL = 'http://localhost:3000';
const SHOT = path.join(__dirname, 'screenshots');
fs.mkdirSync(SHOT, { recursive: true });
const sleep = (ms) => new Promise(r => setTimeout(r, ms));
const shot = async (page, l) => { const f = path.join(SHOT, `creature_${l}_${Date.now()}.png`); await page.screenshot({ path: f }); console.log('SHOT', l, path.basename(f)); };

(async () => {
  const browser = await puppeteer.launch({ headless: false, defaultViewport: { width: 1280, height: 720 }, args: ['--no-sandbox', '--disable-features=ntlm-auth', '--window-size=1300,780'] });
  const page = await browser.newPage();
  await page.goto(URL, { waitUntil: 'networkidle0', timeout: 30000 });
  await page.waitForSelector('canvas', { timeout: 15000 });
  await sleep(2000);
  const eval = (fn, ...a) => page.evaluate(fn, ...a);
  const hold = async (k, ms) => { await page.keyboard.down(k); await sleep(ms); await page.keyboard.up(k); await sleep(120); };
  const clickCanvas = async () => { const c = await page.$('canvas'); if (c) { const b = await c.boundingBox(); if (b) await page.mouse.click(b.x + 5, b.y + 5); } };

  console.log('-> New game');
  await eval(() => { if (typeof window.gameClickNewGame === 'function') window.gameClickNewGame(); });
  await sleep(2500);

  console.log('-> Jump to Level 2 (Лес Двубуквия)');
  await eval(() => { if (typeof window.gameTestGotoMap === 'function') window.gameTestGotoMap('two_letter_forest'); });
  await sleep(3500);
  await shot(page, 'l2_arrived');

  // Count real creatures on the map
  const monsters = await eval(() => window.gameMonsterStates || []);
  const creatures = monsters.filter(m => m.id === 'forest_creature');
  console.log('-> Real enemies (Лесная Тварь) on map:', creatures.length);

  // Walk east toward where creatures spawn so you can SEE them
  for (let i = 0; i < 8; i++) {
    await clickCanvas();
    await hold('KeyD', 700);
    await sleep(200);
  }
  await shot(page, 'creature_in_view');
  console.log('-> A real drawn enemy should now be visible (not just "!").');

  // Try to start a dialogue with a creature to hear the new forest lines
  await eval(() => { if (typeof window.gameTestAddDots === 'function') window.gameTestAddDots(6); });
  await sleep(300);
  await eval(() => { if (typeof window.gameTestStartDialogue === 'function') window.gameTestStartDialogue(); });
  await sleep(1500);
  const dt = await eval(() => window.gameDialogueText || '');
  console.log('-> Forest dialogue:', dt);
  await shot(page, 'forest_dialogue');

  console.log('Keeping window open 8s...');
  await sleep(8000);
  await browser.close();
  console.log('done');
})().catch(e => { console.error('BOT ERROR:', e); process.exit(1); });
