#!/usr/bin/env node
/**
 * walkthrough33_bot.js — Baseline-прогон по всем 33 картам.
 *
 * Цель: для каждой карты зафиксировать
 *   — регион/HP/число монстров/рекрутов загрузились (✅/⚠/❌)
 *   — победа/портал достигнуты
 *   — где зависает / падает / чёрный экран
 *
 * Бот НЕ пытается пройти "по-настоящему" (это отдельный full_playthrough).
 * Бот проверяет: загружается ли карта, спавнятся ли монстры, реагирует ли
 * авто-бой, есть ли победа. Это базовая "проходимость" — хватает для
 * baseline перед заливкой квестов.
 *
 * Запуск:
 *   node tests/e2e/playthrough/walkthrough33_bot.js
 *   (нужен http-server на :3000, см. scripts/dev/serve.ps1)
 *
 * Агент: читает stdout в конце — список ✅/⚠/❌ по 33 картам.
 */

const puppeteer = require('puppeteer');
const fs = require('fs');
const path = require('path');

const GODOT_URL = process.env.GODOT_URL || 'http://localhost:3000';
const SCREENSHOT_DIR = path.join(__dirname, '..', '..', 'screenshots');
if (!fs.existsSync(SCREENSHOT_DIR)) fs.mkdirSync(SCREENSHOT_DIR, { recursive: true });

const REPORT_PATH = path.join(__dirname, 'walkthrough33_report.json');

// 33 карты в порядке MAP_CHAIN (constants.gd)
const MAP_CHAIN = [
  'light_valley', 'two_letter_forest', 'dark_oaks',
  'mossy_lowlands', 'rotten_swamps', 'swamp_lights',
  'stony_wastes', 'ash_plains', 'crystal_grottos', 'dark_cathedral',
  'forgotten_ruins', 'misty_grove', 'grey_forest', 'wind_pass',
  'ice_pincers', 'mountain_caves', 'deep_mines', 'catacombs_silence',
  'vaults_oblivion', 'underground_river', 'flooded_temple', 'ruined_library',
  'broken_bridge', 'abandoned_village', 'old_citadel', 'shadow_fortress',
  'black_tower', 'throne_void', 'hall_mirrors', 'labyrinth_fear',
  'chambers_ban', 'throne_keeper', 'well_of_letters'
];

const PER_MAP_BUDGET_MS = 25000;   // таймаут на одну карту (бой + движение)
const LOAD_WAIT_MS = 2500;         // подождать после смены карты

function log(msg) {
  const ts = new Date().toISOString().substr(11, 8);
  console.log(`[${ts}] ${msg}`);
}
const sleep = (ms) => new Promise(r => setTimeout(r, ms));

async function getMapState(page) {
  return await page.evaluate(() => ({
    mapId: window.gameCurrentMapId || null,
    region: (window.gameHUD || {}).region || '?',
    hp: (window.gameHUD || {}).hp || '?',
    playerPos: window.gamePlayerPos || { x: 0, y: 0 },
    monsters: (window.gameMonsterStates || []).filter(m => m.state !== 'dead'),
    deadMonsters: (window.gameMonsterStates || []).filter(m => m.state === 'dead'),
    recruitCount: window.gameRecruitCount || 0,
    victory: !!window.gameVictory,
    portalSpawned: !!window.gamePortalSpawned,
    inCombat: !!window.gameInCombat,
    autoCombat: window.gameAutoCombat || null,
    activeQuest: window.gameQuest || null,
    inventory: {
      dots: (window.gameInventory || {}).dots || 0,
      letterKinds: Object.keys((window.gameInventory || {}).letters || {}).length,
    },
    fontApplied: !!window.gameFontApplied,
    gameErrors: (window.__bookwarErrors || []).slice(-5),
  }));
}

async function clickCanvas(page) {
  const c = await page.$('canvas');
  if (c) { const b = await c.boundingBox(); if (b) await page.mouse.click(b.x + 5, b.y + 5); }
}

async function holdKey(page, key, ms) {
  await page.keyboard.down(key);
  await sleep(ms);
  await page.keyboard.up(key);
}

/** Загрузить карту через test-bridge и подождать спавна.
 *  B-QUEST-1 фикс: после правки INITIAL_BRIDGE_JS старый gameHUD сохраняется,
 *  поэтому ждём ИЗМЕНЕНИЯ region (старый → новый), а не просто появления. */
async function gotoMap(page, mapId) {
  // Запомнить предыдущий region (чтобы дождаться смены)
  const prevRegion = await page.evaluate(() => (window.gameHUD || {}).region || '');
  await page.evaluate((id) => {
    if (typeof window.gameTestGotoMap === 'function') window.gameTestGotoMap(id);
  }, mapId);
  const deadline = Date.now() + 12000;
  while (Date.now() < deadline) {
    await sleep(500);
    const s = await page.evaluate(() => ({
      region: (window.gameHUD || {}).region || '',
    }));
    if (s.region !== '' && s.region !== '?' && s.region !== prevRegion) return;
  }
}

/** Ждать пока world_map загрузит регион и (опционально) монстров. */
async function waitForMapLoaded(page, expectedMapId) {
  const deadline = Date.now() + 12000;
  while (Date.now() < deadline) {
    await sleep(500);
    const s = await page.evaluate(() => ({
      region: (window.gameHUD || {}).region || '?',
      monsters: ((window.gameMonsterStates || []).length),
      inWorld: !!window.gameHUD && (window.gameHUD || {}).region !== '?',
    }));
    if (s.inWorld) return;
  }
}

/** Ждать пока fn() вернёт truthy. */
async function waitForFn(page, fn, timeoutMs, label) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const v = await page.evaluate(fn);
    if (v) return true;
    await sleep(300);
  }
  log(`  (timeout waiting for: ${label})`);
  return false;
}

/** Попытка пройти карту: подход к ! → авто-бой × N попыток. */
async function attemptClear(page, state, idx) {
  const result = { fought: 0, won: 0, lost: 0, stuckReasons: [] };
  const tStart = Date.now();

  // 1) Дать точек (если есть ? — нужен диалог; если бой — буквы уже могут быть)
  await page.evaluate(() => {
    if (typeof window.gameTestAddDots === 'function') window.gameTestAddDots(20);
  });
  await sleep(200);

  for (let attempt = 0; attempt < 4; attempt++) {
    if (Date.now() - tStart > PER_MAP_BUDGET_MS) {
      result.stuckReasons.push('budget exhausted');
      break;
    }
    state = await getMapState(page);

    // Победа / портал — выход
    if (state.victory || state.portalSpawned) {
      result.stuckReasons.push('victory/portal reached');
      break;
    }
    if (state.hp === '0' || state.hp === 0) {
      result.stuckReasons.push('player dead');
      break;
    }

    const hostiles = state.monsters.filter(m => m.id === 'exclamation' || m.allegiance === 0);
    if (hostiles.length === 0) {
      // Нет врагов — может, монстры других типов (? npc). Попытка вербовки или просто ждём победу.
      result.stuckReasons.push('no hostiles; relying on victory check');
      break;
    }

    // Найти ближайшего
    let closest = hostiles[0], closestDist = Infinity;
    for (const m of hostiles) {
      const d = Math.hypot(m.position.x - state.playerPos.x, m.position.y - state.playerPos.y);
      if (d < closestDist) { closestDist = d; closest = m; }
    }

    // Подойти (упрощённо — двигаемся к монстру)
    const dx = closest.position.x - state.playerPos.x;
    const dy = closest.position.y - state.playerPos.y;
    if (Math.abs(dx) > 40) await holdKey(page, dx > 0 ? 'KeyD' : 'KeyA', Math.min(Math.abs(dx) / 200 * 700, 1500));
    if (Math.abs(dy) > 40) await holdKey(page, dy > 0 ? 'KeyS' : 'KeyW', Math.min(Math.abs(dy) / 200 * 700, 1500));
    await sleep(800);

    // Атака через F (initiate combat, см. §20.4)
    await page.keyboard.press('KeyF');
    await sleep(1500);

    state = await getMapState(page);
    if (state.autoCombat) {
      result.fought++;
      if (state.autoCombat.won) result.won++; else result.lost++;
      await sleep(1500);
    } else if (state.inCombat) {
      result.fought++;
      // ждём резолва
      for (let w = 0; w < 6; w++) {
        await sleep(800);
        const s2 = await getMapState(page);
        if (!s2.inCombat) { result.won++; break; }
      }
    } else {
      // Возможно диалог с ? — пропускаем
      await page.evaluate(() => {
        if (typeof window.gameAdvanceDialogue === 'function') window.gameAdvanceDialogue();
      });
    }

    if (attempt === 3) result.stuckReasons.push('4 attempts done');
  }
  return result;
}

async function run() {
  log('=================================================');
  log('  BOOKWAR — Baseline walkthrough по 33 картам');
  log('=================================================\n');

  const browser = await puppeteer.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-web-security', '--disable-features=ntlm-auth', '--window-size=1280,800']
  });
  const page = await browser.newPage();
  await page.setViewport({ width: 1280, height: 720 });

  // Собираем ошибки движка
  await page.evaluateOnNewDocument(() => {
    window.__bookwarErrors = [];
    window.addEventListener('error', e => window.__bookwarErrors.push(String(e.message || e)));
  });

  page.on('console', msg => {
    const t = msg.text();
    // Игнорируем 404-шум (favicon, audio worklet и пр. — не критично)
    if (t.includes('Failed to load resource')) return;
    if (msg.type() === 'error' || t.includes('SCRIPT ERROR') || /[^a-zA-Z]Error[^a-zA-Z]/.test(t)) {
      log(`  ⚠ [GAME] ${t.substr(0, 200)}`);
    }
  });

  // ===== Загрузка =====
  log(`Загрузка ${GODOT_URL} ...`);
  try {
    await page.goto(GODOT_URL, { waitUntil: 'domcontentloaded', timeout: 60000 });
  } catch (e) {
    log(`❌ Не удалось загрузить игру: ${e.message}`);
    await browser.close();
    process.exit(2);
  }
  await page.waitForSelector('canvas', { timeout: 30000 });
  await clickCanvas(page);
  await sleep(3000);

  let state = await getMapState(page);
  log(`Шрифт применён: ${state.fontApplied ? '✅' : '❌'}`);
  log(`Стартовый экран, ошибки: ${(state.gameErrors || []).length}`);

  // ===== New Game → intro → advance ×12 → character_select → confirm → world_map =====
  // gameSkipIntro() флаг не ловится intro._process (timing), но 12× advance
  // прокручивает все панели и доводит до _finish() → char_select.
  await page.evaluate(() => {
    if (typeof window.gameClickNewGame === 'function') window.gameClickNewGame();
  });
  await sleep(2500);
  // Сначала skip (на случай если он сработает), потом advance как fallback.
  await page.evaluate(() => { if (typeof window.gameSkipIntro === 'function') window.gameSkipIntro(); });
  await sleep(1500);
  for (let i = 0; i < 12; i++) {
    await page.evaluate(() => { if (typeof window.gameAdvanceIntro === 'function') window.gameAdvanceIntro(); });
    await sleep(350);
  }
  await waitForFn(page, () => !!(window.gameCharSelectLoaded), 10000, 'char_select loaded');
  await sleep(500);
  await page.evaluate(() => { if (typeof window.gameSelectHeroByIndex === 'function') window.gameSelectHeroByIndex(0); });
  await sleep(500);
  await page.evaluate(() => { if (typeof window.gameConfirmHero === 'function') window.gameConfirmHero(); });
  await waitForMapLoaded(page, 'light_valley');

  const report = [];

  for (let i = 0; i < MAP_CHAIN.length; i++) {
    const mapId = MAP_CHAIN[i];
    const levelNum = i + 1;
    log(`\n--- Уровень ${levelNum}/33: ${mapId} ---`);

    if (i > 0) {
      await gotoMap(page, mapId);
    }
    // Подождать спавна монстров (на новой карте они появляются через 1-2с).
    for (let w = 0; w < 12; w++) {
      state = await getMapState(page);
      if (state.monsters.length > 0 || state.region !== '?') break;
      await sleep(500);
    }
    state = await getMapState(page);

    const before = {
      region: state.region,
      hp: state.hp,
      monsters: state.monsters.length,
      recruits: state.recruitCount,
      dots: state.inventory.dots,
      letterKinds: state.inventory.letterKinds,
      questActive: !!state.activeQuest,
      questDesc: state.activeQuest ? (state.activeQuest.desc || '').substr(0, 60) : null,
      errors: state.gameErrors || [],
    };
    log(`  Было: регион="${before.region}", HP=${before.hp}, монстров=${before.monsters}, рекрутов=${before.recruits}, квест=${before.questActive ? 'да' : 'нет'}`);

    // Попытка пройти (в режиме FAST_BASELINE=false). В baseline-режиме пропускаем
    // бой на каждой карте — просто проверяем что карта загрузилась и валидна.
    // Бои тестируются отдельно в full_playthrough_bot.js.
    let result;
    if (process.env.FAST_BASELINE === '1') {
      result = { fought: 0, won: 0, lost: 0, stuckReasons: ['baseline-only (no combat)'] };
    } else {
      try {
        result = await attemptClear(page, state, i);
      } catch (e) {
        result = { fought: 0, won: 0, lost: 0, stuckReasons: ['EXCEPTION: ' + e.message] };
      }
    }

    state = await getMapState(page);
    const after = {
      region: state.region,
      hp: state.hp,
      monsters: state.monsters.length,
      deadMonsters: state.deadMonsters.length,
      recruits: state.recruitCount,
      victory: state.victory,
      portalSpawned: state.portalSpawned,
    };

    // Классификация исхода
    let status = 'WARN';
    let reason = '';
    if (result.stuckReasons.includes('EXCEPTION')) {
      status = 'ERROR'; reason = result.stuckReasons.join('; ');
    } else if (before.monsters === 0 && before.region === '?') {
      status = 'ERROR'; reason = 'карта не загрузилась (нет региона/монстров)';
    } else if (before.errors.length > 0) {
      status = 'ERROR'; reason = 'GDScript errors: ' + before.errors.slice(0, 2).join(' | ');
    } else if (after.victory || after.portalSpawned) {
      status = 'OK'; reason = 'победа/портал достигнуты';
    } else if (result.won > 0) {
      status = 'WARN'; reason = `боёв выиграно ${result.won}, но победа не сработала`;
    } else if (before.monsters > 0 && result.fought === 0) {
      status = 'WARN'; reason = `монстров ${before.monsters}, бой не стартует (${result.stuckReasons.join('; ')})`;
    } else {
      status = 'WARN'; reason = result.stuckReasons.join('; ') || 'непонятный исход';
    }

    const icon = status === 'OK' ? '✅' : (status === 'ERROR' ? '❌' : '⚠');
    log(`  ${icon} ${status}: ${reason}`);
    log(`  После: HP=${after.hp}, мертво=${after.deadMonsters}, осталось=${after.monsters}, победа=${after.victory}, портал=${after.portalSpawned}`);

    // Скриншот для Vision-аудита
    const shotName = `lv${String(levelNum).padStart(2,'0')}_${mapId}_${status}.png`;
    try {
      await page.screenshot({ path: path.join(SCREENSHOT_DIR, shotName), fullPage: false });
    } catch (e) { /* ignore */ }

    report.push({
      level: levelNum,
      mapId,
      status,
      reason,
      before,
      after,
      fought: result.fought,
      won: result.won,
      lost: result.lost,
      screenshot: shotName,
    });
  }

  fs.writeFileSync(REPORT_PATH, JSON.stringify(report, null, 2));

  // ===== Итог =====
  log('\n=================================================');
  log('  СВОДКА BASELINE (33 карты)');
  log('=================================================');
  const ok = report.filter(r => r.status === 'OK').length;
  const warn = report.filter(r => r.status === 'WARN').length;
  const err = report.filter(r => r.status === 'ERROR').length;
  log(`✅ OK: ${ok}   ⚠ WARN: ${warn}   ❌ ERROR: ${err}`);
  log('');
  log('Ошибки (требуют починки):');
  report.filter(r => r.status === 'ERROR').forEach(r => {
    log(`  L${r.level} ${r.mapId}: ${r.reason}`);
  });
  log('');
  log('Предупреждения (проходимо, но не до конца):');
  report.filter(r => r.status === 'WARN').slice(0, 10).forEach(r => {
    log(`  L${r.level} ${r.mapId}: ${r.reason}`);
  });
  if (warn > 10) log(`  ... и ещё ${warn - 10}`);
  log('');
  log(`Отчёт: ${REPORT_PATH}`);
  log(`Скриншоты: ${SCREENSHOT_DIR}`);
  log('=================================================\n');

  await browser.close();
}

run().catch(err => { log(`❌ ОШИБКА БОТА: ${err.message}`); console.error(err.stack); process.exit(1); });
