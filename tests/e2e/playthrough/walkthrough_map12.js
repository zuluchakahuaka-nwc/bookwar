// walkthrough_map12.js — E2E полное прохождение карты 12 (Туманная Роща).
// Бот делает скриншоты КАЖДОГО шага: загрузка, квесты, диалоги, бой, victory.
// Цель: проверить что один регион проходится от старта до портала.
const puppeteer = require('puppeteer');
const fs = require('fs');
const path = require('path');

const GODOT_URL = 'http://localhost:3000';
const SHOTS_DIR = path.join(__dirname, '..', '..', 'screenshots', 'walk_map12');
if (!fs.existsSync(SHOTS_DIR)) fs.mkdirSync(SHOTS_DIR, { recursive: true });

const sleep = ms => new Promise(r => setTimeout(r, ms));
const MAP_ID = 'misty_grove';
const MAP_NAME_RU = 'Туманная Роща';

let stepN = 0;
function log(msg) {
  const ts = new Date().toISOString().substr(11, 8);
  console.log(`[${ts}] ${msg}`);
}
async function snap(page, label) {
  stepN++;
  const fp = path.join(SHOTS_DIR, String(stepN).padStart(2,'0') + '_' + label + '.png');
  await page.screenshot({ path: fp, fullPage: false });
  log(`📸 #${stepN}: ${label}`);
  return fp;
}
async function getState(page) {
  return await page.evaluate(() => ({
    region: (window.gameHUD || {}).region || '?',
    hp: (window.gameHUD || {}).hp || '',
    monsters: (window.gameMonsterStates || []).length,
    hostileMonsters: (window.gameMonsterStates || []).filter(m => m.allegiance === 0 && m.state !== 'dead').length,
    friendlyMonsters: (window.gameMonsterStates || []).filter(m => m.allegiance === 1).length,
    neutralMonsters: (window.gameMonsterStates || []).filter(m => m.allegiance === 2).length,
    deadMonsters: (window.gameMonsterStates || []).filter(m => m.state === 'dead').length,
    recruits: window.gameRecruitCount || 0,
    dots: (window.gameInventory || {}).dots || 0,
    lettersCount: Object.keys((window.gameInventory || {}).letters || {}).length,
    questActive: (function() { try { return JSON.parse(window.gameQuests || '{}').active || []; } catch(e){ return []; } })().length,
    inCombat: !!window.gameInCombat,
    inDialogue: !!window.gameDialogueActive,
    victory: !!window.gameVictory,
    portalSpawned: !!window.gamePortalSpawned,
    levelProgress: window.gameLevelProgress || 0,
    playerPos: window.gamePlayerPos || { x: 0, y: 0 },
  }));
}

async function newGameFlow(page) {
  await page.evaluate(() => window.gameClickNewGame && window.gameClickNewGame());
  await sleep(2000);
  await page.evaluate(() => window.gameSkipIntro && window.gameSkipIntro());
  await sleep(1500);
  for (let i = 0; i < 12; i++) { await page.evaluate(() => window.gameAdvanceIntro && window.gameAdvanceIntro()); await sleep(300); }
  await sleep(800);
  await page.evaluate(() => { if (window.gameSelectHeroByIndex) window.gameSelectHeroByIndex(0); });
  await sleep(500);
  await page.evaluate(() => { if (window.gameConfirmHero) window.gameConfirmHero(); });
  await sleep(3500);
}

async function gotoMap(page, mapId) {
  const prev = await page.evaluate(() => (window.gameHUD || {}).region || '');
  await page.evaluate((id) => { if (window.gameTestGotoMap) window.gameTestGotoMap(id); }, mapId);
  for (let k = 0; k < 24; k++) {
    await sleep(500);
    const r = await page.evaluate(() => (window.gameHUD || {}).region || '');
    if (r && r !== prev && r !== '?') return true;
  }
  return false;
}

async function holdKey(page, key, ms) {
  const canvas = await page.$('canvas');
  if (canvas) { const box = await canvas.boundingBox(); if (box) await page.mouse.click(box.x + box.width/2, box.y + box.height/2); }
  await sleep(50);
  await page.keyboard.down(key); await sleep(ms); await page.keyboard.up(key);
  await sleep(300);
}

async function moveTo(page, targetX, targetY, threshold = 50) {
  let state = await getState(page);
  let dx = targetX - state.playerPos.x;
  let dy = targetY - state.playerPos.y;
  let attempts = 0;
  while ((Math.abs(dx) > threshold || Math.abs(dy) > threshold) && attempts < 12) {
    if (Math.abs(dx) > threshold) {
      await holdKey(page, dx > 0 ? 'KeyD' : 'KeyA', Math.min(Math.abs(dx) / 200 * 700, 1500));
    }
    if (Math.abs(dy) > threshold) {
      await holdKey(page, dy > 0 ? 'KeyS' : 'KeyW', Math.min(Math.abs(dy) / 200 * 700, 1500));
    }
    state = await getState(page);
    dx = targetX - state.playerPos.x;
    dy = targetY - state.playerPos.y;
    attempts++;
    if (state.inCombat || state.inDialogue) break;
  }
  return state;
}

(async () => {
  log('=== E2E WALKTHROUGH КАРТЫ 12: ' + MAP_NAME_RU + ' ===\n');
  const browser = await puppeteer.launch({
    headless: true,
    args: ['--no-sandbox','--disable-web-security','--disable-features=ntlm-auth','--window-size=1280,800']
  });
  const page = await browser.newPage();
  await page.setViewport({ width: 1280, height: 720 });
  page.on('console', m => {
    const t = m.text();
    if (t.includes('Failed to load resource')) return;
    if (m.type() === 'error' || t.includes('SCRIPT ERROR')) log(`  ⚠ [GAME] ${t.substr(0, 200)}`);
  });

  log('Загрузка игры...');
  await page.goto(GODOT_URL, { waitUntil: 'domcontentloaded', timeout: 60000 });
  await page.waitForSelector('canvas', { timeout: 30000 });
  const c = await page.$('canvas');
  if (c) { const bx = await c.boundingBox(); if (bx) await page.mouse.click(bx.x+5, bx.y+5); }
  await sleep(3500);

  log('New Game → skip intro → выбор героя');
  await newGameFlow(page);

  log('Переход на карту 12: ' + MAP_ID);
  await gotoMap(page, MAP_ID);
  await sleep(2000);

  let state = await getState(page);
  log(`Регион: "${state.region}", HP: ${state.hp}, монстров: ${state.monsters} (врагов: ${state.hostileMonsters}, друзей: ${state.friendlyMonsters}, нейтральных: ${state.neutralMonsters})`);
  log(`Квестов активно: ${state.questActive}, буквиц: ${state.dots}, букв: ${state.lettersCount}`);
  await snap(page, 'load');

  // 1. Скриншот: журнал квестов
  log('\n--- Шаг: открыть журнал квестов ---');
  await page.evaluate(() => { if (window.gameToggleQuestLog) window.gameToggleQuestLog(); });
  await sleep(800);
  await snap(page, 'quest_log');
  await page.evaluate(() => { if (window.gameToggleQuestLog) window.gameToggleQuestLog(); });
  await sleep(400);

  // 2. Скриншот: статистика
  log('\n--- Шаг: открыть статистику ---');
  await page.evaluate(() => { if (window.gameToggleStats) window.gameToggleStats(); });
  await sleep(800);
  await snap(page, 'stats');
  await page.evaluate(() => { if (window.gameToggleStats) window.gameToggleStats(); });
  await sleep(400);

  // 3. Найти ближайшего ? монстра (нейтрального) — для диалога
  log('\n--- Шаг: подойти к ? монстру для диалога ---');
  let monsters = await page.evaluate(() => window.gameMonsterStates || []);
  const neutral = monsters.filter(m => m.id === 'question' && m.allegiance === 2 && m.state !== 'dead');
  if (neutral.length > 0) {
    const target = neutral[0];
    log(`Нейтральный ? монстр "${target.name}" в (${Math.round(target.position.x)}, ${Math.round(target.position.y)})`);
    state = await moveTo(page, target.position.x, target.position.y, 70);
    await snap(page, 'near_question');
    // Дать точек для диалога
    await page.evaluate(() => { if (window.gameTestAddDots) window.gameTestAddDots(15); });
    await sleep(300);
    // gameTriggerDialogue — надёжный JS bridge (T-key через Puppeteer нестабилен)
    await page.evaluate(() => { if (window.gameTriggerDialogue) window.gameTriggerDialogue(); });
    await sleep(1500);
    state = await getState(page);
    if (state.inDialogue) {
      log(`Диалог открыт`);
      await snap(page, 'dialogue');
      // Прокликать диалог
      for (let i = 0; i < 5; i++) {
        await page.evaluate(() => { if (window.gameAdvanceDialogue) window.gameAdvanceDialogue(); });
        await sleep(800);
        const s2 = await getState(page);
        if (!s2.inDialogue) break;
      }
      await snap(page, 'after_dialogue');
    } else {
      log(`Диалог не открылся (нет ? монстра в радиусе)`);
    }
  } else {
    log('Нет нейтральных ? монстров на карте');
  }

  // 4. Подойти к враждебному ! монстру — инициировать бой
  log('\n--- Шаг: подойти к враждебному ! монстру ---');
  monsters = await page.evaluate(() => window.gameMonsterStates || []);
  const hostile = monsters.filter(m => m.allegiance === 0 && m.state !== 'dead');
  if (hostile.length > 0) {
    const target = hostile[0];
    log(`Враг "${target.name}" (${target.id}) в (${Math.round(target.position.x)}, ${Math.round(target.position.y)}), HP=${target.hp}`);
    state = await moveTo(page, target.position.x, target.position.y, 70);
    await snap(page, 'near_enemy');
    // F-key для атаки
    const canvas = await page.$('canvas');
    if (canvas) { const box = await canvas.boundingBox(); if (box) await page.mouse.click(box.x + box.width/2, box.y + box.height/2); }
    await page.keyboard.press('KeyF');
    await sleep(2500);
    state = await getState(page);
    log(`После F-атаки: inCombat=${state.inCombat}, victory=${state.victory}`);
    await snap(page, 'after_attack');
    if (state.inCombat) {
      log('Бой начался. Активируем автобой через JS bridge...');
      // gameAutoBattle — JS bridge в battle_manager.gd
      await page.evaluate(() => { if (window.gameAutoBattle) window.gameAutoBattle(); });
      await sleep(500);
      // Ждём завершения боя (возврат в world_map)
      let waited = 0;
      while (waited < 30) {
        await sleep(1500);
        const s2 = await getState(page);
        waited++;
        if (!s2.inCombat) {
          log(`Бой завершён за ${waited*1.5}с, регион: ${s2.region}`);
          break;
        }
      }
      await snap(page, 'after_combat');
    }
  } else {
    log('Нет враждебных монстров (возможно карта уже зачищена?)');
  }

  // 5. Открыть инвентарь — проверить состояние
  log('\n--- Шаг: открыть инвентарь ---');
  await page.evaluate(() => { if (window.gameToggleInventory) window.gameToggleInventory(); });
  await sleep(1000);
  await snap(page, 'inventory');
  await page.evaluate(() => { if (window.gameToggleInventory) window.gameToggleInventory(); });
  await sleep(400);

  // 6. Попытаться зачистить карту через gameClearRegion и проверить victory
  log('\n--- Шаг: нейтрализовать всех → проверить victory ---');
  await page.evaluate(() => { if (window.gameClearRegion) window.gameClearRegion(); });
  await sleep(2500);
  state = await getState(page);
  log(`После clearRegion: victory=${state.victory}, портал=${state.portalSpawned}, прогресс=${state.levelProgress}%`);
  await snap(page, 'after_clear');

  // 7. Если портал есть — подойти к нему
  if (state.portalSpawned || state.victory) {
    log('\n--- Шаг: подойти к порталу ---');
    const player = state.playerPos;
    // Портал спавнится около игрока + offset (140, -40)
    const portalX = player.x + 140;
    const portalY = player.y - 40;
    await moveTo(page, portalX, portalY, 40);
    await sleep(500);
    await snap(page, 'near_portal');
  }

  // 8. Финальный скриншот
  state = await getState(page);
  log('\n=== ИТОГ ===');
  log(`Регион: ${state.region}`);
  log(`HP: ${state.hp}`);
  log(`Монстров: ${state.monsters}, из них мертво: ${state.deadMonsters}`);
  log(`Победа: ${state.victory}, Портал: ${state.portalSpawned}`);
  log(`Букв собрано: ${state.lettersCount}, Буквиц: ${state.dots}`);
  await snap(page, 'final');

  await browser.close();
  log(`\nСкриншотов сохранено: ${stepN} в ${SHOTS_DIR}`);
})();
