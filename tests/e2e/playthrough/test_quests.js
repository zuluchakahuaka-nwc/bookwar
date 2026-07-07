#!/usr/bin/env node
// Проверка: квесты появляются на карте 3+, журнал работает, прогрессия N-2.
const puppeteer = require('puppeteer');
const sleep = ms => new Promise(r => setTimeout(r, ms));
const MAP_CHAIN = ['light_valley','two_letter_forest','dark_oaks','mossy_lowlands','rotten_swamps','swamp_lights','stony_wastes'];

(async () => {
  const b = await puppeteer.launch({ headless: true, args: ['--no-sandbox','--disable-web-security','--disable-features=ntlm-auth'] });
  const p = await b.newPage();
  await p.setViewport({ width: 1280, height: 720 });
  p.on('console', m => { const t = m.text(); if (t.includes('Failed to load resource')) return; if (m.type() === 'error' || t.includes('Error')) console.log('[c]', t.substr(0,250)); });
  await p.goto('http://localhost:3000', { waitUntil: 'domcontentloaded', timeout: 60000 });
  await p.waitForSelector('canvas', { timeout: 30000 });
  const c = await p.$('canvas'); if (c) { const bx = await c.boundingBox(); if (bx) await p.mouse.click(bx.x+5, bx.y+5); }
  await sleep(3500);
  await p.evaluate(() => window.gameClickNewGame && window.gameClickNewGame());
  await sleep(2500);
  await p.evaluate(() => window.gameSkipIntro && window.gameSkipIntro());
  await sleep(1500);
  for (let i = 0; i < 12; i++) { await p.evaluate(() => window.gameAdvanceIntro && window.gameAdvanceIntro()); await sleep(350); }
  await sleep(1000);
  await p.evaluate(() => { if (window.gameSelectHeroByIndex) window.gameSelectHeroByIndex(0); });
  await sleep(500);
  await p.evaluate(() => { if (window.gameConfirmHero) window.gameConfirmHero(); });
  await sleep(3500);

  for (let i = 0; i < MAP_CHAIN.length; i++) {
    const mapId = MAP_CHAIN[i];
    if (i > 0) {
      const prev = await p.evaluate(() => (window.gameHUD || {}).region || '');
      await p.evaluate((id) => { if (window.gameTestGotoMap) window.gameTestGotoMap(id); }, mapId);
      // ждём смены региона
      for (let k = 0; k < 20; k++) {
        await sleep(500);
        const r = await p.evaluate(() => (window.gameHUD || {}).region || '');
        if (r && r !== prev && r !== '?') break;
      }
    }
    await sleep(1500);
    const quests = await p.evaluate(() => {
      try { return JSON.parse(window.gameQuests || '{"active":[]}'); }
      catch (e) { return { active: [], parse_err: String(e) }; }
    });
    const level = i + 1;
    const expectedCount = level >= 3 ? Math.max(1, level - 2) : 0;
    const actualCount = (quests.active || []).length;
    const ok = actualCount === expectedCount ? '✅' : '❌';
    console.log(`L${level} ${mapId}: ${ok} ожидаемо ${expectedCount}, по факту ${actualCount}`);
    if (actualCount > 0) {
      const q = (quests.active || [])[0];
      console.log(`   первый квест: [${q.type}] ${q.npc_name || '?'} — ${q.description?.substr(0,60)}`);
    }
  }

  // Тест: открыть журнал на карте 3 (должна быть 1 квест)
  await p.evaluate(() => { if (window.gameTestGotoMap) window.gameTestGotoMap('dark_oaks'); });
  await sleep(3000);
  await p.evaluate(() => { if (window.gameToggleQuestLog) window.gameToggleQuestLog(); });
  await sleep(800);
  const logVisible = await p.evaluate(() => !!window.gameQuestLogVisible);
  console.log(`\nЖурнал открыт на карте 3: ${logVisible ? '✅' : '❌'}`);
  await p.screenshot({ path: 'D:\\Projects\\BOOKWAR\\tests\\screenshots\\quest_log_test.png' });

  await b.close();
})();
