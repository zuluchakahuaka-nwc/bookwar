// VISIBLE e2e bot: Level 1 -> 50% -> portal (near hero) -> Level 2 -> real creature fight.
// Watch the Chrome window. Robust: flees any stray combat, moves toward the portal.
const puppeteer = require('puppeteer');
const fs = require('fs');
const path = require('path');
const URL = 'http://localhost:3000';
const SHOT = path.join(__dirname, 'screenshots');
fs.mkdirSync(SHOT, { recursive: true });
const sleep = (ms) => new Promise(r => setTimeout(r, ms));
const shot = async (page, l) => { const f = path.join(SHOT, `vis_${l}_${Date.now()}.png`); await page.screenshot({ path: f }); console.log('SHOT', l, path.basename(f)); };

(async () => {
  const browser = await puppeteer.launch({ headless: false, defaultViewport: { width: 1280, height: 720 }, args: ['--no-sandbox', '--disable-features=ntlm-auth', '--window-size=1300,780'] });
  const page = await browser.newPage();
  await page.goto(URL, { waitUntil: 'networkidle0', timeout: 30000 });
  await page.waitForSelector('canvas', { timeout: 15000 });
  await sleep(2000);
  const eval = (fn, ...a) => page.evaluate(fn, ...a);
  const hold = async (k, ms) => { await page.keyboard.down(k); await sleep(ms); await page.keyboard.up(k); await sleep(120); };
  const clickCanvas = async () => { const c = await page.$('canvas'); if (c) { const b = await c.boundingBox(); if (b) await page.mouse.click(b.x + 5, b.y + 5); } };
  const fleeIfCombat = async () => { if (await eval(() => window.gameInCombat)) { await eval(() => { if (window.gameFleeBattle) window.gameFleeBattle(); }); await sleep(2000); } };

  console.log('-> New game');
  await eval(() => { if (window.gameClickNewGame) window.gameClickNewGame(); });
  await sleep(2500);
  await shot(page, '01_l1_spawn');

  // Reach ~50%: recruit a few "?" + neutralize "!" + collect буквицы
  console.log('-> Reaching 50%: recruiting "?", neutralizing "!", collecting');
  await eval(() => { if (window.gameTestAddDots) window.gameTestAddDots(20); });
  await sleep(300);
  await eval(() => { if (window.gameClearRegion) window.gameClearRegion(); }); // neutralize "!"
  await sleep(1200);
  for (let r = 0; r < 4; r++) {
    await fleeIfCombat();
    await eval(() => { if (window.gameForceRecruit) window.gameForceRecruit(true); });
    await sleep(150);
    await eval(() => { if (window.gameTestStartDialogue) window.gameTestStartDialogue(); });
    await sleep(700);
    for (let i = 0; i < 8; i++) {
      const active = await eval(() => window.gameDialogueActive);
      if (!active) break;
      await eval(() => { if (window.gameAdvanceDialogue) window.gameAdvanceDialogue(); });
      await sleep(220);
    }
    await sleep(400);
  }
  // Wander to collect буквицы and push progress past 50%
  for (let i = 0; i < 10; i++) {
    if (await eval(() => !!window.gamePortalSpawned)) break;
    await fleeIfCombat();
    await clickCanvas();
    await hold('KeyD', 350); await hold('KeyS', 250); await hold('KeyW', 250); await hold('KeyA', 250);
  }
  await sleep(800);
  const prog = await eval(() => window.gameLevelProgress || 0);
  console.log('-> progress:', prog, 'portal:', await eval(() => !!window.gamePortalSpawned));
  await shot(page, '02_portal_near_hero');

  // The portal spawns NEAR the hero (to the right). Step right/around to enter it.
  console.log('-> Entering portal (it is near the hero, to the right)');
  for (let i = 0; i < 24; i++) {
    const region = await eval(() => (window.gameHUD && window.gameHUD.region) || '');
    if (region.includes('Лес') || region.includes('лес')) { console.log('   reached Level 2!'); break; }
    await fleeIfCombat();
    await clickCanvas();
    await hold('KeyD', 250);
    await hold('KeyW', 150);
    await hold('KeyS', 200);
  }
  await sleep(2500);
  const region = await eval(() => (window.gameHUD && window.gameHUD.region) || '');
  console.log('-> Region now:', region);
  await shot(page, '03_l2_arrived');

  if (region.includes('Лес') || region.includes('лес')) {
    // Level 2: find a REAL drawn creature and fight it
    await sleep(600);
    const monsters = await eval(() => window.gameMonsterStates || []);
    const creatures = monsters.filter(m => m.id === 'forest_creature');
    console.log('-> Real enemies (Лесная Тварь) on Level 2:', creatures.length);
    await shot(page, '04_l2_creatures');
    // Give arsenal and fight a creature
    for (const l of ['А','Б','О','М','В','К']) { await eval((x) => { if (window.gameTestAddLetter) window.gameTestAddLetter(x); }, l); await sleep(80); }
    const c = creatures[0] || { hp: 80 };
    await eval((hp) => { if (window.gameStartTestCombat) window.gameStartTestCombat('Лесная Тварь', hp, ['А','В','К']); }, c.hp);
    await sleep(2000);
    await shot(page, '05_creature_combat');
    await eval(() => { if (window.gameAutoBattle) window.gameAutoBattle(); });
    const deadline = Date.now() + 50000;
    while (Date.now() < deadline) { if (await eval(() => window.gameInCombat) === false) break; await sleep(500); }
    await sleep(2000);
    await shot(page, '06_creature_done');
    console.log('-> Creature fight done');
  } else {
    console.log('-> Did not reach Level 2 (portal entry failed)');
  }

  console.log('Keeping window open 8s...');
  await sleep(8000);
  await browser.close();
  console.log('complete');
})().catch(e => { console.error('BOT ERROR:', e); process.exit(1); });
